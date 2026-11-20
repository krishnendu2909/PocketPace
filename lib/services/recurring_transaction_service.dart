
import '../data/local_database.dart';
import '../models/transaction_record.dart';
import 'notification_service.dart';

class RecurringTransactionService {
  RecurringTransactionService._();

  static final RecurringTransactionService instance =
      RecurringTransactionService._();

  final LocalDatabase _database = LocalDatabase.instance;

  Future<int> processDueTransactions({
    DateTime? throughDate,
  }) async {
    final today = throughDate ?? DateTime.now();
    final dueItems =
        await _database.getDueRecurringTransactions(today);

    int processedCount = 0;

    for (final item in dueItems) {
      final id = item['id'] as int;
      final frequency = item['frequency'] as String;

      DateTime dueDate =
          DateTime.parse(item['next_due_date'] as String);

      final endDateString = item['end_date'] as String?;
      final endDate = endDateString == null
          ? null
          : DateTime.parse(endDateString);

      while (!dueDate.isAfter(today) &&
          (endDate == null || !dueDate.isAfter(endDate))) {
        final alreadyProcessed =
            await _database.hasRecurringOccurrence(
          recurringTransactionId: id,
          occurrenceDate: dueDate,
        );

        if (!alreadyProcessed) {
          final transactionId =
              await _database.addTransaction(
            TransactionRecord(
              title: item['title'] as String,
              category: item['category'] as String,
              amountMinor: item['amount_minor'] as int,
              type: item['type'] as String,
              date: dueDate,
              note: 'Automatically generated recurring transaction',
            ),
          );

          final recorded =
              await _database.recordRecurringOccurrence(
            recurringTransactionId: id,
            occurrenceDate: dueDate,
            transactionId: transactionId,
          );

          if (recorded) {
            processedCount++;

            try {
              final amount =
                  (item['amount_minor'] as int) / 100;

              final formattedAmount =
                  amount.toStringAsFixed(2);

              await NotificationService.instance.showNotification(
                id: (id * 1000 +
                    dueDate.year * 10000 +
                    dueDate.month * 100 +
                    dueDate.day) &
                    0x7FFFFFFF,
                title: 'Recurring transaction recorded',
                body:
                    '${item['title']} - ₹$formattedAmount has been added.',
              );
            } catch (error) {
              // Notification failure should not undo a saved transaction.
            }
          } else {
            await _database.deleteTransaction(transactionId);
          }
        }

        dueDate = _nextDueDate(dueDate, frequency);
      }

      await _database.updateRecurringNextDueDate(
        id: id,
        nextDueDate: dueDate,
      );
    }

    return processedCount;
  }

  DateTime _nextDueDate(DateTime date, String frequency) {
    switch (frequency) {
      case 'daily':
        return date.add(const Duration(days: 1));

      case 'weekly':
        return date.add(const Duration(days: 7));

      case 'monthly':
        final nextMonth = DateTime(date.year, date.month + 1, 1);
        final lastDay =
            DateTime(nextMonth.year, nextMonth.month + 1, 0).day;

        return DateTime(
          nextMonth.year,
          nextMonth.month,
          date.day > lastDay ? lastDay : date.day,
          date.hour,
          date.minute,
          date.second,
        );

      case 'yearly':
        final nextYear = date.year + 1;
        final lastDay =
            DateTime(nextYear, date.month + 1, 0).day;

        return DateTime(
          nextYear,
          date.month,
          date.day > lastDay ? lastDay : date.day,
          date.hour,
          date.minute,
          date.second,
        );

      default:
        throw ArgumentError('Unsupported frequency: $frequency');
    }
  }
}
