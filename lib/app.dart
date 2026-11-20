
import 'package:material_ui/material_ui.dart';

import 'theme/app_theme.dart';
import 'data/local_database.dart';
import 'models/budget_profile.dart';

import 'features/onboarding/onboarding_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/budgets/category_budgets_screen.dart';
import 'features/reports/monthly_report_screen.dart';
import 'features/recurring/recurring_transactions_screen.dart';

import 'services/notification_service.dart';
import 'services/backup_service.dart';

class PocketPaceApp extends StatefulWidget {
  const PocketPaceApp({super.key});

  @override
  State<PocketPaceApp> createState() => _PocketPaceAppState();
}

class _PocketPaceAppState extends State<PocketPaceApp> {
  ThemeMode _themeMode = ThemeMode.light;
  late Future<BudgetProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = LocalDatabase.instance.getProfile();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  Future<void> _saveProfile(BudgetProfile profile) async {
    await LocalDatabase.instance.saveProfile(profile);
    if (!mounted) return;
    setState(() {
      _profileFuture = LocalDatabase.instance.getProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketPace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: FutureBuilder<BudgetProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Unable to load your profile: ${snapshot.error}',
                ),
              ),
            );
          }

          if (snapshot.data == null) {
            return OnboardingScreen(onComplete: _saveProfile);
          }

          return MainNavigation(
            profile: snapshot.data!,
            themeMode: _themeMode,
            onToggleTheme: _toggleTheme,
          );
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final BudgetProfile profile;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const MainNavigation({
    super.key,
    required this.profile,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _insightsRefreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onToggleTheme: widget.onToggleTheme,
        themeMode: widget.themeMode,
        profile: widget.profile,
      ),
      InsightsScreen(
        key: ValueKey(_insightsRefreshKey),
        profile: widget.profile,
      ),
      SettingsScreen(
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 1) _insightsRefreshKey++;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backupReminderEnabled = false;
  bool _isReminderLoaded = false;
  bool _isUpdatingReminder = false;

  @override
  void initState() {
    super.initState();
    _loadBackupReminderStatus();
  }

  Future<void> _loadBackupReminderStatus() async {
    try {
      final service = NotificationService.instance;
      await service.initialize();

      final pendingNotifications =
          await service.getPendingNotifications();

      final isScheduled = pendingNotifications.any(
        (notification) =>
            notification.id ==
            NotificationService.monthlyBackupNotificationId,
      );

      if (!mounted) return;

      setState(() {
        _backupReminderEnabled = isScheduled;
        _isReminderLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isReminderLoaded = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load reminder status: $error'),
        ),
      );
    }
  }

  Future<void> _toggleBackupReminder(bool enabled) async {
    if (_isUpdatingReminder) return;

    setState(() {
      _isUpdatingReminder = true;
    });

    try {
      final service = NotificationService.instance;

      if (enabled) {
        final granted = await service.requestPermission();

        if (!granted) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please allow notifications in Android settings.',
              ),
            ),
          );
          return;
        }

        await service.scheduleMonthlyBackupReminder();
      } else {
        await service.cancelMonthlyBackupReminder();
      }

      if (!mounted) return;

      setState(() {
        _backupReminderEnabled = enabled;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Monthly backup reminder enabled!'
                : 'Monthly backup reminder disabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update reminder: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingReminder = false;
        });
      }
    }
  }

  Future<void> _testNotification(BuildContext context) async {
    final service = NotificationService.instance;
    final granted = await service.requestPermission();
    if (!context.mounted) return;

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please allow notifications in Android settings.'),
        ),
      );
      return;
    }

    await service.showTestNotification();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification sent!')),
    );
  }

  Future<void> _createBackup(BuildContext context) async {
    try {
      final savedPath =
          await BackupService.instance.createBackup();

      if (!context.mounted) return;

      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup cancelled.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PocketPace backup created successfully!'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $error'),
        ),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore Backup?'),
          content: const Text(
            'Restoring a backup will replace all your current '
            'PocketPace data, including transactions, budgets and '
            'recurring transactions.\n\n'
            'This action cannot be undone. Make sure you have '
            'created a backup of your current data first.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final fileName =
          await BackupService.instance.restoreBackup();

      if (!context.mounted) return;

      if (fileName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore cancelled. No data was changed.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup restored successfully: $fileName'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $error'),
        ),
      );
    }
  }

  void _openCategoryBudgets(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryBudgetsScreen(),
      ),
    );
  }

  void _openMonthlyReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MonthlyReportScreen(),
      ),
    );
  }

  void _openRecurringTransactions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecurringTransactionsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark Mode'),
              subtitle: const Text('Change the appearance of PocketPace'),
              value: isDarkMode,
              onChanged: (_) => widget.onToggleTheme(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Category Budgets'),
              subtitle: const Text('Set and manage monthly spending limits'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openCategoryBudgets(context),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assessment_outlined),
              title: const Text('Monthly Report'),
              subtitle: const Text(
                'View income, expenses, savings and spending breakdown',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openMonthlyReport(context),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Recurring Transactions'),
              subtitle: const Text(
                'Schedule salary, rent, bills and subscriptions',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openRecurringTransactions(context),
            ),
          ),
          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.backup_outlined),
              title: const Text('Monthly Backup Reminder'),
              subtitle: Text(
                !_isReminderLoaded
                    ? 'Checking reminder status...'
                    : 'Remind me on the 1st of every month at 10:00 AM',
              ),
              value: _backupReminderEnabled,
              onChanged: !_isReminderLoaded || _isUpdatingReminder
                  ? null
                  : _toggleBackupReminder,
            ),
          ),
          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Data Management',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Create Backup'),
              subtitle: const Text(
                'Export your PocketPace data as a JSON file',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _createBackup(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore Backup'),
              subtitle: const Text(
                'Restore your data from a PocketPace JSON backup',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _restoreBackup(context),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Test Notifications'),
              subtitle: const Text('Check whether Android notifications work'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _testNotification(context),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('PocketPace'),
              subtitle: const Text('Personal finance tracker'),
              trailing: const Text('v1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}
