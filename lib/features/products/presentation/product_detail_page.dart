import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../categories/domain/category.dart';
import '../data/invoice_download_service.dart';
import '../domain/guarantee_type.dart';
import '../domain/product.dart';
import 'product_form_page.dart';
import 'product_ui_helpers.dart';

const _brand = Color(0xFF1F6E8C);
const _bg = Color(0xFFF4F6F8);
const _border = Color(0xFFEEF1F4);
const _muted = Color(0xFF6B7785);
const _dark = Color(0xFF1A1F26);

String _invoiceFileName(Product product) {
  final base = product.name.trim().isEmpty
      ? 'produto'
      : product.name
          .trim()
          .replaceAll(RegExp(r'[^\w\- ]'), '')
          .replaceAll(' ', '_');
  final ext = _extensionFromUrl(product.noteImageUrl ?? '');
  return '${base}_nota_fiscal.$ext';
}

String _extensionFromUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final lastSegment = Uri.decodeComponent(path).split('/').last;
  final dot = lastSegment.lastIndexOf('.');
  if (dot != -1 && dot < lastSegment.length - 1) {
    return lastSegment.substring(dot + 1).toLowerCase();
  }
  return 'jpg';
}

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage(
      {super.key, required this.product, required this.cats});
  final Product product;
  final List<ProductCategory> cats;

  @override
  Widget build(BuildContext context) {
    final st = productStatus(product);
    final sc = statusColors[st]!;
    final days = daysRemaining(product);
    final fmt = DateFormat('dd/MM/yyyy');
    final emoji = categoryEmoji(product.categoryId, cats);
    final catName =
        cats.where((c) => c.id == product.categoryId).firstOrNull?.name ??
            'Sem categoria';

    final totalDays =
        product.warrantyEndDate.difference(product.purchaseDate).inDays;
    final elapsed = DateTime.now().difference(product.purchaseDate).inDays;
    final progress =
        totalDays > 0 ? (elapsed / totalDays).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: _dark),
        title: const Text('Detalhes do produto',
            style: TextStyle(color: _dark, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _dark),
            tooltip: 'Editar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => ProductFormPage(existing: product)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(product.name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _dark)),
                      const SizedBox(height: 2),
                      Text(catName,
                          style: const TextStyle(fontSize: 13, color: _muted)),
                    ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: sc.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(sc.label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sc.text)),
                ),
              ]),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEEF1F4),
                  valueColor: AlwaysStoppedAnimation<Color>(sc.dot),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                days < 0
                    ? 'Expirada'
                    : days == 0
                        ? 'Expira hoje!'
                        : '$days dias restantes',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: sc.dot),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          const _SectionLabel('INFORMAÇÕES'),
          const SizedBox(height: 8),
          _InfoCard(children: [
            _InfoRow(
                label: 'Data da compra',
                value: fmt.format(product.purchaseDate)),
            _InfoRow(
                label: 'Vencimento da garantia',
                value: fmt.format(product.warrantyEndDate)),
            _InfoRow(
                label: 'Tipo de garantia', value: product.guaranteeType.label),
            _InfoRow(
              label: 'Observações',
              value: (product.description?.trim().isNotEmpty ?? false)
                  ? product.description!.trim()
                  : '—',
              isLast: true,
            ),
          ]),
          const SizedBox(height: 20),

          const _SectionLabel('NOTA FISCAL / FOTO DO PRODUTO'),
          const SizedBox(height: 8),
          if (product.noteImageUrl != null)
            _InvoiceCard(product: product)
          else
            const _EmptyInvoiceCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.8),
    );
  }
}

// ─── Info card ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, this.isLast = false});
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: _muted))),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
            ),
          ),
        ]),
      ),
      if (!isLast) const Divider(height: 1, color: _border),
    ]);
  }
}

// ─── Invoice card ─────────────────────────────────────────────────────────────
class _InvoiceCard extends StatefulWidget {
  const _InvoiceCard({required this.product});
  final Product product;

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  final _downloadService = InvoiceDownloadService();
  bool _isDownloading = false;

  Future<void> _download() async {
    final url = widget.product.noteImageUrl;
    if (url == null) return;
    setState(() => _isDownloading = true);
    try {
      await _downloadService.saveInvoiceImage(
          url: url, fileName: _invoiceFileName(widget.product));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar nota fiscal: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.product.noteImageUrl!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => _ImageViewerPage(product: widget.product)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 220,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (context, error, stack) => Container(
                height: 220,
                color: const Color(0xFFF4F6F8),
                alignment: Alignment.center,
                child: const Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.broken_image_outlined, size: 32, color: _muted),
                  SizedBox(height: 8),
                  Text('Não foi possível carregar a imagem',
                      style: TextStyle(fontSize: 12, color: _muted)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isDownloading ? null : _download,
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(_isDownloading ? 'Salvando...' : 'Salvar nota fiscal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brand,
              side: const BorderSide(color: _brand),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Empty invoice state ──────────────────────────────────────────────────────
class _EmptyInvoiceCard extends StatelessWidget {
  const _EmptyInvoiceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: const Column(children: [
        Icon(Icons.receipt_long_outlined, size: 36, color: _muted),
        SizedBox(height: 8),
        Text('Nenhuma nota fiscal anexada',
            style: TextStyle(fontSize: 13, color: _muted)),
      ]),
    );
  }
}

// ─── Full-screen image viewer ────────────────────────────────────────────────
class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({required this.product});
  final Product product;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  final _downloadService = InvoiceDownloadService();
  bool _isDownloading = false;

  Future<void> _download() async {
    final url = widget.product.noteImageUrl;
    if (url == null) return;
    setState(() => _isDownloading = true);
    try {
      await _downloadService.saveInvoiceImage(
          url: url, fileName: _invoiceFileName(widget.product));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar nota fiscal: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'Salvar nota fiscal',
            onPressed: _isDownloading ? null : _download,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child:
              Image.network(widget.product.noteImageUrl!, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
