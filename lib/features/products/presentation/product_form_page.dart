import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../alerts/warranty_alert_service.dart';
import '../../categories/domain/category.dart';
import '../data/invoice_storage_service.dart';
import '../data/product_repository.dart';
import '../domain/guarantee_type.dart';
import '../domain/product.dart';

const _brand  = Color(0xFF1F6E8C);
const _bg     = Color(0xFFF4F6F8);
const _border = Color(0xFFEEF1F4);
const _muted  = Color(0xFF6B7785);
const _dark   = Color(0xFF1A1F26);

// Pre-defined warranty month options (0 = custom)
const _warrantyMonthOptions = [3, 6, 12, 24, 36, 0];

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.existing});
  final Product? existing;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ProductRepository();
  final _invoiceService = InvoiceStorageService();
  final _alertService = WarrantyAlertService();
  final _uuid = const Uuid();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  DateTime _warrantyEndDate = DateTime.now().add(const Duration(days: 365));
  GuaranteeType _guaranteeType = GuaranteeType.standard;
  String? _noteImageUrl;
  String? _selectedCategoryId;
  XFile? _selectedImage;
  bool _isSaving = false;

  // Warranty chip selection: null = custom, otherwise months
  int? _selectedMonths = 12;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _selectedCategoryId = e.categoryId;
      _descController.text = e.description ?? '';
      _purchaseDate = e.purchaseDate;
      _warrantyEndDate = e.warrantyEndDate;
      _guaranteeType = e.guaranteeType;
      _noteImageUrl = e.noteImageUrl;
      // Try to match existing duration
      final dur = e.warrantyEndDate.difference(e.purchaseDate);
      final months = (dur.inDays / 30.44).round();
      _selectedMonths = _warrantyMonthOptions.contains(months) && months != 0 ? months : null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onMonthChipTap(int months) {
    if (months == 0) {
      setState(() => _selectedMonths = null);
      return;
    }
    setState(() {
      _selectedMonths = months;
      _warrantyEndDate = DateTime(
        _purchaseDate.year, _purchaseDate.month + months, _purchaseDate.day,
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final img = await ImagePicker().pickImage(source: source);
      if (img != null) setState(() => _selectedImage = img);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'Câmera não disponível neste dispositivo'
                  : 'Não foi possível acessar a galeria',
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }
    if (!_warrantyEndDate.isAfter(_purchaseDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O vencimento da garantia deve ser posterior à data de compra')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final id = widget.existing?.id ?? _uuid.v4();

      // Try to upload the image, but do not block the save if it fails.
      var noteUrl = _noteImageUrl;
      if (_selectedImage != null) {
        try {
          noteUrl = await _invoiceService.uploadInvoiceImage(
              productId: id, image: _selectedImage!);
        } catch (uploadErr) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Foto não enviada: ${_uploadErrorMessage(uploadErr)}. '
                  'O produto será salvo sem ela.',
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      final product = Product(
        id: id,
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        purchaseDate: _purchaseDate,
        warrantyEndDate: _warrantyEndDate,
        guaranteeType: _guaranteeType,
        noteImageUrl: noteUrl,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      );
      await _repo.saveProduct(product);

      // Schedule alerts without blocking the save on Android.
      _alertService.scheduleWarrantyAlerts(
        productId: id,
        productName: product.name,
        warrantyEndDate: product.warrantyEndDate,
      ).catchError((Object e) {
        debugPrint('Erro ao agendar alerta: $e');
      });

      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _uploadErrorMessage(Object err) {
    final msg = err.toString().toLowerCase();
    if (msg.contains('token') ||
        msg.contains('app-check') ||
        msg.contains('app check') ||
        msg.contains('unauthorized') ||
        msg.contains('permission')) {
      return 'Erro de permissão no servidor';
    }
    if (msg.contains('timeout') || msg.contains('tempo')) {
      return 'Tempo de conexão esgotado';
    }
    return 'Verifique sua conexão e tente novamente';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: _dark),
        title: Text(
          isEdit ? 'Editar produto' : 'Novo produto',
          style: const TextStyle(color: _dark, fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo capture
            _SectionLabel('FOTO DA NOTA FISCAL'),
            const SizedBox(height: 8),
            Row(children: [
              _PhotoTile(
                icon: Icons.camera_alt_outlined,
                label: 'Câmera',
                active: _selectedImage != null || _noteImageUrl != null,
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(width: 10),
              _PhotoTile(
                icon: Icons.photo_library_outlined,
                label: 'Galeria',
                active: false,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ]),
            const SizedBox(height: 20),

            // Identification
            _SectionLabel('IDENTIFICAÇÃO'),
            const SizedBox(height: 8),
            _FormCard(children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome do produto'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<ProductCategory>>(
                stream: _repo.watchCategories(),
                builder: (ctx, snap) {
                  final cats = snap.data ?? const <ProductCategory>[];
                  return DropdownButtonFormField<String>(
                    value: cats.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) => v == null ? 'Selecione uma categoria' : null,
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  hintText: 'Número de série, modelo, etc.',
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Warranty
            _SectionLabel('GARANTIA'),
            const SizedBox(height: 8),
            _FormCard(children: [
              const Text('Duração da garantia', style: TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ..._warrantyMonthOptions.map((m) {
                  final isCustom = m == 0;
                  final isActive = isCustom ? _selectedMonths == null : _selectedMonths == m;
                  return GestureDetector(
                    onTap: () => _onMonthChipTap(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? _brand : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: isActive ? _brand : _border),
                      ),
                      child: Text(
                        isCustom ? 'Outro' : '${m}m',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : _muted,
                        ),
                      ),
                    ),
                  );
                }),
              ]),
              const SizedBox(height: 14),
              _DateRow(
                label: 'Data da compra',
                date: _purchaseDate,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() {
                      _purchaseDate = d;
                      if (_selectedMonths != null) {
                        _warrantyEndDate = DateTime(d.year, d.month + _selectedMonths!, d.day);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              _DateRow(
                label: 'Vencimento da garantia',
                date: _warrantyEndDate,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _warrantyEndDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() { _warrantyEndDate = d; _selectedMonths = null; });
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<GuaranteeType>(
                value: _guaranteeType,
                decoration: const InputDecoration(labelText: 'Tipo de garantia'),
                items: GuaranteeType.values
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                    .toList(),
                onChanged: (v) { if (v != null) setState(() => _guaranteeType = v); },
              ),
            ]),
            const SizedBox(height: 20),

            // Summary card
            _SummaryCard(purchaseDate: _purchaseDate, warrantyEndDate: _warrantyEndDate),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.8),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE8F1F5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _brand : _border, width: active ? 1.5 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 28, color: active ? _brand : _muted),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: active ? _brand : _muted, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: _muted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: _muted))),
          Text(fmt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark)),
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.purchaseDate, required this.warrantyEndDate});
  final DateTime purchaseDate, warrantyEndDate;

  @override
  Widget build(BuildContext context) {
    final totalDays = warrantyEndDate.difference(purchaseDate).inDays;
    final remaining = warrantyEndDate.difference(DateTime.now()).inDays;
    final progress = totalDays > 0
        ? (DateTime.now().difference(purchaseDate).inDays / totalDays).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_brand, Color(0xFF185973)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Resumo da cobertura', style: TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 8),
        Row(children: [
          Text(
            remaining < 0 ? 'Expirada' : '$remaining dias restantes',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total: $totalDays dias de cobertura',
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ]),
    );
  }
}
