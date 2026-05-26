import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/auth_service.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/categories_page.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_form_page.dart';
import '../../products/presentation/products_page.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _brand     = Color(0xFF1F6E8C);
const _brandDark = Color(0xFF185973);
const _bg        = Color(0xFFF4F6F8);
const _border    = Color(0xFFEEF1F4);
const _dark      = Color(0xFF1A1F26);
const _muted     = Color(0xFF6B7785);
const _light     = Color(0xFF8893A1);

// ─── Coverage model ───────────────────────────────────────────────────────────
enum _Status { active, warn, soon, expired }

class _Cover {
  const _Cover({required this.product, required this.status, required this.days});
  final Product product;
  final _Status status;
  final int days;
}

_Cover _computeCoverage(Product p) {
  final days = p.warrantyEndDate.difference(DateTime.now()).inDays;
  final _Status s;
  if (days < 0) {
    s = _Status.expired;
  } else if (days <= 30) {
    s = _Status.soon;
  } else if (days <= 180) {
    s = _Status.warn;
  } else {
    s = _Status.active;
  }
  return _Cover(product: p, status: s, days: days);
}

// ─── Category helpers ─────────────────────────────────────────────────────────
String _catIcon(String catId, List<ProductCategory> cats) {
  final cat = cats.where((c) => c.id == catId).firstOrNull;
  if (cat == null) return '📦';
  final n = _norm(cat.name);
  if (n.contains('eletrodom')) return '🔌';
  if (n.contains('eletr') || n.contains('celular')) return '📱';
  if (n.contains('veiculo') || n.contains('carro') || n.contains('auto')) return '🚗';
  if (n.contains('ferram')) return '🔧';
  if (n.contains('movel') || n.contains('sofa')) return '🛋';
  if (n.contains('servic')) return '🛠️';
  if (n.contains('esporte') || n.contains('sport')) return '⚽';
  if (n.contains('vestua') || n.contains('roupa')) return '👕';
  return '📦';
}

Color _catTint(String catId, List<ProductCategory> cats) {
  final cat = cats.where((c) => c.id == catId).firstOrNull;
  if (cat == null) return const Color(0xFFEEEEEE);
  final n = _norm(cat.name);
  if (n.contains('eletrodom')) return const Color(0xFFEEF0F3);
  if (n.contains('eletr')) return const Color(0xFFE8F1F5);
  if (n.contains('veiculo') || n.contains('carro')) return const Color(0xFFE8EEF5);
  if (n.contains('ferram')) return const Color(0xFFF0EDE8);
  if (n.contains('movel') || n.contains('sofa')) return const Color(0xFFF2EEE8);
  final h = cat.name.codeUnits.fold(0, (a, b) => a ^ b);
  const tints = [
    Color(0xFFE8F1F5), Color(0xFFEEF0F3), Color(0xFFF2EEE8),
    Color(0xFFF0EDE8), Color(0xFFE8EEF5), Color(0xFFEEF3E8),
  ];
  return tints[h % tints.length];
}

String _norm(String s) => s.toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');

// ─── Status colors ────────────────────────────────────────────────────────────
class _SC { const _SC(this.dot, this.bg, this.text); final Color dot, bg, text; }
const _sc = {
  _Status.active:  _SC(Color(0xFF1F8A5B), Color(0xFFE6F5EE), Color(0xFF1F8A5B)),
  _Status.warn:    _SC(Color(0xFFC4A12B), Color(0xFFFBF5DE), Color(0xFF8A6F0F)),
  _Status.soon:    _SC(Color(0xFFE08A2B), Color(0xFFFCEEDC), Color(0xFF9C5B12)),
  _Status.expired: _SC(Color(0xFF9AA5B2), Color(0xFFF1F3F5), Color(0xFF6B7785)),
};

// ─── Dashboard page ───────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _repo = ProductRepository();
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _repo.seedDefaultCategories().catchError((Object e) {
      debugPrint('seedDefaultCategories: $e');
    });
    _repo.syncIfNeeded().catchError((Object e) {
      debugPrint('syncIfNeeded: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<List<ProductCategory>>(
        stream: _repo.watchCategories(),
        builder: (ctx, catSnap) {
          if (catSnap.hasError) {
            return _FirestoreErrorView(error: catSnap.error);
          }
          return StreamBuilder<List<Product>>(
            stream: _repo.watchProducts(),
            builder: (ctx, prodSnap) {
              if (prodSnap.hasError) {
                return _FirestoreErrorView(error: prodSnap.error);
              }
              return _DashBody(
                products: prodSnap.data ?? [],
                categories: catSnap.data ?? [],
                onLogout: _auth.signOut,
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _DashBody extends StatelessWidget {
  const _DashBody({required this.products, required this.categories, required this.onLogout});
  final List<Product> products;
  final List<ProductCategory> categories;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final covers = products.map(_computeCoverage).toList();

    var nActive = 0, nSoon = 0, nExpired = 0;
    for (final c in covers) {
      switch (c.status) {
        case _Status.active:
        case _Status.warn:
          nActive++;
        case _Status.soon:
          nSoon++;
        case _Status.expired:
          nExpired++;
      }
    }
    final total = products.length;
    final healthPct = total > 0 ? ((nActive + nSoon) * 100 ~/ total) : 0;

    final soonest = (covers.where((c) => c.status != _Status.expired).toList()
          ..sort((a, b) => a.days.compareTo(b.days)))
        .take(3)
        .toList();
    final expired = covers.where((c) => c.status == _Status.expired).toList();
    final recent = (covers.toList()
          ..sort((a, b) => b.product.purchaseDate.compareTo(a.product.purchaseDate)))
        .take(4)
        .toList();

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim() ?? '';
    final name = displayName.split(' ').where((s) => s.isNotEmpty).firstOrNull ?? 'você';
    final raw = displayName.isNotEmpty ? displayName : '?';
    final initials = raw.split(RegExp(r'\s+')).where((s) => s.isNotEmpty)
        .take(2).map((s) => s[0].toUpperCase()).join();

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                name: name, initials: initials,
                healthPct: healthPct, nActive: nActive, nSoon: nSoon, nExpired: nExpired,
                badgeCount: nSoon + nExpired,
                onSettings: () => _showSettings(context),
              ),
              Padding(
                padding: const EdgeInsets.only(top: -56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // KPI cards
                      Row(children: [
                        Expanded(child: _KpiCard(label: 'Total', value: total, icon: Icons.inventory_2_outlined, tint: _brand)),
                        const SizedBox(width: 10),
                        Expanded(child: _KpiCard(label: 'Vencendo', value: nSoon, icon: Icons.schedule_outlined, tint: const Color(0xFFE08A2B), urgent: nSoon > 0)),
                        const SizedBox(width: 10),
                        Expanded(child: _KpiCard(label: 'Expiradas', value: nExpired, icon: Icons.remove_circle_outline, tint: _muted)),
                      ]),
                      const SizedBox(height: 16),

                      // Quick actions
                      Column(children: [
                        Row(children: [
                          Expanded(child: _ActionTile(
                            title: 'Cadastrar produto',
                            sub: 'Tire foto da nota e pronto',
                            icon: Icons.add_box_outlined,
                            primary: true,
                            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductFormPage())),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _ActionTile(
                            title: 'Meus produtos',
                            sub: '$total cadastrados',
                            icon: Icons.view_list_outlined,
                            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductsPage())),
                          )),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _ActionTile(
                            title: 'Categorias',
                            sub: 'Organize do seu jeito',
                            icon: Icons.category_outlined,
                            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CategoriesPage())),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _ActionTile(
                            title: 'Notas fiscais',
                            sub: 'Acesse rápido',
                            icon: Icons.receipt_long_outlined,
                            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductsPage())),
                          )),
                        ]),
                      ]),

                      // Urgent banner
                      if (nSoon > 0) ...[
                        const SizedBox(height: 16),
                        _UrgentBanner(
                          count: nSoon,
                          nextDate: soonest.isNotEmpty ? soonest.first.product.warrantyEndDate : null,
                        ),
                      ],

                      // Expiring soon
                      if (soonest.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _SectionHeader(
                          title: 'Vencendo em breve',
                          sub: 'Aproveite enquanto está coberto',
                          cta: 'Ver todos',
                          onCta: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductsPage())),
                        ),
                        const SizedBox(height: 10),
                        ...soonest.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ExpiringRow(cover: c, categories: categories),
                        )),
                      ],

                      // Recent
                      if (recent.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _SectionHeader(
                          title: 'Cadastros recentes',
                          cta: 'Ver todos',
                          onCta: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductsPage())),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 185,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recent.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => _RecentCard(cover: recent[i], categories: categories),
                          ),
                        ),
                      ],

                      // Expired
                      if (expired.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _SectionHeader(
                          title: 'Garantias expiradas',
                          sub: 'Mantemos o histórico aqui',
                        ),
                        const SizedBox(height: 10),
                        ...expired.take(2).map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ExpiredRow(cover: c, categories: categories),
                        )),
                        if (expired.length > 2)
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductsPage())),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Text('+ mais', textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brand)),
                            ),
                          ),
                      ],

                      const SizedBox(height: 22),
                      const _TipCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _BottomNav(onLogout: onLogout),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair da conta'),
            onTap: () { Navigator.pop(context); onLogout(); },
          ),
        ]),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.name, required this.initials,
    required this.healthPct, required this.nActive, required this.nSoon, required this.nExpired,
    required this.badgeCount, required this.onSettings,
  });
  final String name, initials;
  final int healthPct, nActive, nSoon, nExpired, badgeCount;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [_brand, _brandDark],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Avatar
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Olá,', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.78))),
              Text('$name 👋', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1)),
            ])),
            _IconBtn(badge: badgeCount, onTap: () {}, child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 18)),
            const SizedBox(width: 8),
            _IconBtn(onTap: onSettings, child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18)),
          ]),
          const SizedBox(height: 16),
          Text('Status das suas garantias', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.82))),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$healthPct%', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.6, height: 1.0)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('protegido', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.86))),
            ),
          ]),
          const SizedBox(height: 18),
          _SegmentBar(nActive: nActive, nSoon: nSoon, nExpired: nExpired),
          const SizedBox(height: 10),
          Row(children: [
            _LegendDot(color: const Color(0xFF7FE5B5), count: nActive, label: 'Ativas'),
            const SizedBox(width: 14),
            _LegendDot(color: const Color(0xFFFFD58A), count: nSoon, label: 'Vencendo'),
            const SizedBox(width: 14),
            _LegendDot(color: const Color(0xFFE6CDB5), count: nExpired, label: 'Expiradas'),
          ]),
        ],
      ),
    );
  }
}


class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.child, required this.onTap, this.badge = 0});
  final Widget child;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: Colors.white.withValues(alpha: 0.16),
          ),
          alignment: Alignment.center,
          child: child,
        ),
        if (badge > 0) Positioned(
          top: -2, right: -2,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16),
            height: 16,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5C5C),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _brand, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.nActive, required this.nSoon, required this.nExpired});
  final int nActive, nSoon, nExpired;

  @override
  Widget build(BuildContext context) {
    final total = nActive + nSoon + nExpired;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: Colors.white.withValues(alpha: 0.18),
        child: total == 0 ? null : Row(children: [
          if (nActive > 0) Flexible(flex: nActive, child: Container(color: const Color(0xFF7FE5B5))),
          if (nSoon > 0) Flexible(flex: nSoon, child: Container(color: const Color(0xFFFFD58A))),
          if (nExpired > 0) Flexible(flex: nExpired, child: Container(color: const Color(0xFFE6CDB5))),
        ]),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.count, required this.label});
  final Color color;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
    ]);
  }
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.icon, required this.tint, this.urgent = false});
  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x08141E28), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: tint, size: 16),
        ),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.5, height: 1.0)),
          if (urgent) ...[
            const SizedBox(width: 4),
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFE08A2B), shape: BoxShape.circle)),
          ],
        ]),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11.5, color: _light)),
      ]),
    );
  }
}

// ─── Action tile ──────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.title, required this.sub, required this.icon, required this.onTap, this.primary = false});
  final String title, sub;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: primary ? _brand : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: _border),
          boxShadow: primary
              ? [BoxShadow(color: _brand.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 6))]
              : const [BoxShadow(color: Color(0x08141E28), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: primary ? Colors.white.withValues(alpha: 0.18) : _bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primary ? Colors.white : const Color(0xFF4A5563), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary ? Colors.white : _dark, letterSpacing: -0.2, height: 1.2)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: primary ? Colors.white.withValues(alpha: 0.82) : _light)),
          ])),
        ]),
      ),
    );
  }
}

// ─── Urgent banner ────────────────────────────────────────────────────────────
class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.count, this.nextDate});
  final int count;
  final DateTime? nextDate;

  @override
  Widget build(BuildContext context) {
    final fmt = nextDate != null ? DateFormat("d 'de' MMM yyyy", 'pt_BR').format(nextDate!) : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCE2BB)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFFCEEDC), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE08A2B), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count ${count == 1 ? 'garantia' : 'garantias'} vencendo em breve',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF9C5B12))),
          if (fmt != null) Text('Mais próxima: $fmt',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9C5B12))),
        ])),
      ]),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.sub, this.cta, this.onCta});
  final String title;
  final String? sub, cta;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.3)),
        if (sub != null) Text(sub!, style: const TextStyle(fontSize: 12, color: _light, height: 1.4)),
      ])),
      if (cta != null) GestureDetector(
        onTap: onCta,
        child: Text('$cta →', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _brand)),
      ),
    ]);
  }
}

// ─── Expiring row ─────────────────────────────────────────────────────────────
class _ExpiringRow extends StatelessWidget {
  const _ExpiringRow({required this.cover, required this.categories});
  final _Cover cover;
  final List<ProductCategory> categories;

  @override
  Widget build(BuildContext context) {
    final icon = _catIcon(cover.product.categoryId, categories);
    final tint = _catTint(cover.product.categoryId, categories);
    final style = _sc[cover.status]!;
    final expiresStr = DateFormat("d 'de' MMM yyyy", 'pt_BR').format(cover.product.warrantyEndDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(11)),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cover.product.description ?? cover.product.name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark, letterSpacing: -0.2)),
          Text('vence em $expiresStr', style: const TextStyle(fontSize: 11.5, color: _light)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(999)),
          child: Text(cover.days <= 0 ? 'hoje' : '${cover.days}d',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: style.text)),
        ),
      ]),
    );
  }
}

// ─── Recent card ──────────────────────────────────────────────────────────────
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.cover, required this.categories});
  final _Cover cover;
  final List<ProductCategory> categories;

  @override
  Widget build(BuildContext context) {
    final icon = _catIcon(cover.product.categoryId, categories);
    final tint = _catTint(cover.product.categoryId, categories);
    final style = _sc[cover.status]!;
    final months = cover.days >= 0 ? '${(cover.days / 30).round()}m restantes' : 'Expirou';

    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 78, width: double.infinity,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 36)),
        ),
        const SizedBox(height: 8),
        Text(cover.product.description ?? cover.product.name,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark, letterSpacing: -0.2, height: 1.2)),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: style.dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(months, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: style.text)),
        ]),
      ]),
    );
  }
}

// ─── Expired row ──────────────────────────────────────────────────────────────
class _ExpiredRow extends StatelessWidget {
  const _ExpiredRow({required this.cover, required this.categories});
  final _Cover cover;
  final List<ProductCategory> categories;

  @override
  Widget build(BuildContext context) {
    final icon = _catIcon(cover.product.categoryId, categories);
    final expiresStr = DateFormat("d 'de' MMM yyyy", 'pt_BR').format(cover.product.warrantyEndDate);

    return Opacity(
      opacity: 0.82,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cover.product.description ?? cover.product.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4A5563), letterSpacing: -0.1)),
            Text('Expirou em $expiresStr', style: const TextStyle(fontSize: 11, color: _light)),
          ])),
        ]),
      ),
    );
  }
}

// ─── Tip card ─────────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brand.withValues(alpha: 0.12)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Dica', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.2)),
          SizedBox(height: 3),
          Text('Tire fotos legíveis de todas as suas notas. Quanto mais detalhes, mais fácil acionar a garantia.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF4A5563), height: 1.5)),
        ])),
      ]),
    );
  }
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.onLogout});
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 10, 8, 10 + bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [BoxShadow(color: Color(0x0A141E28), blurRadius: 18, offset: Offset(0, -4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _NavItem(icon: Icons.home_rounded, label: 'Início', active: true),
        _NavItem(
          icon: Icons.inventory_2_outlined,
          label: 'Produtos',
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductsPage())),
        ),
        // FAB
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductFormPage())),
          child: Container(
            width: 52, height: 52,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: _brand, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _brand.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 26),
          ),
        ),
        _NavItem(
          icon: Icons.grid_view_outlined,
          label: 'Categorias',
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CategoriesPage())),
        ),
        _NavItem(
          icon: Icons.person_outline_rounded,
          label: 'Perfil',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sair da conta'),
                onTap: () { Navigator.pop(context); onLogout(); },
              ),
            ])),
          ),
        ),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.active = false, this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _brand : _light;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

// ─── Firestore error view ─────────────────────────────────────────────────────
class _FirestoreErrorView extends StatelessWidget {
  const _FirestoreErrorView({this.error});
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _dark),
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
