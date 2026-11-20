class TransactionRecord {
  final int? id;
  final String title;
  final String category;
  final int amountMinor;
  final String type; // income or expense
  final DateTime date;
  final String? note;

  const TransactionRecord({
    this.id,
    required this.title,
    required this.category,
    required this.amountMinor,
    required this.type,
    required this.date,
    this.note,
  });
}