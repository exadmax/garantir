import 'package:isar/isar.dart';

part 'sync_meta_isar_schema.g.dart';

@Collection()
class SyncMetaIsarSchema {
  // Fixed ID = 1: there is always exactly one record in this collection.
  Id id = 1;

  DateTime? lastSyncAt;

  // Firebase Auth uid dos dados locais. Se outro usuário logar no mesmo
  // aparelho, o Isar é limpo e re-sincronizado para não vazar dados.
  String? uid;
}
