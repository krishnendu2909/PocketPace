
import 'package:material_ui/material_ui.dart';

import '../../data/local_database.dart';
import '../../models/transaction_record.dart';
import '../../services/notification_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'expense';
  String _category = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final List<String> _expenseCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Other',
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Gift',
    'Other',
  ];

  List<String> get _categories =>
      _type == 'expense' ? _expenseCategories : _incomeCategories;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _changeType(String type) {
    setState(() {
      _type = type;
      _category = _categories.first;
    });
  }

  // Converts an amount such as 125.50 into 12550 minor units.
  int? _parseAmount(String value) {
    final input = value.trim();

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(input)) {
      return null;
    }

    final parts = input.split('.');
    final whole = int.tryParse(parts[0]);

    if (whole == null) return null;

    final decimal = parts.length == 2
        ? int.parse(parts[1].padRight(2, '0'))
        : 0;

    return whole * 100 + decimal;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatAmount(int amountMinor) {
    return '₹${(amountMinor / 100).toStringAsFixed(2)}';
  }

  // Checks whether this expense crosses a category budget threshold.
  Future<void> _checkBudgetAndNotify(int amountMinor) async {
    try {
      // Alerts are only for transactions in the current month.
      final now = DateTime.now();

      final isCurrentMonth =
          _selectedDate.year == now.year &&
          _selectedDate.month == now.month;

      if (!isCurrentMonth) return;

      final database = LocalDatabase.instance;

      final budgets = await database.getCategoryBudgets();

      final monthlyLimit = budgets[_category];

      if (monthlyLimit == null || monthlyLimit <= 0) return;

      final expenses =
          await database.getMonthlyExpensesByCategory(_selectedDate);

      final currentSpent = expenses[_category] ?? 0;

      // Calculate spending before the newly added transaction.
      final previousSpent = currentSpent - amountMinor;

      final eightyPercentLimit =
          (monthlyLimit * 0.8).round();

      String? title;
      String? body;
      int notificationLevel = 0;
      int? alertLevel;

      if (previousSpent <= monthlyLimit &&
          currentSpent > monthlyLimit) {
        title = 'Budget exceeded!';
        body =
            'You spent ${_formatAmount(currentSpent)} '
            'against your $_category budget of '
            '${_formatAmount(monthlyLimit)}.';
        notificationLevel = 3;
        alertLevel = 101;
      } else if (previousSpent < monthlyLimit &&
          currentSpent >= monthlyLimit) {
        title = 'Budget limit reached!';
        body =
            'You have used your entire $_category budget '
            'of ${_formatAmount(monthlyLimit)}.';
        notificationLevel = 2;
        alertLevel = 100;
      } else if (previousSpent < eightyPercentLimit &&
          currentSpent >= eightyPercentLimit) {
        title = 'Budget alert: 80% used';
        body =
            'You have spent ${_formatAmount(currentSpent)} '
            'of your $_category budget of '
            '${_formatAmount(monthlyLimit)}.';
        notificationLevel = 1;
        alertLevel = 80;
      }

      if (title != null && body != null && alertLevel != null) {
        final alertMonth = DateTime(
          _selectedDate.year,
          _selectedDate.month,
        );

        final alreadySent = await database.hasBudgetAlertBeenSent(
          category: _category,
          month: alertMonth,
          alertLevel: alertLevel,
        );

        if (alreadySent) return;

        final categoryId = _category.hashCode.abs() % 100000;

        await NotificationService.instance.showNotification(
          id: categoryId * 10 + notificationLevel,
          title: title,
          body: body,
        );

        await database.recordBudgetAlertIfNew(
          category: _category,
          month: alertMonth,
          alertLevel: alertLevel,
        );
      }
    } catch (error) {
      // Notification failures should not undo a saved transaction.
      debugPrint('Budget notification error: $error');
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amountMinor = _parseAmount(_amountController.text);

    if (amountMinor == null || amountMinor <= 0) return;

    setState(() => _isSaving = true);

    try {
      final record = TransactionRecord(
        title: _titleController.text.trim(),
        category: _category,
        amountMinor: amountMinor,
        type: _type,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      await LocalDatabase.instance.addTransaction(record);

      // Check budget thresholds after saving an expense.
      if (_type == 'expense') {
        await _checkBudgetAndNotify(amountMinor);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save transaction: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == 'expense';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Transaction type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _typeButton(
                      label: 'Expense',
                      selected: isExpense,
                      onTap: () => _changeType('expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _typeButton(
                      label: 'Income',
                      selected: !isExpense,
                      onTap: () => _changeType('income'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                'Amount',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = _parseAmount(value ?? '');

                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount (up to 2 decimals)';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 22),

              const Text(
                'Transaction name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Grocery shopping',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a transaction name';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 22),

              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),

              const SizedBox(height: 22),

              const Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')}/'
                  '${_selectedDate.month.toString().padLeft(2, '0')}/'
                  '${_selectedDate.year}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Note (optional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _noteController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Add a note...',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveTransaction,
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Transaction',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: selected
            ? const Color(0xFF16745D)
            : Colors.transparent,
        foregroundColor: selected ? Colors.white : null,
        side: BorderSide(
          color: selected
              ? const Color(0xFF16745D)
              : Colors.grey.shade400,
        ),
      ),
      child: Text(label),
    );
  }
}
