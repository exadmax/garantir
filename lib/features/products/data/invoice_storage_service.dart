import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class InvoiceStorageService {
  InvoiceStorageService({FirebaseStorage? storage, FirebaseAuth? auth})
      : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Usuário não autenticado');
    return uid;
  }

  Future<String> uploadInvoiceImage({
    required String productId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = image.path.contains('.')
        ? image.path.split('.').last.toLowerCase()
        : 'jpg';

    final ref = _storage
        .ref()
        .child('invoices')
        .child(_uid)
        .child(productId)
        .child('invoice.$extension');

    final metadata = SettableMetadata(
      contentType: 'image/$extension',
      customMetadata: {'productId': productId},
    );

    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
  }
}
