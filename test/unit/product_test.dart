import 'package:flutter_test/flutter_test.dart';
import 'package:soyyo/features/products/domain/guarantee_type.dart';
import 'package:soyyo/features/products/domain/product.dart';

void main() {
  group('Product', () {
    final past = DateTime(2020, 1, 1);
    final future = DateTime(2099, 12, 31);
    final purchase = DateTime(2023, 6, 1);

    Product make({required DateTime warrantyEnd}) => Product(
          id: 'p1',
          name: 'TV 4K',
          categoryId: 'cat1',
          purchaseDate: purchase,
          warrantyEndDate: warrantyEnd,
          guaranteeType: GuaranteeType.standard,
        );

    test('isExpired retorna true quando warrantyEndDate é passado', () {
      expect(make(warrantyEnd: past).isExpired, isTrue);
    });

    test('isExpired retorna false quando warrantyEndDate é futuro', () {
      expect(make(warrantyEnd: future).isExpired, isFalse);
    });

    test('toMap inclui todos os campos obrigatórios', () {
      final p = make(warrantyEnd: future);
      final map = p.toMap();
      expect(map.containsKey('name'), isTrue);
      expect(map.containsKey('categoryId'), isTrue);
      expect(map.containsKey('purchaseDate'), isTrue);
      expect(map.containsKey('warrantyEndDate'), isTrue);
      expect(map.containsKey('guaranteeType'), isTrue);
      expect(map['name'], equals('TV 4K'));
      expect(map['guaranteeType'], equals('standard'));
    });

    test('toMap com noteImageUrl e description nulos', () {
      final map = make(warrantyEnd: future).toMap();
      expect(map['noteImageUrl'], isNull);
      expect(map['description'], isNull);
    });

    test('toMap com noteImageUrl e description preenchidos', () {
      final p = Product(
        id: 'p2',
        name: 'Geladeira',
        categoryId: 'cat2',
        purchaseDate: purchase,
        warrantyEndDate: future,
        guaranteeType: GuaranteeType.extended,
        noteImageUrl: 'https://storage/img.jpg',
        description: 'Modelo XYZ',
      );
      final map = p.toMap();
      expect(map['noteImageUrl'], equals('https://storage/img.jpg'));
      expect(map['description'], equals('Modelo XYZ'));
    });
  });

  group('GuaranteeType', () {
    test('todos os valores têm labels', () {
      for (final t in GuaranteeType.values) {
        expect(t.label, isNotEmpty);
      }
    });

    test('label de standard é legível em português', () {
      expect(GuaranteeType.standard.label, isNotEmpty);
      expect(GuaranteeType.extended.label, isNotEmpty);
      expect(GuaranteeType.maintenance.label, isNotEmpty);
    });

    test('nomes dos valores coincidem com o enum', () {
      expect(GuaranteeType.standard.name, equals('standard'));
      expect(GuaranteeType.extended.name, equals('extended'));
      expect(GuaranteeType.maintenance.name, equals('maintenance'));
    });
  });
}
