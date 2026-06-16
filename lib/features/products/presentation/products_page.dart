import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../alerts/warranty_alert_service.dart';
import '../../categories/domain/category.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'product_detail_page.dart';
import 'product_form_page.dart';
import 'product_ui_helpers.dart';

const _brand = Color(0xFF1F6E8C);
const _bg = Color(0xFFF4F6F8);
const _muted = Color(0xFF6B7785);
const _border = Color(0xFFEEF1F4);

// ─── Filter chip enum ─────────────────────────────────────────────────────────
enum _Filter { all, active, soon, expired }

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _repo = ProductRepository();
  final _alertService = WarrantyAlertService();
  final _searchCtrl = TextEditingController();

  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(Product p) async {
    await _repo.deleteProduct(p.id);
    await _alertService.cancelAlertsForProduct(p.id);
  }

  List<Product> _applyFilters(List<Product> all) {
    var list = all;
    if (_query.trim().isNotEmpty) {
      final q = normalize(_query.trim());
      list = list.where((p) => normalize(p.name).contains(q)).toList();
    }
    switch (_filter) {
      case _Filter.all:
        break;
      case _Filter.active:
        list = list.where((p) {
          final s = productStatus(p);
          return s == ProductStatus.active || s == ProductStatus.warn;
        }).toList();
      case _Filter.soon:
        list =
            list.where((p) => productStatus(p) == ProductStatus.soon).toList();
      case _Filter.expired:
        list = list
            .where((p) => productStatus(p) == ProductStatus.expired)
            .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<List<ProductCategory>>(
        stream: _repo.watchCategories(),
        builder: (ctx, catSnap) {
          if (catSnap.hasError) {
            return _StreamErrorView(error: catSnap.error);
          }
          final cats = catSnap.data ?? const <ProductCategory>[];
          return StreamBuilder<List<Product>>(
            stream: _repo.watchProducts(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return _StreamErrorView(error: snap.error);
              }
              final all = snap.data ?? const <Product>[];
              final nActive = all.where((p) {
                final s = productStatus(p);
                return s == ProductStatus.active || s == ProductStatus.warn;
              }).length;
              final nSoon = all
                  .where((p) => productStatus(p) == ProductStatus.soon)
                  .length;
              final nExpired = all
                  .where((p) => productStatus(p) == ProductStatus.expired)
                  .length;
              final filtered = _applyFilters(all);

              return CustomScrollView(
                slivers: [
                  _StickyHeader(
                    searchCtrl: _searchCtrl,
                    onBack: () => Navigator.of(context).pop(),
                    onAdd: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const ProductFormPage()),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _StatsStrip(
                          total: all.length, nActive: nActive, nSoon: nSoon),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _FilterChips(
                        selected: _filter,
                        counts: {
                          _Filter.all: all.length,
                          _Filter.active: nActive,
                          _Filter.soon: nSoon,
                          _Filter.expired: nExpired,
                        },
                        onSelect: (f) => setState(() => _filter = f),
                      ),
                    ),
                  ),
                  if (!snap.hasData)
                    const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()))
                  else if (filtered.isEmpty)
                    SliverFillRemaining(
                        child: _EmptyState(
                            isFiltered:
                                _query.isNotEmpty || _filter != _Filter.all))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProductCard(
                              product: filtered[i],
                              cats: cats,
                              onEdit: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ProductFormPage(existing: filtered[i])),
                              ),
                              onDelete: () => _delete(filtered[i]),
                            ),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProductFormPage()),
        ),
        backgroundColor: _brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─── Sticky header ────────────────────────────────────────────────────────────
class _StickyHeader extends StatelessWidget {
  const _StickyHeader(
      {required this.searchCtrl, required this.onBack, required this.onAdd});
  final TextEditingController searchCtrl;
  final VoidCallback onBack, onAdd;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120 + top,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, top + 16, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(Icons.arrow_back, color: Color(0xFF1A1F26)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Meus Produtos',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1F26))),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar produto...',
                prefixIcon: const Icon(Icons.search, color: _muted),
                filled: true,
                fillColor: _bg,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _brand, width: 1.5),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Stats strip ─────────────────────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  const _StatsStrip(
      {required this.total, required this.nActive, required this.nSoon});
  final int total, nActive, nSoon;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(label: 'Total', value: total, color: _brand)),
      const SizedBox(width: 10),
      Expanded(
          child: _StatCard(
              label: 'Ativas', value: nActive, color: const Color(0xFF1F8A5B))),
      const SizedBox(width: 10),
      Expanded(
          child: _StatCard(
              label: 'Vencendo', value: nSoon, color: const Color(0xFFE08A2B))),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  const _FilterChips(
      {required this.selected, required this.counts, required this.onSelect});
  final _Filter selected;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onSelect;

  @override
  Widget build(BuildContext context) {
    const opts = [
      (_Filter.all, 'Todos'),
      (_Filter.active, 'Ativas'),
      (_Filter.soon, 'Vencendo'),
      (_Filter.expired, 'Expiradas'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: opts.map((opt) {
          final active = selected == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(opt.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? _brand : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? _brand : _border),
                ),
                child: Text(
                  '${opt.$2} ${counts[opt.$1] ?? 0}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active ? Colors.white : _muted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.cats,
    required this.onEdit,
    required this.onDelete,
  });
  final Product product;
  final List<ProductCategory> cats;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final st = productStatus(product);
    final sc = statusColors[st]!;
    final days = daysRemaining(product);
    final fmt = DateFormat('dd/MM/yyyy');

    // Progress bar: how much of the warranty life remains (relative to purchase date)
    final totalDays =
        product.warrantyEndDate.difference(product.purchaseDate).inDays;
    final elapsed = DateTime.now().difference(product.purchaseDate).inDays;
    final progress =
        totalDays > 0 ? (elapsed / totalDays).clamp(0.0, 1.0) : 1.0;
    final emoji = categoryEmoji(product.categoryId, cats);
    final catName =
        cats.where((c) => c.id == product.categoryId).firstOrNull?.name ??
            'Sem categoria';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => ProductDetailPage(product: product, cats: cats)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1F26))),
                    const SizedBox(height: 2),
                    Text(catName,
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ])),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    color: sc.bg, borderRadius: BorderRadius.circular(999)),
                child: Text(sc.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sc.text)),
              ),
            ]),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: const Color(0xFFEEF1F4),
                valueColor: AlwaysStoppedAnimation<Color>(sc.dot),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text(
                days < 0
                    ? 'Expirou em ${fmt.format(product.warrantyEndDate)}'
                    : 'Vence em ${fmt.format(product.warrantyEndDate)}',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              const Spacer(),
              Text(
                days < 0
                    ? 'Expirada'
                    : days == 0
                        ? 'Expira hoje!'
                        : '$days dias restantes',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: sc.dot),
              ),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          ProductDetailPage(product: product, cats: cats)),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('Visualizar'),
                style: TextButton.styleFrom(
                  foregroundColor: _brand,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Editar'),
                style: TextButton.styleFrom(
                  foregroundColor: _brand,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('Excluir'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE05555),
                  textStyle: const TextStyle(fontSize: 12),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltered});
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('📦', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 16),
        Text(
          isFiltered
              ? 'Nenhum produto encontrado'
              : 'Nenhum produto cadastrado',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F26)),
        ),
        const SizedBox(height: 6),
        Text(
          isFiltered
              ? 'Tente outra busca ou filtro'
              : 'Cadastre seu primeiro produto',
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
      ]),
    );
  }
}

// ─── Stream error state ───────────────────────────────────────────────────────
class _StreamErrorView extends StatelessWidget {
  const _StreamErrorView({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 52, color: _muted),
          const SizedBox(height: 16),
          const Text(
            'Não foi possível carregar os dados',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1F26)),
          ),
          const SizedBox(height: 8),
          Text(
            error?.toString() ?? 'Verifique sua conexão e tente novamente.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ]),
      ),
    );
  }
}
