import 'package:flutter_test/flutter_test.dart';
import 'package:soyyo/features/categories/domain/category.dart';

void main() {
  group('ProductCategory.fromMap', () {
    test('lê campos corretamente', () {
      final cat = ProductCategory.fromMap('id1', {
        'name': 'Eletrônicos',
        'isDefault': true,
      });
      expect(cat.id, equals('id1'));
      expect(cat.name, equals('Eletrônicos'));
      expect(cat.isDefault, isTrue);
    });

    test('usa defaults quando campos são nulos', () {
      final cat = ProductCategory.fromMap('id2', {});
      expect(cat.name, equals('Sem nome'));
      expect(cat.isDefault, isFalse);
    });

    test('faz trim no nome', () {
      final cat = ProductCategory.fromMap('id3', {'name': '  Eletrodomésticos  '});
      expect(cat.name, equals('Eletrodomésticos'));
    });
  });

  group('ProductCategory.toMap', () {
    test('serializa campos corretamente', () {
      final cat = ProductCategory(id: 'id4', name: 'Móveis', isDefault: false);
      final map = cat.toMap();
      expect(map['name'], equals('Móveis'));
      expect(map['isDefault'], isFalse);
      expect(map.containsKey('id'), isFalse);
    });

    test('serializa isDefault=true', () {
      final cat = ProductCategory(id: 'id5', name: 'Serviços', isDefault: true);
      expect(cat.toMap()['isDefault'], isTrue);
    });
  });

  group('ProductCategory constructor', () {
    test('isDefault padrão é false', () {
      final cat = ProductCategory(id: 'x', name: 'Teste');
      expect(cat.isDefault, isFalse);
    });
  });
}
