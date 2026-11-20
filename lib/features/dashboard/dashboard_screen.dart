
import 'package:material_ui/material_ui.dart';

import '../../models/budget_profile.dart';
import '../../models/transaction_record.dart';
import '../../data/local_database.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transaction_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final BudgetProfile profile;

  const DashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
    required this.profile,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int get monthlyIncome => widget.profile.monthlyIncomeMinor;
  int get fixedExpenses => widget.profile.fixedExpensesMinor;
  int get savings => widget.profile.savingsTargetMinor;
  int get buffer => widget.profile.bufferMinor;

  int _spent = 0;
  Map<String, int> _categoryExpenses = {};
  List<int> _monthlySpending = List.filled(6, 0);
  List<TransactionRecord> _recentTransactions = [];

  int get spent => _spent;

  int get remainingDays {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return lastDay - now.day + 1;
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  // ------------------------------------------
  // LOAD TRANSACTIONS
  // ------------------------------------------

  Future<void> _loadTransactions() async {
    try {
      final now = DateTime.now();
      final months = List.generate(
        6,
        (index) => DateTime(now.year, now.month - 5 + index, 1),
      );

      final results = await Future.wait([
        LocalDatabase.instance.getMonthlySpentMinor(now),
        LocalDatabase.instance.getMonthlyTransactions(now),
        LocalDatabase.instance.getMonthlyExpensesByCategory(now),
        Future.wait(
          months.map(
            (month) =>
                LocalDatabase.instance.getMonthlySpentMinor(month),
          ),
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _spent = results[0] as int;
        _recentTransactions =
            (results[1] as List<TransactionRecord>)
                .take(5)
                .toList();
        _categoryExpenses = results[2] as Map<String, int>;
        _monthlySpending = (results[3] as List<int>);
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  // ------------------------------------------
  // ADD TRANSACTION
  // ------------------------------------------

  Future<void> _openAddTransaction() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTransactionScreen(),
      ),
    );

    if (result == true) {
      await _loadTransactions();
    }
  }

  // ------------------------------------------
  // TRANSACTION HISTORY NAVIGATION
  // ------------------------------------------

  Future<void> _openTransactionHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransactionHistoryScreen(),
      ),
    );

    if (mounted) {
      await _loadTransactions();
    }
  }

  // ------------------------------------------
  // FORMAT TRANSACTION DATE
  // ------------------------------------------

  String _formatTransactionDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  // ------------------------------------------
  // CURRENCY FORMATTER
  // ------------------------------------------

  String money(int amountMinor) {
    const currencySymbols = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'د.إ',
    };

    final symbol = currencySymbols[widget.profile.currency] ??
        '${widget.profile.currency} ';

    final amount = (amountMinor / 100).round();

    return '$symbol${amount.toString()}';
  }

  // ------------------------------------------
  // BUDGET CALCULATIONS
  // ------------------------------------------

  int get remainingBudget {
    return monthlyIncome -
        fixedExpenses -
        savings -
        buffer -
        spent;
  }

  int get dailyAllowance {
    if (remainingBudget <= 0 || remainingDays <= 0) {
      return 0;
    }

    return remainingBudget ~/ remainingDays;
  }

  // ------------------------------------------
  // BUILD DASHBOARD
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'PocketPace',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch theme',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GREETING

              const Text(
                'Good morning 👋',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Stay in control of your money.',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.7,
                ),
              ),

              const SizedBox(height: 22),

              // OVERVIEW HEADING

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.outlineVariant,
                      ),
                    ),
                    child: Text(
                      widget.profile.currency,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // SAFE TO SPEND CARD

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(23),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF123D35),
                      Color(0xFF16745D),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SAFE TO SPEND TODAY',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Text(
                      money(dailyAllowance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.2,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Your recommended daily allowance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 22),

                    Divider(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Remaining this month',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          money(remainingBudget),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // MONTHLY SUMMARY

              Text(
                'Monthly summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: 'Income',
                      amount: money(monthlyIncome),
                      icon: Icons.south_west_rounded,
                      color: const Color(0xFF16A36A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      title: 'Fixed costs',
                      amount: money(fixedExpenses),
                      icon: Icons.north_east_rounded,
                      color: const Color(0xFFE58A42),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // SAVINGS ALLOCATION

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.savings_outlined,
                        color: colors.primary,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Savings allocation',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            money(savings),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Icon(
                      Icons.trending_up_rounded,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // CATEGORY-WISE EXPENSE BREAKDOWN

              Text(
                'Spending by category',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              _categoryBreakdown(),

              const SizedBox(height: 25),

              // SIX-MONTH SPENDING TREND

              Text(
                'Monthly spending trend',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              _monthlySpendingChart(),

              const SizedBox(height: 25),

              // RECENT ACTIVITY HEADING

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  TextButton(
                    onPressed: _openTransactionHistory,
                    child: const Text('View All'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // RECENT TRANSACTIONS

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.outlineVariant,
                  ),
                ),
                child: _recentTransactions.isEmpty
                    ? Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 32,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No transactions yet',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Tap Add Transaction to record your '
                            'first expense.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: _recentTransactions.map((transaction) {
                          final isIncome =
                              transaction.type == 'income';

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: isIncome
                                        ? const Color(0xFF16A36A)
                                            .withValues(alpha: 0.12)
                                        : const Color(0xFFE58A42)
                                            .withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isIncome
                                        ? Icons.south_west_rounded
                                        : Icons.north_east_rounded,
                                    color: isIncome
                                        ? const Color(0xFF16A36A)
                                        : const Color(0xFFE58A42),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        transaction.title,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${transaction.category} • '
                                        '${_formatTransactionDate(transaction.date)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Text(
                                  '${isIncome ? '+' : '-'}'
                                  '${money(transaction.amountMinor)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome
                                        ? const Color(0xFF16A36A)
                                        : colors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),

      // ADD TRANSACTION BUTTON

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTransaction,
        backgroundColor: const Color(0xFF16745D),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }

  // ------------------------------------------
  // CATEGORY-WISE EXPENSE BREAKDOWN
  // ------------------------------------------

  Widget _categoryBreakdown() {
    final colors = Theme.of(context).colorScheme;
    final total = _categoryExpenses.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );

    if (_categoryExpenses.isEmpty || total == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 32,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            const Text(
              'No expense data yet',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              'Add an expense to see your category-wise breakdown.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final entries = _categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total expenses',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                money(total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...entries.map((entry) {
            final fraction = entry.value / total;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        money(entry.value),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${(fraction * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor:
                          colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ------------------------------------------
  // SIX-MONTH SPENDING TREND
  // ------------------------------------------

  Widget _monthlySpendingChart() {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final maxSpending = _monthlySpending.fold<int>(
      0,
      (maximum, amount) => amount > maximum ? amount : maximum,
    );
    final currentMonthSpending =
        _monthlySpending.isEmpty ? 0 : _monthlySpending.last;
    final previousMonthSpending =
        _monthlySpending.length < 2 ? 0 : _monthlySpending[
          _monthlySpending.length - 2
        ];

    final monthLabels = List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index, 1);
      const names = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return names[month.month - 1];
    });

    String comparisonText;
    if (previousMonthSpending == 0) {
      comparisonText = 'No previous-month spending to compare';
    } else {
      final difference = currentMonthSpending - previousMonthSpending;
      final percentage =
          (difference.abs() / previousMonthSpending * 100).round();
      if (difference > 0) {
        comparisonText = '$percentage% more than last month';
      } else if (difference < 0) {
        comparisonText = '$percentage% less than last month';
      } else {
        comparisonText = 'Same spending as last month';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This month so far',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            money(currentMonthSpending),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            comparisonText,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_monthlySpending.length, (index) {
                final amount = _monthlySpending[index];
                final barHeight = maxSpending == 0
                    ? 4.0
                    : (amount / maxSpending * 92).clamp(4.0, 92.0).toDouble();
                final isCurrentMonth =
                    index == _monthlySpending.length - 1;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          amount == 0 ? '—' : money(amount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: barHeight,
                          width: 22,
                          decoration: BoxDecoration(
                            color: isCurrentMonth
                                ? colors.primary
                                : colors.primary.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          monthLabels[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrentMonth
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrentMonth
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------
  // REUSABLE SUMMARY CARD
  // ------------------------------------------

  Widget _summaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),

          const SizedBox(height: 13),

          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
