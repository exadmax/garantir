---
name: flutter-testing
description: "Gera e executa testes Flutter para Android e Web. Use para: criar testes de widget, testes unitários e testes de integração; rodar a suíte de testes no Android ou no Chrome; verificar cobertura; depurar falhas em testes específicos. Gatilhos: gerar testes, criar teste, rodar testes, executar testes, testar android, testar web, cobertura de testes."
argument-hint: "ex: 'gerar testes para ProductRepository' ou 'rodar todos os testes web'"
---

# Flutter Testing — Android & Web

## Quando Usar
- Criar testes unitários para serviços, repositórios ou modelos
- Criar testes de widget para páginas e componentes
- Executar a suíte completa de testes no Android (JVM) ou Web (Chrome)
- Verificar cobertura após alterações

---

## Arquitetura de Testes do Projeto

```
test/
  widget_test.dart          # Smoke test principal (SoyYoApp renderiza)
  unit/                     # Testes unitários (criar se não existir)
    products/
    categories/
    auth/
  widget/                   # Testes de widget por feature
    products/
    categories/
    auth/
  integration/              # Testes de integração (flutter_test driver)
```

Convenção de nomes: `<nome_do_arquivo>_test.dart`

---

## Procedure — Gerar Testes

### 1. Identificar o alvo
- Se o alvo for um **modelo/domínio** (`product.dart`, `category.dart`) → teste unitário em `test/unit/`
- Se o alvo for um **repositório/serviço** → teste unitário com mocks em `test/unit/`
- Se o alvo for uma **página/widget** → teste de widget em `test/widget/`

### 2. Ler o arquivo-alvo
Sempre ler o arquivo antes de gerar o teste para entender assinaturas, dependências e comportamento esperado.

### 3. Dependências para mocks
- Use o pacote `mockito` com `@GenerateMocks` para serviços Firebase e repositórios Isar
- Para widgets que dependem de Firebase/Isar, envolva em `MaterialApp` e injete dependências fake

### 4. Estrutura padrão de teste unitário

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:soyyo/features/<feature>/domain/<arquivo>.dart';

// @GenerateMocks([<ClasseDependencia>])
void main() {
  group('<ClasseAlvo>', () {
    setUp(() {
      // inicializar mocks
    });

    test('<comportamento esperado>', () {
      // arrange
      // act
      // assert
    });
  });
}
```

### 5. Estrutura padrão de teste de widget

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soyyo/features/<feature>/presentation/<pagina>.dart';

void main() {
  testWidgets('<Página> renderiza <elemento>', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: <Pagina>()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(<Widget>), findsOneWidget);
  });
}
```

---

## Procedure — Executar Testes

### Todos os testes (VM — padrão)
```bash
flutter test
```

### Teste único
```bash
flutter test test/widget_test.dart
```

### Testes no Android (dispositivo/emulador conectado)
```bash
flutter test integration_test/ -d android
```
> Requer `integration_test` no `pubspec.yaml` e um emulador ou dispositivo ativo.

### Testes na Web (Chrome)
```bash
flutter test --platform chrome
```
> Usa o Chrome instalado. Na CI, use `CHROME_EXECUTABLE` apontando para o Chromium.

### Com cobertura
```bash
flutter test --coverage
# Relatório HTML (requer lcov):
genhtml coverage/lcov.info -o coverage/html
```

---

## Procedure — Rotina Completa de Testes

Execute na ordem abaixo antes de qualquer PR ou release:

1. **Análise estática**
   ```bash
   flutter analyze
   ```
   Corrija todos os warnings antes de continuar.

2. **Testes unitários e de widget (VM)**
   ```bash
   flutter test
   ```

3. **Testes na Web**
   ```bash
   flutter test --platform chrome
   ```
   > Atenção: `WarrantyAlertService` usa guard `kIsWeb` — notificações são no-op na Web, não causam falha.

4. **Build de verificação Android**
   ```bash
   flutter build apk --debug
   ```

5. **Testes de integração no Android** *(quando emulador disponível)*
   ```bash
   flutter test integration_test/ -d android
   ```

---

## Diferenças Android × Web

| Aspecto | Android | Web |
|---|---|---|
| Notificações locais | ✅ `flutter_local_notifications` ativo | 🚫 no-op (`kIsWeb`) |
| Isar | ✅ nativo | ✅ via `isar_web` WASM |
| Firebase Storage | ✅ | ✅ |
| Camera (image_picker) | ✅ | ✅ (via browser) |
| Platform channel mocks | Necessário para notificações | Não necessário |

Em testes de widget que usam `WarrantyAlertService`, mocke o método `scheduleWarrantyAlerts` para evitar erros de platform channel.

---

## Referências do Projeto
- Modelo de produto: [lib/features/products/domain/product.dart](../../../lib/features/products/domain/product.dart)
- Repositório: [lib/features/products/data/product_repository.dart](../../../lib/features/products/data/product_repository.dart)
- Teste existente: [test/widget_test.dart](../../../test/widget_test.dart)
- CLAUDE.md: [CLAUDE.md](../../../CLAUDE.md)
