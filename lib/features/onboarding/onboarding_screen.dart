import 'package:material_ui/material_ui.dart';

import '../../models/budget_profile.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function(BudgetProfile profile) onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final incomeController = TextEditingController();
  final expensesController = TextEditingController();
  final savingsController = TextEditingController();
  final bufferController = TextEditingController();

  String selectedCurrency = 'INR';

  bool isSaving = false;

  final currencies = {
    'INR': 'Indian Rupee (₹)',
    'USD': 'US Dollar (\$)',
    'EUR': 'Euro (€)',
    'GBP': 'British Pound (£)',
    'AED': 'UAE Dirham (د.إ)',
  };

  @override
  void dispose() {
    incomeController.dispose();
    expensesController.dispose();
    savingsController.dispose();
    bufferController.dispose();
    super.dispose();
  }

  int toMinorUnits(String value) {
    final parts = value.trim().split('.');

    final whole = int.parse(parts[0]);
    final decimal = parts.length > 1
        ? parts[1].padRight(2, '0')
        : '00';

    return whole * 100 + int.parse(decimal);
  }

  String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an amount';
    }

    final pattern = RegExp(r'^\d+(\.\d{1,2})?$');

    if (!pattern.hasMatch(value.trim())) {
      return 'Enter a valid amount (maximum 2 decimals)';
    }

    return null;
  }

  Future<void> submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final income = toMinorUnits(incomeController.text);
    final expenses = toMinorUnits(expensesController.text);
    final savings = toMinorUnits(savingsController.text);
    final buffer = toMinorUnits(bufferController.text);

    if (income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monthly income must be greater than zero'),
        ),
      );
      return;
    }

    if (expenses + savings + buffer > income) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Expenses, savings and buffer cannot exceed income.',
          ),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    final profile = BudgetProfile(
      monthlyIncomeMinor: income,
      fixedExpensesMinor: expenses,
      savingsTargetMinor: savings,
      bufferMinor: buffer,
      currency: selectedCurrency,
    );

    try {
      await widget.onComplete(profile);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 42,
                  color: colors.primary,
                ),

                const SizedBox(height: 22),

                Text(
                  'Welcome to PocketPace',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Let’s understand your monthly finances '
                  'to calculate your daily spending allowance.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Choose your base currency',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: selectedCurrency,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: currencies.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCurrency = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 25),

                _buildField(
                  label: 'Monthly income',
                  hint: '45000',
                  controller: incomeController,
                  icon: Icons.account_balance_wallet_outlined,
                  required: true,
                ),

                const SizedBox(height: 18),

                _buildField(
                  label: 'Fixed monthly expenses',
                  hint: '18000',
                  controller: expensesController,
                  icon: Icons.receipt_long_outlined,
                ),

                const SizedBox(height: 18),

                _buildField(
                  label: 'Monthly savings target',
                  hint: '5000',
                  controller: savingsController,
                  icon: Icons.savings_outlined,
                ),

                const SizedBox(height: 18),

                _buildField(
                  label: 'Emergency buffer',
                  hint: '2000',
                  controller: bufferController,
                  icon: Icons.shield_outlined,
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: isSaving ? null : submitForm,
                    child: isSaving
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Create my budget',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Text(
                    'Your financial data stays on this device for now.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
          ),
          validator: required ? validateAmount : (value) {
            if (value == null || value.trim().isEmpty) {
              return null;
            }
            return validateAmount(value);
          },
        ),
      ],
    );
  }
}