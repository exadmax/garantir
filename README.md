# SoyYo (Garantir)

Aplicacao Flutter para Android e Web focada em gestao de garantias de produtos.

## Escopo inicial implementado

- CRUD basico de produtos (adicionar, listar, editar e excluir)
- Categorias padrao e categorias personalizadas
- Tipos de garantia:
	- Padrao
	- Estendida
	- Manutencao
- Captura da nota fiscal pela camera com upload para Firebase Storage
- Integracao preparada com Firebase Firestore
- Alertas automaticos de garantia (7 dias antes e no dia do vencimento)
- Produto associado por `categoryId` real e exibicao com nome da categoria

## Estrutura criada

- `lib/main.dart`: bootstrap Flutter + Firebase
- `lib/app/app.dart`: configuracao do MaterialApp
- `lib/features/products`: dominio, dados e telas de produtos
- `lib/features/categories`: dominio e tela de categorias
- `lib/features/alerts`: servico base de notificacoes locais
- `lib/firebase_options.dart`: placeholder para opcoes Firebase
- `pubspec.yaml`: dependencias do projeto

## Dependencias principais

- `firebase_core`
- `cloud_firestore`
- `firebase_storage`
- `image_picker`
- `flutter_local_notifications`
- `intl`
- `uuid`

## Pre-requisitos

Este container ainda nao possui o Flutter instalado por padrao.

1. Instale Flutter SDK na maquina/container.
2. Valide com:

```bash
flutter --version
flutter doctor
```

## Configuracao Firebase (Android e Web)

1. Crie um projeto no Firebase Console.
2. Habilite Firestore Database.
3. Habilite Firebase Storage.
4. Registre app Android (`com.example.soyyo` ou seu pacote real).
5. Registre app Web.
6. Instale FlutterFire CLI e gere a configuracao:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

7. Substitua o arquivo `lib/firebase_options.dart` placeholder pelo gerado automaticamente.

### Firebase Storage no Web (CORS)

Para upload de imagens em deploy Web (ex.: GitHub Pages), o bucket precisa aceitar a origem do frontend.
Sem isso, o navegador bloqueia o preflight (`OPTIONS`) com erro de CORS.

1. Ajuste as origens permitidas em `storage.cors.json` (inclua seu dominio de producao).
2. Aplique no bucket:

```bash
bash scripts/apply_storage_cors.sh omegabackend-88ebc.firebasestorage.app
```

3. Publique as regras do Storage:

```bash
firebase deploy --only storage
```

Observacao: CORS do bucket nao e publicado pelo `firebase deploy`; ele precisa ser aplicado via `gcloud` ou `gsutil` (o script acima faz isso).

## Como executar

```bash
flutter pub get
flutter run -d android
flutter run -d chrome
```

## Modelo de colecoes no Firestore

- `products`
	- `name` (string)
	- `categoryId` (string)
	- `purchaseDate` (timestamp)
	- `warrantyEndDate` (timestamp)
	- `guaranteeType` (string)
	- `noteImageUrl` (string opcional)
	- `description` (string opcional)

- `categories`
	- `name` (string)
	- `isDefault` (bool)

## Proximos passos recomendados

1. Criar regra de seguranca do Firestore e Storage por usuario autenticado.
2. Adicionar autenticacao (Firebase Auth) para separar dados por usuario.
3. Configurar timezone dinamico por dispositivo para alertas locais.
4. Adicionar camada de estado (Provider, Riverpod ou Bloc).
5. Criar tela de dashboard com garantias proximas do vencimento.
