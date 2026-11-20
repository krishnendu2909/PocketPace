
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../data/local_database.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const int backupFormatVersion = 1;
  static const int databaseVersion = 5;

  static const Map<String, List<String>> _tableColumns = {
    'budget_profile': [
      'id',
      'monthly_income_minor',
      'fixed_expenses_minor',
      'savings_target_minor',
      'buffer_minor',
      'currency',
      'created_at',
    ],
    'transactions': [
      'id',
      'title',
      'category',
      'amount_minor',
      'type',
      'date',
      'note',
      'created_at',
    ],
    'category_budgets': [
      'category',
      'monthly_limit_minor',
      'created_at',
    ],
    'budget_alert_history': [
      'id',
      'category',
      'month_key',
      'alert_level',
      'created_at',
    ],
    'recurring_transactions': [
      'id',
      'title',
      'category',
      'amount_minor',
      'type',
      'frequency',
      'start_date',
      'next_due_date',
      'end_date',
      'is_active',
      'created_at',
    ],
    'recurring_transaction_occurrences': [
      'id',
      'recurring_transaction_id',
      'occurrence_date',
      'transaction_id',
      'created_at',
    ],
  };

  /// Creates a JSON backup of all PocketPace database tables.
  Future<String?> createBackup() async {
    final Database db = await LocalDatabase.instance.database;

    final Map<String, dynamic> tableData = {};

    for (final tableName in _tableColumns.keys) {
      tableData[tableName] = await db.query(tableName);
    }

    final Map<String, dynamic> backupData = {
      'app': 'PocketPace',
      'backup_format_version': backupFormatVersion,
      'database_version': databaseVersion,
      'created_at': DateTime.now().toIso8601String(),
      'data': tableData,
    };

    final String jsonString =
        const JsonEncoder.withIndent('  ').convert(backupData);

    final Uint8List bytes = Uint8List.fromList(
      utf8.encode(jsonString),
    );

    return FilePicker.platform.saveFile(
      dialogTitle: 'Save PocketPace Backup',
      fileName: 'pocketpace_backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
  }

  /// Selects, validates and restores a PocketPace JSON backup.
  ///
  /// Returns the selected filename after successful restoration.
  /// Returns null if the user cancels file selection.
  Future<String?> restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select PocketPace Backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('The selected backup file is empty.');
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('The selected file is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file structure.');
    }

    _validateBackup(decoded);

    final data = decoded['data'] as Map<String, dynamic>;

    final Database db = await LocalDatabase.instance.database;

    await db.transaction((txn) async {
      // Delete child records before their related parent records.
      for (final tableName in [
        'recurring_transaction_occurrences',
        'recurring_transactions',
        'budget_alert_history',
        'category_budgets',
        'transactions',
        'budget_profile',
      ]) {
        await txn.delete(tableName);
      }

      // Restore parent records before dependent records.
      for (final tableName in [
        'budget_profile',
        'transactions',
        'category_budgets',
        'budget_alert_history',
        'recurring_transactions',
        'recurring_transaction_occurrences',
      ]) {
        final rows = data[tableName] as List<dynamic>;

        final batch = txn.batch();

        for (final row in rows) {
          batch.insert(
            tableName,
            Map<String, Object?>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }

        await batch.commit(noResult: true);
      }
    });

    return file.name;
  }

  /// Validates backup metadata, table structure and record relationships.
  void _validateBackup(Map<String, dynamic> backup) {
    if (backup['app'] != 'PocketPace') {
      throw const FormatException(
        'This backup does not belong to PocketPace.',
      );
    }

    if (backup['backup_format_version'] != backupFormatVersion) {
      throw const FormatException(
        'Unsupported backup format version.',
      );
    }

    if (backup['database_version'] != databaseVersion) {
      throw const FormatException(
        'This backup uses an unsupported database version.',
      );
    }

    if (backup['created_at'] is! String) {
      throw const FormatException('Invalid backup creation date.');
    }

    try {
      DateTime.parse(backup['created_at'] as String);
    } catch (_) {
      throw const FormatException('Invalid backup creation date.');
    }

    final data = backup['data'];

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Backup data is missing or invalid.');
    }

    // Every expected table must be present and contain valid rows.
    for (final entry in _tableColumns.entries) {
      final tableName = entry.key;
      final columns = entry.value;
      final rows = data[tableName];

      if (rows is! List) {
        throw FormatException('Invalid data for table: $tableName');
      }

      for (final row in rows) {
        if (row is! Map) {
          throw FormatException(
            'Invalid record in table: $tableName',
          );
        }

        for (final column in columns) {
          if (!row.containsKey(column)) {
            throw FormatException(
              'Missing $column in table $tableName.',
            );
          }
        }
      }
    }

    _validateRelationships(data);
  }

  /// Checks recurring occurrence references before database changes.
  void _validateRelationships(Map<String, dynamic> data) {
    final recurringRows =
        data['recurring_transactions'] as List<dynamic>;

    final transactionRows =
        data['transactions'] as List<dynamic>;

    final occurrenceRows =
        data['recurring_transaction_occurrences'] as List<dynamic>;

    final recurringIds = <int>{};
    final transactionIds = <int>{};

    for (final row in recurringRows) {
      final id = row['id'];

      if (id is! int || !recurringIds.add(id)) {
        throw const FormatException(
          'Invalid or duplicate recurring transaction ID.',
        );
      }
    }

    for (final row in transactionRows) {
      final id = row['id'];

      if (id is! int || !transactionIds.add(id)) {
        throw const FormatException(
          'Invalid or duplicate transaction ID.',
        );
      }
    }

    final occurrenceKeys = <String>{};

    for (final row in occurrenceRows) {
      final recurringId = row['recurring_transaction_id'];
      final transactionId = row['transaction_id'];
      final occurrenceDate = row['occurrence_date'];

      if (recurringId is! int ||
          !recurringIds.contains(recurringId)) {
        throw const FormatException(
          'A recurring occurrence references a missing schedule.',
        );
      }

      if (transactionId != null &&
          (transactionId is! int ||
              !transactionIds.contains(transactionId))) {
        throw const FormatException(
          'A recurring occurrence references a missing transaction.',
        );
      }

      if (occurrenceDate is! String) {
        throw const FormatException(
          'Invalid recurring occurrence date.',
        );
      }

      final key = '$recurringId|$occurrenceDate';

      if (!occurrenceKeys.add(key)) {
        throw const FormatException(
          'Duplicate recurring occurrence found.',
        );
      }
    }
  }
}
