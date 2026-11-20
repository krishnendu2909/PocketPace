
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/budget_profile.dart';
import '../models/transaction_record.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _database;

  // ------------------------------------------
  // DATABASE INITIALIZATION
  // ------------------------------------------

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pocketpace.db');

    _database = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await _createBudgetProfileTable(db);
        await _createTransactionsTable(db);
        await _createCategoryBudgetsTable(db);
        await _createBudgetAlertHistoryTable(db);
        await _createRecurringTransactionsTable(db);
        await _createRecurringTransactionOccurrencesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTransactionsTable(db);
        }

        if (oldVersion < 3) {
          await _createCategoryBudgetsTable(db);
        }

        if (oldVersion < 4) {
          await _createBudgetAlertHistoryTable(db);
        }

        if (oldVersion < 5) {
          await _createRecurringTransactionsTable(db);
          await _createRecurringTransactionOccurrencesTable(db);
        }
      },
    );

    return _database!;
  }

  // ------------------------------------------
  // TABLE CREATION
  // ------------------------------------------

  Future<void> _createBudgetProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE budget_profile (
        id INTEGER PRIMARY KEY,
        monthly_income_minor INTEGER NOT NULL,
        fixed_expenses_minor INTEGER NOT NULL,
        savings_target_minor INTEGER NOT NULL,
        buffer_minor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_date
      ON transactions(date)
    ''');
  }

  Future<void> _createCategoryBudgetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE category_budgets (
        category TEXT PRIMARY KEY,
        monthly_limit_minor INTEGER NOT NULL
          CHECK(monthly_limit_minor > 0),
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createBudgetAlertHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE budget_alert_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        month_key TEXT NOT NULL,
        alert_level INTEGER NOT NULL CHECK(alert_level IN (80, 100, 101)),
        created_at TEXT NOT NULL,
        UNIQUE(category, month_key, alert_level)
      )
    ''');
  }

  Future<void> _createRecurringTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        frequency TEXT NOT NULL
          CHECK(frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
        start_date TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createRecurringTransactionOccurrencesTable(
    Database db,
  ) async {
    await db.execute('''
      CREATE TABLE recurring_transaction_occurrences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recurring_transaction_id INTEGER NOT NULL,
        occurrence_date TEXT NOT NULL,
        transaction_id INTEGER,
        created_at TEXT NOT NULL,
        UNIQUE(recurring_transaction_id, occurrence_date)
      )
    ''');
  }

  // ------------------------------------------
  // BUDGET PROFILE METHODS
  // ------------------------------------------

  Future<void> saveProfile(BudgetProfile profile) async {
    final db = await database;

    await db.insert(
      'budget_profile',
      {
        'id': 1,
        'monthly_income_minor': profile.monthlyIncomeMinor,
        'fixed_expenses_minor': profile.fixedExpensesMinor,
        'savings_target_minor': profile.savingsTargetMinor,
        'buffer_minor': profile.bufferMinor,
        'currency': profile.currency,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<BudgetProfile?> getProfile() async {
    final db = await database;

    final result = await db.query(
      'budget_profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final row = result.first;

    return BudgetProfile(
      monthlyIncomeMinor: row['monthly_income_minor'] as int,
      fixedExpensesMinor: row['fixed_expenses_minor'] as int,
      savingsTargetMinor: row['savings_target_minor'] as int,
      bufferMinor: row['buffer_minor'] as int,
      currency: row['currency'] as String,
    );
  }

  // ------------------------------------------
  // ADD TRANSACTION
  // ------------------------------------------

  Future<int> addTransaction(TransactionRecord record) async {
    if (record.title.trim().isEmpty) {
      throw ArgumentError('Transaction title cannot be empty.');
    }

    if (record.amountMinor <= 0) {
      throw ArgumentError(
        'Transaction amount must be greater than zero.',
      );
    }

    if (record.type != 'income' && record.type != 'expense') {
      throw ArgumentError(
        'Transaction type must be income or expense.',
      );
    }

    final db = await database;

    return await db.insert(
      'transactions',
      {
        'title': record.title.trim(),
        'category': record.category,
        'amount_minor': record.amountMinor,
        'type': record.type,
        'date': record.date.toIso8601String(),
        'note': record.note,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  // ------------------------------------------
  // GET ALL TRANSACTIONS
  // ------------------------------------------

  Future<List<TransactionRecord>> getTransactions() async {
    final db = await database;

    final result = await db.query(
      'transactions',
      orderBy: 'date DESC, id DESC',
    );

    return result.map((row) {
      return TransactionRecord(
        id: row['id'] as int,
        title: row['title'] as String,
        category: row['category'] as String,
        amountMinor: row['amount_minor'] as int,
        type: row['type'] as String,
        date: DateTime.parse(row['date'] as String),
        note: row['note'] as String?,
      );
    }).toList();
  }

  // ------------------------------------------
  // GET MONTHLY TRANSACTIONS
  // ------------------------------------------

  Future<List<TransactionRecord>> getMonthlyTransactions(
    DateTime month,
  ) async {
    final db = await database;

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);

    final result = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC, id DESC',
    );

    return result.map((row) {
      return TransactionRecord(
        id: row['id'] as int,
        title: row['title'] as String,
        category: row['category'] as String,
        amountMinor: row['amount_minor'] as int,
        type: row['type'] as String,
        date: DateTime.parse(row['date'] as String),
        note: row['note'] as String?,
      );
    }).toList();
  }

  // ------------------------------------------
  // MONTHLY EXPENSE TOTAL
  // ------------------------------------------

  Future<int> getMonthlySpentMinor(DateTime month) async {
    final db = await database;

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS total
      FROM transactions
      WHERE type = ?
      AND date >= ?
      AND date < ?
      ''',
      [
        'expense',
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
    );

    return (result.first['total'] as num).toInt();
  }

  // ------------------------------------------
  // MONTHLY INCOME TOTAL
  // ------------------------------------------

  Future<int> getMonthlyIncomeMinor(DateTime month) async {
    final db = await database;

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS total
      FROM transactions
      WHERE type = ?
      AND date >= ?
      AND date < ?
      ''',
      [
        'income',
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
    );

    return (result.first['total'] as num).toInt();
  }

  // ------------------------------------------
  // MONTHLY EXPENSES BY CATEGORY
  // ------------------------------------------

  Future<Map<String, int>> getMonthlyExpensesByCategory(
    DateTime month,
  ) async {
    final db = await database;

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);

    final result = await db.rawQuery(
      '''
      SELECT category, SUM(amount_minor) AS total
      FROM transactions
      WHERE type = ?
        AND date >= ?
        AND date < ?
      GROUP BY category
      ORDER BY total DESC
      ''',
      [
        'expense',
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
    );

    return {
      for (final row in result)
        row['category'] as String:
            (row['total'] as num).toInt(),
    };
  }

  // ------------------------------------------
  // UPDATE TRANSACTION
  // ------------------------------------------

  Future<int> updateTransaction(
    TransactionRecord transaction,
  ) async {
    if (transaction.id == null) {
      throw ArgumentError(
        'Transaction ID is required for updating.',
      );
    }

    if (transaction.title.trim().isEmpty) {
      throw ArgumentError(
        'Transaction title cannot be empty.',
      );
    }

    if (transaction.amountMinor <= 0) {
      throw ArgumentError(
        'Transaction amount must be greater than zero.',
      );
    }

    if (transaction.type != 'income' &&
        transaction.type != 'expense') {
      throw ArgumentError(
        'Transaction type must be income or expense.',
      );
    }

    final db = await database;

    return await db.update(
      'transactions',
      {
        'title': transaction.title.trim(),
        'category': transaction.category,
        'amount_minor': transaction.amountMinor,
        'type': transaction.type,
        'date': transaction.date.toIso8601String(),
        'note': transaction.note,
      },
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // ------------------------------------------
  // DELETE TRANSACTION
  // ------------------------------------------

  Future<int> deleteTransaction(int id) async {
    final db = await database;

    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  // ------------------------------------------
  // RECURRING TRANSACTION METHODS
  // ------------------------------------------

  Future<int> saveRecurringTransaction({
    int? id,
    required String title,
    required String category,
    required int amountMinor,
    required String type,
    required String frequency,
    required DateTime startDate,
    required DateTime nextDueDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Recurring transaction title cannot be empty.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError('Category cannot be empty.');
    }
    if (amountMinor <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (!['income', 'expense'].contains(type)) {
      throw ArgumentError('Type must be income or expense.');
    }
    if (!['daily', 'weekly', 'monthly', 'yearly'].contains(frequency)) {
      throw ArgumentError('Invalid recurring frequency.');
    }
    if (endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError('End date cannot be before start date.');
    }

    final db = await database;
    final values = <String, Object?>{
      'title': title.trim(),
      'category': category.trim(),
      'amount_minor': amountMinor,
      'type': type,
      'frequency': frequency,
      'start_date': startDate.toIso8601String(),
      'next_due_date': nextDueDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };

    if (id == null) {
      values['created_at'] = DateTime.now().toIso8601String();
      return db.insert('recurring_transactions', values);
    }

    return db.update(
      'recurring_transactions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> getRecurringTransactions({
    bool activeOnly = false,
  }) async {
    final db = await database;
    return db.query(
      'recurring_transactions',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'next_due_date ASC, id DESC',
    );
  }

  Future<List<Map<String, Object?>>> getDueRecurringTransactions(
    DateTime throughDate,
  ) async {
    final db = await database;
    return db.query(
      'recurring_transactions',
      where: 'is_active = ? AND next_due_date <= ? '
          'AND (end_date IS NULL OR end_date >= ?)',
      whereArgs: [
        1,
        throughDate.toIso8601String(),
        throughDate.toIso8601String(),
      ],
      orderBy: 'next_due_date ASC',
    );
  }

  Future<int> setRecurringTransactionActive(int id, bool isActive) async {
    final db = await database;
    return db.update(
      'recurring_transactions',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRecurringTransaction(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.delete(
        'recurring_transaction_occurrences',
        where: 'recurring_transaction_id = ?',
        whereArgs: [id],
      );
      return txn.delete(
        'recurring_transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<bool> recordRecurringOccurrence({
    required int recurringTransactionId,
    required DateTime occurrenceDate,
    int? transactionId,
  }) async {
    final db = await database;
    final insertedId = await db.insert(
      'recurring_transaction_occurrences',
      {
        'recurring_transaction_id': recurringTransactionId,
        'occurrence_date': occurrenceDate.toIso8601String(),
        'transaction_id': transactionId,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return insertedId != -1;
  }

  Future<bool> hasRecurringOccurrence({
    required int recurringTransactionId,
    required DateTime occurrenceDate,
  }) async {
    final db = await database;
    final result = await db.query(
      'recurring_transaction_occurrences',
      columns: ['id'],
      where: 'recurring_transaction_id = ? AND occurrence_date = ?',
      whereArgs: [
        recurringTransactionId,
        occurrenceDate.toIso8601String(),
      ],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> updateRecurringNextDueDate({
    required int id,
    required DateTime nextDueDate,
  }) async {
    final db = await database;
    return db.update(
      'recurring_transactions',
      {'next_due_date': nextDueDate.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------------------------------------------
  // BUDGET ALERT HISTORY
  // ------------------------------------------

  Future<bool> recordBudgetAlertIfNew({
    required String category,
    required DateTime month,
    required int alertLevel,
  }) async {
    if (category.trim().isEmpty) {
      throw ArgumentError('Category cannot be empty.');
    }

    if (![80, 100, 101].contains(alertLevel)) {
      throw ArgumentError('Invalid budget alert level.');
    }

    final db = await database;
    final monthKey =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';

    final insertedId = await db.insert(
      'budget_alert_history',
      {
        'category': category.trim(),
        'month_key': monthKey,
        'alert_level': alertLevel,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // SQLite returns -1 when the unique key already exists.
    return insertedId != -1;
  }

  Future<bool> hasBudgetAlertBeenSent({
    required String category,
    required DateTime month,
    required int alertLevel,
  }) async {
    if (![80, 100, 101].contains(alertLevel)) {
      throw ArgumentError('Invalid budget alert level.');
    }

    final db = await database;
    final monthKey =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';

    final result = await db.query(
      'budget_alert_history',
      columns: ['id'],
      where: 'category = ? AND month_key = ? AND alert_level = ?',
      whereArgs: [category.trim(), monthKey, alertLevel],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // ------------------------------------------
  // CATEGORY BUDGET METHODS
  // ------------------------------------------

  Future<void> saveCategoryBudget({
    required String category,
    required int monthlyLimitMinor,
  }) async {
    if (category.trim().isEmpty) {
      throw ArgumentError('Category cannot be empty.');
    }

    if (monthlyLimitMinor <= 0) {
      throw ArgumentError('Budget must be greater than zero.');
    }

    final db = await database;

    await db.insert(
      'category_budgets',
      {
        'category': category.trim(),
        'monthly_limit_minor': monthlyLimitMinor,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, int>> getCategoryBudgets() async {
    final db = await database;

    final result = await db.query('category_budgets');

    return {
      for (final row in result)
        row['category'] as String:
            row['monthly_limit_minor'] as int,
    };
  }

  Future<int> deleteCategoryBudget(String category) async {
    final db = await database;

    return await db.delete(
      'category_budgets',
      where: 'category = ?',
      whereArgs: [category],
    );
  }
}
