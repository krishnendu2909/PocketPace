import 'package:material_ui/material_ui.dart';

import '../../data/local_database.dart';
import '../../models/budget_profile.dart';

class InsightsScreen extends StatefulWidget {
  final BudgetProfile profile;

  const InsightsScreen({
    super.key,
    required this.profile,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  DateTime _selectedMonth = DateTime.now();

  int _monthlyIncome = 0;
  int _monthlyExpenses = 0;
  int _previousMonthlyIncome = 0;
  int _previousMonthlyExpenses = 0;

  Map<String, int> _categoryExpenses = {};
  Map<String, int> _previousCategoryExpenses = {};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final database = LocalDatabase.instance;

      final income = await database.getMonthlyIncomeMinor(
        _selectedMonth,
      );

      final expenses = await database.getMonthlySpentMinor(
        _selectedMonth,
      );

      final categories = await database.getMonthlyExpensesByCategory(
        _selectedMonth,
      );

      final previousMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );

      final previousIncome = await database.getMonthlyIncomeMinor(
        previousMonth,
      );

      final previousExpenses = await database.getMonthlySpentMinor(
        previousMonth,
      );

      final previousCategories =
          await database.getMonthlyExpensesByCategory(previousMonth);

      if (!mounted) return;

      setState(() {
        _monthlyIncome = income;
        _monthlyExpenses = expenses;
        _previousMonthlyIncome = previousIncome;
        _previousMonthlyExpenses = previousExpenses;
        _categoryExpenses = categories;
        _previousCategoryExpenses = previousCategories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int difference) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + difference,
      );
    });

    _loadInsights();
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  String _formatAmount(int amountMinor) {
    return '₹${(amountMinor / 100).toStringAsFixed(2)}';
  }

  int get _netSavings => _monthlyIncome - _monthlyExpenses;

  double get _savingsProgress {
    final target = widget.profile.savingsTargetMinor;

    if (target <= 0 || _netSavings <= 0) {
      return 0;
    }

    return (_netSavings / target).clamp(0.0, 1.0).toDouble();
  }

  int get _totalCategoryExpenses {
    return _categoryExpenses.values.fold(
      0,
      (total, amount) => total + amount,
    );
  }

  Widget _summaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                amount,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _comparisonRow({
    required String title,
    required int current,
    required int previous,
    required bool increaseIsGood,
  }) {
    final difference = current - previous;
    final hasPreviousData = previous > 0;
    final percentage = hasPreviousData
        ? (difference.abs() / previous) * 100
        : 0.0;

    final isIncrease = difference > 0;
    final color = !hasPreviousData || difference == 0
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : ((isIncrease == increaseIsGood) ? Colors.green : Colors.red);

    String changeText;
    if (!hasPreviousData && current > 0) {
      changeText = 'No previous-month data';
    } else if (!hasPreviousData) {
      changeText = 'No activity in either month';
    } else if (difference == 0) {
      changeText = 'No change from last month';
    } else {
      final direction = isIncrease ? 'higher' : 'lower';
      changeText =
          '${percentage.toStringAsFixed(1)}% $direction (${_formatAmount(difference.abs())})';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 4),
                Text(
                  changeText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(current),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyComparison() {
    final previousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compared with ${_monthName(previousMonth.month)} ${previousMonth.year}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _comparisonRow(
              title: 'Income',
              current: _monthlyIncome,
              previous: _previousMonthlyIncome,
              increaseIsGood: true,
            ),
            const Divider(),
            _comparisonRow(
              title: 'Expenses',
              current: _monthlyExpenses,
              previous: _previousMonthlyExpenses,
              increaseIsGood: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = _categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No expense transactions recorded this month.'),
        ),
      );
    }

    return Column(
      children: categories.map((entry) {
        final percentage = _totalCategoryExpenses == 0
            ? 0.0
            : entry.value / _totalCategoryExpenses;

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _formatAmount(entry.value),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 4),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}% of expenses',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryComparison() {
    final categoryNames = <String>{
      ..._categoryExpenses.keys,
      ..._previousCategoryExpenses.keys,
    }.toList()
      ..sort((a, b) {
        final aTotal = _categoryExpenses[a] ?? 0;
        final bTotal = _categoryExpenses[b] ?? 0;
        return bTotal.compareTo(aTotal);
      });

    if (categoryNames.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('No category spending to compare yet.'),
        ),
      );
    }

    return Column(
      children: categoryNames.map((category) {
        final current = _categoryExpenses[category] ?? 0;
        final previous = _previousCategoryExpenses[category] ?? 0;
        final difference = current - previous;
        final hasPreviousData = previous > 0;

        final Color changeColor;
        final String changeText;

        if (!hasPreviousData && current > 0) {
          changeColor = Theme.of(context).colorScheme.onSurfaceVariant;
          changeText = 'New spending this month';
        } else if (difference == 0) {
          changeColor = Theme.of(context).colorScheme.onSurfaceVariant;
          changeText = 'No change';
        } else {
          final percentage = (difference.abs() / previous) * 100;
          final increased = difference > 0;
          changeColor = increased ? Colors.red : Colors.green;
          changeText =
              '${percentage.toStringAsFixed(1)}% ${increased ? 'higher' : 'lower'}';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _formatAmount(current),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      changeText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: changeColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  Text(
                    'Last month: ${_formatAmount(previous)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.profile.savingsTargetMinor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            onPressed: _loadInsights,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh insights',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 12),
                        const Text('Unable to load insights.'),
                        const SizedBox(height: 8),
                        Text(_error!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadInsights,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInsights,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Month selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => _changeMonth(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          IconButton(
                            onPressed: () => _changeMonth(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Income and expenses
                      Row(
                        children: [
                          _summaryCard(
                            title: 'Income',
                            amount: _formatAmount(_monthlyIncome),
                            icon: Icons.trending_up,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 10),
                          _summaryCard(
                            title: 'Expenses',
                            amount: _formatAmount(_monthlyExpenses),
                            icon: Icons.trending_down,
                            color: Colors.red,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Month-over-month comparison
                      _buildMonthlyComparison(),

                      const SizedBox(height: 12),

                      // Net savings
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Net savings this month',
                                style: TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _formatAmount(_netSavings),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _netSavings >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _netSavings >= 0
                                    ? 'Your recorded income is higher than your expenses.'
                                    : 'Your recorded expenses are higher than your income.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Savings target
                      Text(
                        'Savings goal progress',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 10),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Monthly savings target'),
                                  Text(
                                    _formatAmount(target),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              LinearProgressIndicator(
                                value: _savingsProgress,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                target <= 0
                                    ? 'Set a savings target in your budget profile.'
                                    : '${(_savingsProgress * 100).toStringAsFixed(1)}% of your target reached',
                              ),
                              if (_netSavings > target && target > 0)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'You have reached your savings target!',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Category breakdown
                      Text(
                        'Spending by category',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total expenses: ${_formatAmount(_monthlyExpenses)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildCategoryBreakdown(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Category-wise monthly comparison',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Compare each category with the previous month.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildCategoryComparison(),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}