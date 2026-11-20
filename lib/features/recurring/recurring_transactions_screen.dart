import 'package:material_ui/material_ui.dart';

import '../../data/local_database.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  List<Map<String, Object?>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items =
          await LocalDatabase.instance.getRecurringTransactions();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load schedules: $error')),
      );
    }
  }

  String _formatAmount(int minor) =>
      '₹${(minor / 100).toStringAsFixed(2)}';

  String _formatDate(String value) {
    final date = DateTime.parse(value);
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _frequencyLabel(String value) {
    switch (value) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'yearly':
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }

  Future<void> _showScheduleDialog({
    Map<String, Object?>? existing,
  }) async {
    final titleController = TextEditingController(
      text: existing?['title'] as String? ?? '',
    );
    final categoryController = TextEditingController(
      text: existing?['category'] as String? ?? '',
    );
    final amountController = TextEditingController(
      text: existing == null
          ? ''
          : ((existing['amount_minor'] as int) / 100).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    String type = existing?['type'] as String? ?? 'expense';
    String frequency = existing?['frequency'] as String? ?? 'monthly';
    DateTime startDate = existing == null
        ? DateTime.now()
        : DateTime.parse(existing['start_date'] as String);
    DateTime? endDate = existing?['end_date'] == null
        ? null
        : DateTime.parse(existing!['end_date'] as String);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null
                  ? 'Add Recurring Transaction'
                  : 'Edit Recurring Transaction'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'e.g. House Rent, Salary',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter a title'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            hintText: 'e.g. Housing, Salary, Bills',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter a category'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '₹ ',
                          ),
                          validator: (value) {
                            final amount =
                                double.tryParse(value?.trim() ?? '');
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration:
                              const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(
                              value: 'expense',
                              child: Text('Expense'),
                            ),
                            DropdownMenuItem(
                              value: 'income',
                              child: Text('Income'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => type = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: frequency,
                          decoration:
                              const InputDecoration(labelText: 'Frequency'),
                          items: const [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'yearly',
                              child: Text('Yearly'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => frequency = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start date'),
                          subtitle: Text(_formatDate(startDate.toIso8601String())),
                          trailing: const Icon(Icons.calendar_today_outlined),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: startDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => startDate = picked);
                            }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('End date (optional)'),
                          subtitle: Text(endDate == null
                              ? 'No end date'
                              : _formatDate(endDate!.toIso8601String())),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (endDate != null)
                                IconButton(
                                  tooltip: 'Clear end date',
                                  onPressed: () =>
                                      setDialogState(() => endDate = null),
                                  icon: const Icon(Icons.clear),
                                ),
                              const Icon(Icons.event_outlined),
                            ],
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: endDate ?? startDate,
                              firstDate: startDate,
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => endDate = picked);
                            }
                          },
                        ),
                        if (endDate != null && endDate!.isBefore(startDate))
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'End date must be on or after start date.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate() &&
                        (endDate == null || !endDate!.isBefore(startDate))) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      try {
        final amount = double.parse(amountController.text.trim());
        await LocalDatabase.instance.saveRecurringTransaction(
          id: existing?['id'] as int?,
          title: titleController.text.trim(),
          category: categoryController.text.trim(),
          amountMinor: (amount * 100).round(),
          type: type,
          frequency: frequency,
          startDate: startDate,
          nextDueDate: existing == null
              ? startDate
              : DateTime.parse(existing['next_due_date'] as String),
          endDate: endDate,
          isActive: existing == null
              ? true
              : (existing['is_active'] as int) == 1,
        );
        await _loadItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(existing == null
                  ? 'Recurring schedule added.'
                  : 'Recurring schedule updated.'),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to save schedule: $error')),
          );
        }
      }
    }

    titleController.dispose();
    categoryController.dispose();
    amountController.dispose();
  }

  Future<void> _toggleActive(Map<String, Object?> item) async {
    final id = item['id'] as int;
    final currentlyActive = (item['is_active'] as int) == 1;
    await LocalDatabase.instance
        .setRecurringTransactionActive(id, !currentlyActive);
    await _loadItems();
  }

  Future<void> _deleteItem(Map<String, Object?> item) async {
    final title = item['title'] as String;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete schedule?'),
        content: Text('Delete the recurring schedule "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LocalDatabase.instance
          .deleteRecurringTransaction(item['id'] as int);
      await _loadItems();
    }
  }

  Widget _buildScheduleCard(Map<String, Object?> item) {
    final isActive = (item['is_active'] as int) == 1;
    final isIncome = item['type'] == 'income';
    final amount = item['amount_minor'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(isIncome
                      ? Icons.south_west
                      : Icons.north_east),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(item['category'] as String),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}${_formatAmount(amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text(_frequencyLabel(item['frequency'] as String))),
                Chip(
                  label: Text(isActive ? 'Active' : 'Paused'),
                  avatar: Icon(
                    isActive ? Icons.play_circle_outline : Icons.pause_circle,
                    size: 18,
                  ),
                ),
              ],
            ),
            Text('Next due: ${_formatDate(item['next_due_date'] as String)}'),
            if (item['end_date'] != null)
              Text('Ends: ${_formatDate(item['end_date'] as String)}'),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showScheduleDialog(existing: item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleActive(item),
                  icon: Icon(isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  label: Text(isActive ? 'Pause' : 'Resume'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete schedule',
                  onPressed: () => _deleteItem(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.repeat, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'No recurring transactions yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Schedule regular income and expenses such as '
                          'salary, rent and subscriptions.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => _showScheduleDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Schedule'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Manage your regular income and payments',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      ..._items.map(_buildScheduleCard),
                    ],
                  ),
                ),
      floatingActionButton: _items.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showScheduleDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
