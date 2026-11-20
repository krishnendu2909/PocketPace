
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'recurring_transaction_service.dart';

const String recurringTaskName = 'pocketpaceRecurringTask';
const String recurringTaskUniqueName = 'pocketpaceRecurringSchedule';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == recurringTaskName) {
      try {
        // Initialize notifications in the background isolate.
        await NotificationService.instance.initialize();

        // Process any recurring transactions that are due.
        await RecurringTransactionService.instance
            .processDueTransactions();

        debugPrint(
          'PocketPace: Recurring transactions processed.',
        );

        return true;
      } catch (error) {
        debugPrint(
          'PocketPace background task failed: $error',
        );

        return false;
      }
    }

    return true;
  });
}
