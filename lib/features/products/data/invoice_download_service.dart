import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class InvoiceDownloadService {
  Future<void> saveInvoiceImage(
      {required String url, required String fileName}) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(
          'Não foi possível baixar a nota fiscal (HTTP ${response.statusCode})');
    }

    final mimeType = response.headers['content-type'] ?? 'image/jpeg';
    final file =
        XFile.fromData(response.bodyBytes, name: fileName, mimeType: mimeType);

    await SharePlus.instance.share(
      ShareParams(files: [file], fileNameOverrides: [fileName]),
    );
  }
}
