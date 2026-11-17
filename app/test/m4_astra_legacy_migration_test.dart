// Upgrade the actual archived M3 regression database and compare every legacy value.
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_trainer/data/db/database.dart';
import 'package:puppy_trainer/data/db/sync_tables.dart';
import 'package:puppy_trainer/data/repositories/care_repository.dart';
import 'package:puppy_trainer/data/repositories/repositories.dart';
import 'helpers.dart';

void main() {
  test('Astra archived real M3 data upgrades without changing any legacy field',
      () async {
    final dir = Directory('../tests/regression/m4a-2026-11-17');
    final before =
        jsonDecode(File('${dir.path}/m3-before.json').readAsStringSync())
            as Map;
    File('../${before['source']}').copySync('${dir.path}/m3-upgrade.sqlite');
    final db =
        AppDatabase(NativeDatabase(File('${dir.path}/m3-upgrade.sqlite')));
    final counts = <String, int>{};
    for (final entry in (before['tables'] as Map).entries) {
      final table = entry.key as String;
      final rows = (entry.value as List).cast<Map>();
      final after = await db.customSelect('SELECT * FROM "$table"').get();
      expect(after.length, rows.length, reason: '$table row count');
      // Compare complete legacy row sets independently of SQLite result order.
      String canonical(Map row) {
        final keys = row.keys.cast<String>().toList()..sort();
        return jsonEncode({for (final k in keys) k: row[k]});
      }

      final columns =
          rows.isEmpty ? <String>[] : rows.first.keys.cast<String>().toList();
      final expected = rows.map(canonical).toList()..sort();
      final actual = after
          .map((r) => canonical({for (final k in columns) k: r.data[k]}))
          .toList()
        ..sort();
      expect(actual, expected, reason: '$table every legacy column');
      counts[table] = rows.length;
    }
    for (final t in syncTables) {
      final missing = await db
          .customSelect(
              "SELECT COUNT(*) AS n FROM ${t.name} WHERE client_updated_at IS NULL OR client_updated_at = ''")
          .getSingle();
      expect(missing.read<int>('n'), 0, reason: '${t.name} timestamps');
    }
    final lib = await loadRepoContent(db: db);
    final dog = (await DogRepository(db).currentDog())!;
    await CareRepository(db).syncDefaults(dog, lib.careCalendar);
    final careCount = (await db.select(db.careReminders).get()).length;
    expect(careCount, greaterThan(0));
    final version = (await db.customSelect('PRAGMA user_version').getSingle())
        .data
        .values
        .single;
    expect(version, 4);
    File('${dir.path}/migration-result.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'source': before['source'],
      'from': 3,
      'to': version,
      'all_legacy_fields_equal': true,
      'counts': counts,
      'all_sync_timestamps_present': true,
      'care_count': careCount,
    }));
    await db.close();
  });
}
