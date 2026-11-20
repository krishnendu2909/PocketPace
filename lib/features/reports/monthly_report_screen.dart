
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/local_database.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  DateTime _selectedMonth = DateTime.now();

  int _income = 0;
  int _expenses = 0;
  int _previousExpenses = 0;
  Map<String, int> _categoryExpenses = {};

  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final database = LocalDatabase.instance;
      final previousMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );

      final results = await Future.wait<dynamic>([
        database.getMonthlyIncomeMinor(_selectedMonth),
        database.getMonthlySpentMinor(_selectedMonth),
        database.getMonthlyExpensesByCategory(_selectedMonth),
        database.getMonthlySpentMinor(previousMonth),
      ]);

      if (!mounted) return;

      setState(() {
        _income = results[0] as int;
        _expenses = results[1] as int;
        _categoryExpenses = results[2] as Map<String, int>;
        _previousExpenses = results[3] as int;
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
    _loadReport();
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

  // Use INR in the PDF to ensure currency displays
  // correctly with standard PDF fonts.
  String _pdfAmount(int amountMinor) {
    return 'INR ${(amountMinor / 100).toStringAsFixed(2)}';
  }

  int get _netSavings => _income - _expenses;

  double? get _savingsRate {
    if (_income <= 0) return null;
    return (_netSavings / _income) * 100;
  }

  int get _categoryTotal {
    return _categoryExpenses.values.fold(
      0,
      (total, amount) => total + amount,
    );
  }

  List<MapEntry<String, int>> get _topCategories {
    final categories = _categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return categories.take(5).toList();
  }

  String get _expenseChangeText {
    if (_previousExpenses == 0 && _expenses == 0) {
      return 'No expenses recorded in either month';
    }

    if (_previousExpenses == 0) {
      return 'No expenses recorded last month';
    }

    final difference = _expenses - _previousExpenses;

    if (difference == 0) return 'Same as last month';

    final percentage = (difference.abs() / _previousExpenses) * 100;
    final direction = difference > 0 ? 'higher' : 'lower';

    return '${percentage.toStringAsFixed(1)}% $direction than last month';
  }

  Color get _expenseChangeColor {
    if (_expenses == _previousExpenses) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return _expenses > _previousExpenses
        ? Colors.red
        : Colors.green;
  }

  pw.Document _buildPdfDocument() {
    final document = pw.Document();

    final categories = _topCategories;

    final savingsRateText = _savingsRate == null
        ? 'Not available (no income recorded)'
        : '${_savingsRate!.toStringAsFixed(1)}%';

    final previousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PocketPace',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Monthly Financial Report',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            pw.Text(
              'Financial Summary',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),

            _pdfSummaryRow('Total Income', _pdfAmount(_income)),
            _pdfSummaryRow('Total Expenses', _pdfAmount(_expenses)),
            _pdfSummaryRow(
              'Net Savings',
              _pdfAmount(_netSavings),
              bold: true,
            ),
            _pdfSummaryRow('Savings Rate', savingsRateText),

            pw.SizedBox(height: 22),

            pw.Text(
              'Monthly Expense Comparison',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),

            _pdfSummaryRow(
              'Previous month (${_monthName(previousMonth.month)} ${previousMonth.year})',
              _pdfAmount(_previousExpenses),
            ),
            _pdfSummaryRow(
              'Current month expenses',
              _pdfAmount(_expenses),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Text(
                _expenseChangeText,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _expenses > _previousExpenses
                      ? PdfColors.red
                      : _expenses < _previousExpenses
                          ? PdfColors.green
                          : PdfColors.grey700,
                ),
              ),
            ),

            pw.SizedBox(height: 22),

            pw.Text(
              'Top Spending Categories',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),

            if (categories.isEmpty)
              pw.Text(
                'No expense transactions recorded this month.',
                style: const pw.TextStyle(fontSize: 11),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey100,
                    ),
                    children: [
                      _pdfTableCell('Category', bold: true),
                      _pdfTableCell('Amount', bold: true),
                      _pdfTableCell('Share', bold: true),
                    ],
                  ),
                  ...categories.map((entry) {
                    final percentage = _categoryTotal == 0
                        ? 0.0
                        : (entry.value / _categoryTotal) * 100;

                    return pw.TableRow(
                      children: [
                        _pdfTableCell(entry.key),
                        _pdfTableCell(_pdfAmount(entry.value)),
                        _pdfTableCell(
                          '${percentage.toStringAsFixed(1)}%',
                        ),
                      ],
                    );
                  }),
                ],
              ),

            pw.SizedBox(height: 30),

            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),

            pw.Text(
              'Generated by PocketPace',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'This report is based on transactions recorded in PocketPace.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ];
        },
      ),
    );

    return document;
  }

  pw.Widget _pdfSummaryRow(
    String title,
    String value, {
    bool bold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfTableCell(
    String value, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final document = _buildPdfDocument();
      final bytes = await document.save();

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name:
            'PocketPace_${_selectedMonth.year}_${_selectedMonth.month}.pdf',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to export PDF: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final document = _buildPdfDocument();
      final bytes = await document.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'PocketPace_${_selectedMonth.year}_${_selectedMonth.month}.pdf',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share PDF: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
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
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 10),
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

  Widget _buildTopCategories() {
    final topCategories = _topCategories;

    if (topCategories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('No expense transactions recorded this month.'),
        ),
      );
    }

    return Column(
      children: topCategories.map((entry) {
        final percentage = _categoryTotal == 0
            ? 0.0
            : entry.value / _categoryTotal;

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    _formatAmount(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildReport() {
    final savingsRate = _savingsRate;

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
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
                tooltip: 'Next month',
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _sharePdf,
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF'),
                ),
              ),
            ],
          ),

          if (_isGeneratingPdf) ...[
            const SizedBox(height: 12),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              _summaryCard(
                title: 'Income',
                amount: _formatAmount(_income),
                icon: Icons.trending_up,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              _summaryCard(
                title: 'Expenses',
                amount: _formatAmount(_expenses),
                icon: Icons.trending_down,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net savings'),
                  const SizedBox(height: 8),
                  Text(
                    _formatAmount(_netSavings),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _netSavings >= 0 ? Colors.green : Colors.red,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    savingsRate == null
                        ? 'Savings rate unavailable because no income is recorded.'
                        : 'Savings rate: ${savingsRate.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense comparison',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _expenseChangeText,
                    style: TextStyle(
                      color: _expenseChangeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Previous month: ${_formatAmount(_previousExpenses)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Top spending categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTopCategories(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This report is based on transactions recorded in PocketPace.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report'),
        actions: [
          IconButton(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh report',
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
                        const Text('Unable to load monthly report.'),
                        const SizedBox(height: 8),
                        Text(_error!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadReport,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildReport(),
    );
  }
}
