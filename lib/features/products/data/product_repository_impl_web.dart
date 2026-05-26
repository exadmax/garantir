import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../categories/domain/category.dart';
import '../domain/product.dart';

class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Usuário não autenticado');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('users').doc(_uid).collection('products');

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _firestore.collection('users').doc(_uid).collection('categories');

  Stream<List<Product>> watchProducts() {
    return _productsRef
        .orderBy('warrantyEndDate')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Product.fromDoc(d)).toList())
        .handleError((Object e) {
          throw Exception('Erro ao carregar produtos: $e');
        });
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
    await _productsRef.doc(docId).set(updated.toMap(), SetOptions(merge: true));
    return docId;
  }

  Future<void> deleteProduct(String productId) async {
    await _productsRef.doc(productId).delete();
  }

  Stream<List<ProductCategory>> watchCategories() {
    return _categoriesRef
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProductCategory.fromMap(d.id, d.data()))
            .toList())
        .handleError((Object e) {
          throw Exception('Erro ao carregar categorias: $e');
        });
  }

  Future<void> saveCategory(ProductCategory category) async {
    final docId = category.id.isEmpty ? _uuid.v4() : category.id;
    final updated =
        ProductCategory(id: docId, name: category.name, isDefault: category.isDefault);
    await _categoriesRef.doc(docId).set(updated.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteCategory(String categoryId) async {
    await _categoriesRef.doc(categoryId).delete();
  }

  Future<void> seedDefaultCategories() async {
    final defaults = [
      ProductCategory(id: 'default-eletrodomesticos', name: 'Eletrodomesticos', isDefault: true),
      ProductCategory(id: 'default-eletronicos', name: 'Eletronicos', isDefault: true),
      ProductCategory(id: 'default-servicos', name: 'Servicos', isDefault: true),
    ];
    for (final cat in defaults) {
      final doc = await _categoriesRef.doc(cat.id).get();
      if (!doc.exists) await saveCategory(cat);
    }
  }

  Future<void> syncIfNeeded() async {}
}
