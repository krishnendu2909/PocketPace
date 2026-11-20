
import 'package:material_ui/material_ui.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/recurring_transaction_service.dart';
import 'services/background_task_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications and device timezone.
  await NotificationService.instance.initialize();

  // Process due transactions when the app opens.
  try {
    await RecurringTransactionService.instance
        .processDueTransactions();
  } catch (error) {
    debugPrint('Recurring transaction processing failed: $error');
  }

  // Initialize Android background processing.
  await Workmanager().initialize(callbackDispatcher);

  // Schedule recurring transaction checks every hour.
  await Workmanager().registerPeriodicTask(
    recurringTaskUniqueName,
    recurringTaskName,
    frequency: const Duration(hours: 1),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(const PocketPaceApp());
}
