
import 'package:material_ui/material_ui.dart';

import '../../data/local_database.dart';

class CategoryBudgetsScreen extends StatefulWidget {
  const CategoryBudgetsScreen({super.key});

  @override
  State<CategoryBudgetsScreen> createState() =>
      _CategoryBudgetsScreenState();
}

class _CategoryBudgetsScreenState
    extends State<CategoryBudgetsScreen> {
  Map<String, int> _budgets = {};
  Map<String, int> _expenses = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final budgets =
          await LocalDatabase.instance.getCategoryBudgets();

      final expenses = await LocalDatabase.instance
          .getMonthlyExpensesByCategory(DateTime.now());

      if (!mounted) return;

      setState(() {
        _budgets = budgets;
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load budgets: $error'),
        ),
      );
    }
  }

  String _formatAmount(int minorAmount) {
    return '₹${(minorAmount / 100).toStringAsFixed(2)}';
  }

  Future<void> _showBudgetDialog({
    String? existingCategory,
    int? existingAmount,
  }) async {
    final categoryController = TextEditingController(
      text: existingCategory ?? '',
    );

    final amountController = TextEditingController(
      text: existingAmount == null
          ? ''
          : (existingAmount / 100).toStringAsFixed(2),
    );

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existingCategory == null
                ? 'Add Category Budget'
                : 'Edit Category Budget',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Food, Shopping, Travel',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Limit',
                    prefixText: '₹ ',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      value?.trim() ?? '',
                    );

                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }

                    return null;
                  },
                ),
              ],
            ),
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
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final category = categoryController.text.trim();
      final amount = double.parse(
        amountController.text.trim(),
      );

      final amountMinor = (amount * 100).round();

      try {
        await LocalDatabase.instance.saveCategoryBudget(
          category: category,
          monthlyLimitMinor: amountMinor,
        );

        await _loadBudgets();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category budget saved successfully!'),
          ),
        );
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save budget: $error'),
          ),
        );
      }
    }

    categoryController.dispose();
    amountController.dispose();
  }

  Future<void> _deleteBudget(String category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Budget?'),
          content: Text(
            'Are you sure you want to delete the $category budget?',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await LocalDatabase.instance.deleteCategoryBudget(category);
      await _loadBudgets();
    }
  }

  Widget _buildBudgetCard(String category, int limit) {
    final spent = _expenses[category] ?? 0;

    final progress = limit > 0
        ? (spent / limit).clamp(0.0, 1.0)
        : 0.0;

    final remaining = limit - spent;
    final isOverBudget = spent > limit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit budget',
                  onPressed: () {
                    _showBudgetDialog(
                      existingCategory: category,
                      existingAmount: limit,
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete budget',
                  onPressed: () => _deleteBudget(category),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Spent: ${_formatAmount(spent)}'),
                Text('Limit: ${_formatAmount(limit)}'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
            const SizedBox(height: 10),
            Text(
              isOverBudget
                  ? 'Over budget by ${_formatAmount(spent - limit)}'
                  : '${_formatAmount(remaining)} remaining',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isOverBudget
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Budgets'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _budgets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No category budgets yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set spending limits for categories '
                          'to keep track of your expenses.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => _showBudgetDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Budget'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBudgets,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Your monthly spending limits',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._budgets.entries.map(
                        (entry) => _buildBudgetCard(
                          entry.key,
                          entry.value,
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _budgets.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showBudgetDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
