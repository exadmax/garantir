import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/fast_hash.dart';
import '../../../core/database/isar_database.dart';
import '../../../core/database/sync_meta_isar_schema.dart';
import '../../categories/data/category_isar_schema.dart';
import '../../categories/domain/category.dart';
import '../domain/product.dart';
import 'product_isar_schema.dart';

class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  // Curto o bastante para o Android refletir alterações feitas na web a cada
  // abertura do app; longo o bastante para não martelar o Firestore em
  // navegações de ida e volta dentro da mesma sessão.
  static const _syncInterval = Duration(minutes: 15);

  // Only accessed on Android; never called on web (all paths guarded by kIsWeb).
  Isar get _isar => IsarDatabase.instance;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Usuário não autenticado');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('users').doc(_uid).collection('products');

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _firestore.collection('users').doc(_uid).collection('categories');

  // ── Products ──────────────────────────────────────────────────────────────

  /// Web → Firestore real-time stream.
  /// Android → Isar local stream (instant, offline).
  Stream<List<Product>> watchProducts() {
    if (kIsWeb) {
      return _productsRef
          .orderBy('warrantyEndDate')
          .snapshots()
          .map((snap) => snap.docs.map((d) => Product.fromDoc(d)).toList());
    }
    return _isar.productIsarSchemas
        .where()
        .sortByWarrantyEndDate()
        .watch(fireImmediately: true)
        .map((list) => list.map((s) => s.toDomain()).toList());
  }

  Future<String> saveProduct(Product product) async {
    final docId = product.id.isEmpty ? _uuid.v4() : product.id;
    final updated = Product(
      id: docId,
      name: product.name,
      categoryId: product.categoryId,
      purchaseDate: product.purchaseDate,
      warrantyEndDate: product.warrantyEndDate,
      guaranteeType: product.guaranteeType,
      noteImageUrl: product.noteImageUrl,
      description: product.description,
    );

    if (kIsWeb) {
      // On web, await Firestore so the stream emits the new value immediately.
      await _productsRef.doc(docId).set(updated.toMap(), SetOptions(merge: true));
    } else {
      await _isar.writeTxn(() async {
        await _isar.productIsarSchemas.put(ProductIsarSchema.fromDomain(updated));
      });
      // Fire-and-forget on Android: Isar stream already updated the UI.
      _fireAndForget(
        _productsRef.doc(docId).set(updated.toMap(), SetOptions(merge: true)),
      );
    }
    return docId;
  }

  Future<void> deleteProduct(String productId) async {
    if (kIsWeb) {
      await _productsRef.doc(productId).delete();
    } else {
      await _isar.writeTxn(() async {
        await _isar.productIsarSchemas.delete(fastHash(productId));
      });
      _fireAndForget(_productsRef.doc(productId).delete());
    }
  }

  // ── Categories ────────────────────────────────────────────────────────────

  /// Web → Firestore real-time stream.
  /// Android → Isar local stream.
  Stream<List<ProductCategory>> watchCategories() {
    if (kIsWeb) {
      return _categoriesRef
          .orderBy('name')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => ProductCategory.fromMap(d.id, d.data()))
              .toList());
    }
    return _isar.categoryIsarSchemas
        .where()
        .sortByName()
        .watch(fireImmediately: true)
        .map((list) => list.map((s) => s.toDomain()).toList());
  }

  Future<void> saveCategory(ProductCategory category) async {
    final docId = category.id.isEmpty ? _uuid.v4() : category.id;
    final updated = ProductCategory(id: docId, name: category.name, isDefault: category.isDefault);

    if (kIsWeb) {
      await _categoriesRef.doc(docId).set(updated.toMap(), SetOptions(merge: true));
    } else {
      await _isar.writeTxn(() async {
        await _isar.categoryIsarSchemas.put(CategoryIsarSchema.fromDomain(updated));
      });
      _fireAndForget(
        _categoriesRef.doc(docId).set(updated.toMap(), SetOptions(merge: true)),
      );
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    if (kIsWeb) {
      await _categoriesRef.doc(categoryId).delete();
    } else {
      await _isar.writeTxn(() async {
        await _isar.categoryIsarSchemas.delete(fastHash(categoryId));
      });
      _fireAndForget(_categoriesRef.doc(categoryId).delete());
    }
  }

  Future<void> seedDefaultCategories() async {
    final defaults = [
      ProductCategory(id: 'default-eletrodomesticos', name: 'Eletrodomesticos', isDefault: true),
      ProductCategory(id: 'default-eletronicos', name: 'Eletronicos', isDefault: true),
      ProductCategory(id: 'default-servicos', name: 'Servicos', isDefault: true),
    ];

    for (final cat in defaults) {
      if (kIsWeb) {
        final doc = await _categoriesRef.doc(cat.id).get();
        if (!doc.exists) await saveCategory(cat);
      } else {
        final exists = await _isar.categoryIsarSchemas.get(fastHash(cat.id));
        if (exists == null) await saveCategory(cat);
      }
    }
  }

  /// Lê os produtos uma única vez (Isar no Android, Firestore na web).
  /// Usado para reagendar notificações locais após um sync.
  Future<List<Product>> getProductsOnce() async {
    if (kIsWeb) {
      final snap = await _productsRef.orderBy('warrantyEndDate').get();
      return snap.docs.map(Product.fromDoc).toList();
    }
    final list = await _isar.productIsarSchemas.where().findAll();
    return list.map((s) => s.toDomain()).toList();
  }

  // ── Periodic Firestore sync (Android only) ────────────────────────────────

  /// No-op on web — Firestore streams already keep the UI in sync.
  /// Retorna `true` quando um sync com o Firestore foi executado.
  Future<bool> syncIfNeeded() async {
    if (kIsWeb) return false;

    final uid = _uid;
    final meta = await _isar.syncMetaIsarSchemas.get(1);
    final accountChanged = meta?.uid != uid;

    if (accountChanged) {
      // Outro usuário (ou primeiro login) neste aparelho: nunca exibir os
      // dados locais da conta anterior.
      await _isar.writeTxn(() async {
        await _isar.productIsarSchemas.clear();
        await _isar.categoryIsarSchemas.clear();
        await _isar.syncMetaIsarSchemas.put(
          SyncMetaIsarSchema()
            ..uid = uid
            ..lastSyncAt = null,
        );
      });
    } else if (meta?.lastSyncAt != null &&
        DateTime.now().difference(meta!.lastSyncAt!) < _syncInterval) {
      return false;
    }

    await _fetchFromFirestore();
    await _markSynced(uid);
    return true;
  }

  Future<void> _fetchFromFirestore() async {
    final productsSnap = await _productsRef.orderBy('warrantyEndDate').get();
    final productSchemas = productsSnap.docs
        .map((doc) => ProductIsarSchema.fromDomain(Product.fromDoc(doc)))
        .toList();

    final categoriesSnap = await _categoriesRef.orderBy('name').get();
    final categorySchemas = categoriesSnap.docs
        .map((doc) => CategoryIsarSchema.fromDomain(
              ProductCategory.fromMap(doc.id, doc.data()),
            ))
        .toList();

    // clear + putAll na mesma transação: exclusões feitas em outro
    // dispositivo (ex.: web) são propagadas para o cache local.
    await _isar.writeTxn(() async {
      await _isar.productIsarSchemas.clear();
      await _isar.productIsarSchemas.putAll(productSchemas);
      await _isar.categoryIsarSchemas.clear();
      await _isar.categoryIsarSchemas.putAll(categorySchemas);
    });
  }

  Future<void> _markSynced(String uid) async {
    await _isar.writeTxn(() async {
      await _isar.syncMetaIsarSchemas.put(
        SyncMetaIsarSchema()
          ..uid = uid
          ..lastSyncAt = DateTime.now(),
      );
    });
  }

  /// Escritas no Firestore feitas sem await (a UI já foi atualizada pelo
  /// Isar): loga a falha em vez de deixar uma exceção assíncrona solta.
  /// Offline, o SDK do Firestore enfileira a escrita e reenvia sozinho.
  void _fireAndForget(Future<void> future) {
    future.catchError((Object e) {
      debugPrint('Firestore write falhou: $e');
    });
  }
}
