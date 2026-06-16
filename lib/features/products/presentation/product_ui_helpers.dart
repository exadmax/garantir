import 'package:flutter/material.dart';

import '../../categories/domain/category.dart';
import '../domain/product.dart';

// ─── Status helpers ───────────────────────────────────────────────────────────
enum ProductStatus { active, warn, soon, expired }

ProductStatus productStatus(Product p) {
  final days = p.warrantyEndDate.difference(DateTime.now()).inDays;
  if (days < 0) return ProductStatus.expired;
  if (days <= 30) return ProductStatus.soon;
  if (days <= 180) return ProductStatus.warn;
  return ProductStatus.active;
}

int daysRemaining(Product p) =>
    p.warrantyEndDate.difference(DateTime.now()).inDays;

class StatusColors {
  const StatusColors(this.dot, this.bg, this.text, this.label);
  final Color dot, bg, text;
  final String label;
}

const statusColors = {
  ProductStatus.active: StatusColors(
      Color(0xFF1F8A5B), Color(0xFFE6F5EE), Color(0xFF1F8A5B), 'Ativa'),
  ProductStatus.warn: StatusColors(
      Color(0xFFC4A12B), Color(0xFFFBF5DE), Color(0xFF8A6F0F), 'Atenção'),
  ProductStatus.soon: StatusColors(
      Color(0xFFE08A2B), Color(0xFFFCEEDC), Color(0xFF9C5B12), 'Vencendo'),
  ProductStatus.expired: StatusColors(
      Color(0xFF9AA5B2), Color(0xFFF1F3F5), Color(0xFF6B7785), 'Expirada'),
};

String categoryEmoji(String catId, List<ProductCategory> cats) {
  final cat = cats.where((c) => c.id == catId).firstOrNull;
  if (cat == null) return '📦';
  final n = normalize(cat.name);
  if (n.contains('eletrodom')) return '🔌';
  if (n.contains('eletr') || n.contains('celular')) return '📱';
  if (n.contains('veiculo') || n.contains('carro') || n.contains('auto'))
    return '🚗';
  if (n.contains('ferram')) return '🔧';
  if (n.contains('movel') || n.contains('sofa')) return '🛋';
  if (n.contains('servic')) return '🛠️';
  return '📦';
}

String normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');
