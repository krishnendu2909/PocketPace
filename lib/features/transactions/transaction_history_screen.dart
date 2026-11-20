
import 'package:material_ui/material_ui.dart';

import '../../data/local_database.dart';
import '../../models/transaction_record.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends State<TransactionHistoryScreen> {
  DateTime _selectedMonth = DateTime.now();

  String _selectedFilter = 'All';

  List<TransactionRecord> _transactions = [];

  int _monthlyIncome = 0;
  int _monthlyExpense = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  // ------------------------------------------
  // LOAD TRANSACTIONS
  // ------------------------------------------

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        LocalDatabase.instance.getMonthlyTransactions(
          _selectedMonth,
        ),
        LocalDatabase.instance.getMonthlyIncomeMinor(
          _selectedMonth,
        ),
        LocalDatabase.instance.getMonthlySpentMinor(
          _selectedMonth,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _transactions = results[0] as List<TransactionRecord>;
        _monthlyIncome = results[1] as int;
        _monthlyExpense = results[2] as int;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load transactions: $e')),
      );
    }
  }

  // ------------------------------------------
  // FILTER TRANSACTIONS
  // ------------------------------------------

  List<TransactionRecord> get _filteredTransactions {
    if (_selectedFilter == 'All') {
      return _transactions;
    }

    return _transactions
        .where((transaction) =>
            transaction.type == _selectedFilter.toLowerCase())
        .toList();
  }

  // ------------------------------------------
  // MONTH NAVIGATION
  // ------------------------------------------

  void _changeMonth(int difference) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + difference,
        1,
      );
    });

    _loadTransactions();
  }

  String _monthName(DateTime date) {
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

    return '${months[date.month - 1]} ${date.year}';
  }

  // ------------------------------------------
  // CURRENCY FORMATTER
  // ------------------------------------------

  String _formatAmount(int amountMinor) {
    final amount = (amountMinor / 100).toStringAsFixed(2);
    return '₹$amount';
  }

  // ------------------------------------------
  // EDIT TRANSACTION
  // ------------------------------------------

  Future<void> _editTransaction(
    TransactionRecord transaction,
  ) async {
    final titleController = TextEditingController(
      text: transaction.title,
    );

    final amountController = TextEditingController(
      text: (transaction.amountMinor / 100).toStringAsFixed(2),
    );

    final categoryController = TextEditingController(
      text: transaction.category,
    );

    final noteController = TextEditingController(
      text: transaction.note ?? '',
    );

    String selectedType = transaction.type;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Transaction'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'income',
                          child: Text('Income'),
                        ),
                        DropdownMenuItem(
                          value: 'expense',
                          child: Text('Expense'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
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
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave == true) {
      final title = titleController.text.trim();
      final category = categoryController.text.trim();
      final amountText = amountController.text.trim();

      final amount = double.tryParse(amountText);

      if (title.isEmpty ||
          category.isEmpty ||
          amount == null ||
          !amount.isFinite ||
          amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter valid transaction details.'),
            ),
          );
        }
      } else {
        try {
          final updatedTransaction = TransactionRecord(
            id: transaction.id,
            title: title,
            category: category,
            amountMinor: (amount * 100).round(),
            type: selectedType,
            date: transaction.date,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );

          await LocalDatabase.instance.updateTransaction(
            updatedTransaction,
          );

          await _loadTransactions();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction updated successfully.'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Update failed: $e')),
            );
          }
        }
      }
    }

    titleController.dispose();
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
  }

  // ------------------------------------------
  // DELETE TRANSACTION
  // ------------------------------------------

  Future<void> _deleteTransaction(
    TransactionRecord transaction,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transaction?'),
          content: Text(
            'Are you sure you want to delete "${transaction.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true && transaction.id != null) {
      await LocalDatabase.instance.deleteTransaction(
        transaction.id!,
      );

      await _loadTransactions();
    }
  }

  // ------------------------------------------
  // TRANSACTION CARD
  // ------------------------------------------

  Widget _transactionCard(TransactionRecord transaction) {
    final isIncome = transaction.type == 'income';

    final color = isIncome ? Colors.green : Colors.red;

    final date =
        '${transaction.date.day.toString().padLeft(2, '0')}/'
        '${transaction.date.month.toString().padLeft(2, '0')}/'
        '${transaction.date.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: color,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.category} • $date',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  if (transaction.note != null &&
                      transaction.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.note!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    '${isIncome ? '+' : '-'}${_formatAmount(transaction.amountMinor)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editTransaction(transaction);
                } else if (value == 'delete') {
                  _deleteTransaction(transaction);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------
  // SUMMARY CARD
  // ------------------------------------------

  Widget _summaryCard(
    String title,
    int amount,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _formatAmount(amount),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------
  // MAIN SCREEN
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // MONTH SELECTOR

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  _monthName(_selectedMonth),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // MONTHLY SUMMARY

            Row(
              children: [
                _summaryCard(
                  'Income',
                  _monthlyIncome,
                  Colors.green,
                  Icons.trending_up,
                ),
                const SizedBox(width: 12),
                _summaryCard(
                  'Expenses',
                  _monthlyExpense,
                  Colors.red,
                  Icons.trending_down,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // FILTERS

            const Text(
              'Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              children: ['All', 'Income', 'Expense'].map((filter) {
                return ChoiceChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  onSelected: (_) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // TRANSACTION LIST

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 55,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No transactions found',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Your transactions will appear here.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filteredTransactions.map(_transactionCard),
          ],
        ),
      ),
    );
  }
}
