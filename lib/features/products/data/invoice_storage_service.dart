import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class InvoiceStorageService {
  InvoiceStorageService({FirebaseStorage? storage, FirebaseAuth? auth})
      : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  static const Duration _uploadTimeout = Duration(minutes: 2);

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
    final extension = _resolveExtension(image);

    final ref = _storage
        .ref()
        .child('invoices')
        .child(_uid)
        .child(productId)
        .child('invoice.$extension');

    final metadata = SettableMetadata(
      contentType: _contentTypeForExtension(extension),
      customMetadata: {'productId': productId},
    );

    final uploadTask = ref.putData(bytes, metadata);

    try {
      await uploadTask.timeout(_uploadTimeout, onTimeout: () async {
        await uploadTask.cancel();
        throw TimeoutException(
          'Tempo limite do upload atingido. Verifique conexão/regras do Firebase Storage.',
        );
      });
    } on FirebaseException catch (e) {
      throw Exception('Falha no upload da imagem (${e.code}): ${e.message ?? 'erro desconhecido'}');
    }

    try {
      return await ref.getDownloadURL().timeout(_uploadTimeout);
    } on TimeoutException {
      throw Exception('Upload concluído, mas a URL da imagem não foi obtida a tempo.');
    }
  }

  String _resolveExtension(XFile image) {
    final mime = image.mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) {
      final subtype = mime.split('/').last;
      return subtype == 'jpeg' ? 'jpg' : subtype;
    }

    final uri = Uri.tryParse(image.path);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : image.path.split('/').last;
    final dot = lastSegment.lastIndexOf('.');
    if (dot != -1 && dot < lastSegment.length - 1) {
      final ext = lastSegment.substring(dot + 1).toLowerCase();
      if (RegExp(r'^[a-z0-9]{2,8}$').hasMatch(ext)) {
        return ext == 'jpeg' ? 'jpg' : ext;
      }
    }

    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
