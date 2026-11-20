class RecurringTransaction {
  final int? id;
  final String title;
  final String category;
  final int amountMinor;
  final String type; // income or expense
  final String frequency; // daily, weekly, monthly, yearly
  final DateTime startDate;
  final DateTime nextDueDate;
  final DateTime? endDate;
  final bool isActive;
  final String? note;

  const RecurringTransaction({
    this.id,
    required this.title,
    required this.category,
    required this.amountMinor,
    required this.type,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    this.endDate,
    this.isActive = true,
    this.note,
  });
}