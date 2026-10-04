import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../domain/coffee_pos_models.dart';
import '../../../state/coffee_pos_controller.dart';
import 'reports_export_service.dart';

/// Available presets for reporting date ranges.
enum ReportPreset {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  thisYear('This Year'),
  custom('Custom Range');

  final String label;
  const ReportPreset(this.label);
}

/// Metric displayed on the interactive trend chart.
enum TrendMetric {
  sales('Sales (₱)'),
  orders('Orders'),
  items('Items Sold');

  final String label;
  const TrendMetric(this.label);
}

/// Grouping options for the detailed sales table.
enum TableGroupBy {
  none('None (Itemized)'),
  day('Day'),
  week('Week'),
  month('Month'),
  year('Year'),
  category('Category'),
  product('Product');

  final String label;
  const TableGroupBy(this.label);
}

class PosReportsDashboard extends StatefulWidget {
  const PosReportsDashboard({
    super.key,
    required this.controller,
    required this.compactLandscape,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  State<PosReportsDashboard> createState() => _PosReportsDashboardState();
}

class _PosReportsDashboardState extends State<PosReportsDashboard> {
  final ReportsExportService _exportService = const ReportsExportService();

  ReportPreset _selectedPreset = ReportPreset.thisMonth;
  late DateTime _startDate;
  late DateTime _endDate;

  TrendMetric _selectedMetric = TrendMetric.sales;
  TableGroupBy _groupBy = TableGroupBy.none;

  // Table filters & controls
  String _searchQuery = '';
  String? _filterCategory;
  PaymentType? _filterPayment;
  String? _filterOrderType;
  OrderStatus? _filterStatus;

  int _sortColumnIndex = 0;
  bool _sortAscending = false; // newest first by default

  int _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _applyPreset(ReportPreset.thisMonth, notify: false);
  }

  void _applyPreset(ReportPreset preset, {bool notify = true}) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (preset) {
      case ReportPreset.today:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case ReportPreset.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0, 0);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999);
        break;
      case ReportPreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case ReportPreset.thisMonth:
        start = DateTime(now.year, now.month, 1, 0, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case ReportPreset.thisYear:
        start = DateTime(now.year, 1, 1, 0, 0, 0, 0);
        end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
      case ReportPreset.custom:
        // Keep current custom start and end dates
        start = _startDate;
        end = _endDate;
        break;
    }

    if (notify) {
      setState(() {
        _selectedPreset = preset;
        _startDate = start;
        _endDate = end;
        _currentPage = 0;
      });
    } else {
      _selectedPreset = preset;
      _startDate = start;
      _endDate = end;
    }
  }

  Future<void> _pickCustomDateRange() async {
    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) => _CustomDateRangeDialog(
        initialRange: DateTimeRange(start: _startDate, end: _endDate),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedPreset = ReportPreset.custom;
        _startDate = DateTime(result.start.year, result.start.month, result.start.day, 0, 0, 0, 0);
        _endDate = DateTime(result.end.year, result.end.month, result.end.day, 23, 59, 59, 999);
        _currentPage = 0;
      });
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatCurrency(num value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final dec = parts[1];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₱$formattedWhole.$dec';
  }

  String _periodBannerText() {
    if (_startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day) {
      return _formatDate(_startDate);
    }
    return '${_formatDate(_startDate)} – ${_formatDate(_endDate)}';
  }

  String _resolveCategory(OrderLineSnapshot item) {
    if (item.categoryName != null && item.categoryName!.isNotEmpty) {
      return item.categoryName!;
    }
    if (item.categoryId != null) {
      final cat = widget.controller.categoryById(item.categoryId!);
      if (cat != null) return cat.name;
    }
    final product = widget.controller.productById(item.productId);
    if (product != null) {
      final cat = widget.controller.categoryById(product.categoryId);
      if (cat != null) return cat.name;
    }
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final allOrders = widget.controller.recentOrders;

        // Filter orders in date range
        final ordersInRange = allOrders.where((order) {
          return !order.createdAt.isBefore(_startDate) && !order.createdAt.isAfter(_endDate);
        }).toList(growable: false);

        // Paid sales orders
        final paidOrders = ordersInRange.where((o) => o.status == OrderStatus.paid).toList(growable: false);

        // Refunded orders for separate auditing
        final refundedOrders = ordersInRange.where((o) => o.status == OrderStatus.refunded).toList(growable: false);
        final refundAmount = refundedOrders.fold<double>(0.0, (sum, o) => sum + o.total);

        // KPI calculations
        final totalSales = paidOrders.fold<double>(0.0, (sum, o) => sum + o.total);
        final totalOrdersCount = paidOrders.length;
        final aov = totalOrdersCount == 0 ? 0.0 : totalSales / totalOrdersCount;
        final totalItemsSold = paidOrders.fold<int>(
          0,
          (sum, o) => sum + o.items.fold<int>(0, (iSum, item) => iSum + item.quantity),
        );

        // Category breakdown
        final categorySalesMap = <String, double>{};
        final categoryQtyMap = <String, int>{};
        for (final order in paidOrders) {
          for (final item in order.items) {
            final catName = _resolveCategory(item);
            categorySalesMap[catName] = (categorySalesMap[catName] ?? 0.0) + item.lineTotal;
            categoryQtyMap[catName] = (categoryQtyMap[catName] ?? 0) + item.quantity;
          }
        }
        final sortedCategories = categorySalesMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Top products breakdown
        final productSalesMap = <String, double>{};
        final productQtyMap = <String, int>{};
        for (final order in paidOrders) {
          for (final item in order.items) {
            final pName = item.productName;
            productSalesMap[pName] = (productSalesMap[pName] ?? 0.0) + item.lineTotal;
            productQtyMap[pName] = (productQtyMap[pName] ?? 0) + item.quantity;
          }
        }
        final sortedProducts = productQtyMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(context, ordersInRange.length),
            const SizedBox(height: 12),
            _buildDateRangeSelector(context),
            const SizedBox(height: 12),
            _buildPeriodBanner(
              context,
              paidOrders,
              totalSales,
              totalOrdersCount,
              totalItemsSold,
              aov,
              categorySalesMap,
              sortedProducts,
            ),
            const SizedBox(height: 16),
            _buildKpiCards(totalSales, totalOrdersCount, aov, totalItemsSold, refundedOrders.length, refundAmount),
            const SizedBox(height: 16),
            _buildSalesTrendCard(context, paidOrders),
            const SizedBox(height: 16),
            _buildCategoryAndProductRow(context, sortedCategories, sortedProducts, totalSales),
            const SizedBox(height: 16),
            _buildPaymentMethodBreakdownCard(context, paidOrders),
            const SizedBox(height: 16),
            _buildDetailedSalesTableCard(context, ordersInRange),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  // --- HEADER & DATE FILTER ---

  Widget _buildHeader(BuildContext context, int totalCount) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports & Analytics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2C2523),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analyze store performance, product sales, and transaction records.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF756A63),
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF2ECE4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$totalCount records',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D524B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in ReportPreset.values) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (preset == ReportPreset.custom) ...[
                      const Icon(Icons.date_range_outlined, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(preset.label),
                  ],
                ),
                selected: _selectedPreset == preset,
                selectedColor: const Color(0xFFE87852),
                labelStyle: TextStyle(
                  color: _selectedPreset == preset ? Colors.white : const Color(0xFF4A3E39),
                  fontWeight: _selectedPreset == preset ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                backgroundColor: const Color(0xFFF7F2EB),
                side: BorderSide(
                  color: _selectedPreset == preset ? const Color(0xFFE87852) : const Color(0xFFE5DDD3),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (selected) {
                  if (preset == ReportPreset.custom) {
                    _pickCustomDateRange();
                  } else {
                    _applyPreset(preset);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodBanner(
    BuildContext context,
    List<OrderRecord> paidOrders,
    double totalSales,
    int totalOrders,
    int totalItems,
    double aov,
    Map<String, double> categorySales,
    List<MapEntry<String, int>> topProducts,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFE4D6)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBECE6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today, size: 18, color: Color(0xFFE87852)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reporting Period',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.brown.shade400,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    _periodBannerText(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF322621),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              if (_selectedPreset == ReportPreset.custom)
                InkWell(
                  onTap: _pickCustomDateRange,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.edit_calendar, size: 18, color: Color(0xFFE87852)),
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _handleExportCsv(paidOrders, totalSales, totalOrders, totalItems, aov),
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A3E39),
                  side: const BorderSide(color: Color(0xFFDCCFC3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _handleExportPdf(
                  paidOrders,
                  totalSales,
                  totalOrders,
                  totalItems,
                  aov,
                  categorySales,
                  topProducts,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A3E39),
                  side: const BorderSide(color: Color(0xFFDCCFC3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _handlePrintReport(
                  paidOrders,
                  totalSales,
                  totalOrders,
                  totalItems,
                  aov,
                  categorySales,
                  topProducts,
                ),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print Report'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE87852),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SUMMARY KPI CARDS ---

  Widget _buildKpiCards(
    double totalSales,
    int totalOrders,
    double aov,
    int totalItems,
    int refundCount,
    double refundAmount,
  ) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final isMedium = constraints.maxWidth < 950;
            final cardWidth = isNarrow
                ? constraints.maxWidth
                : isMedium
                    ? (constraints.maxWidth - 12) / 2
                    : (constraints.maxWidth - 36) / 4;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(
                  width: cardWidth,
                  title: 'Total Sales',
                  value: _formatCurrency(totalSales),
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFF2E7D32),
                  iconBgColor: const Color(0xFFE8F5E9),
                  subtitle: 'Completed sales in period',
                ),
                _KpiCard(
                  width: cardWidth,
                  title: 'Total Orders',
                  value: '$totalOrders',
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFFE87852),
                  iconBgColor: const Color(0xFFFBECE6),
                  subtitle: 'Paid transactions',
                ),
                _KpiCard(
                  width: cardWidth,
                  title: 'Average Order Value',
                  value: _formatCurrency(aov),
                  icon: Icons.trending_up,
                  iconColor: const Color(0xFF1976D2),
                  iconBgColor: const Color(0xFFE3F2FD),
                  subtitle: 'Per order spending',
                ),
                _KpiCard(
                  width: cardWidth,
                  title: 'Items Sold',
                  value: '$totalItems',
                  icon: Icons.coffee_outlined,
                  iconColor: const Color(0xFF7B1FA2),
                  iconBgColor: const Color(0xFFF3E5F5),
                  subtitle: 'Cups & food items',
                ),
              ],
            );
          },
        ),
        if (refundCount > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_return_outlined, size: 16, color: Color(0xFFE65100)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tracked separately: $refundCount refunded order${refundCount > 1 ? 's' : ''} (${_formatCurrency(refundAmount)}) excluded from gross sales.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8D4004)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- SALES TREND CHART ---

  Widget _buildSalesTrendCard(BuildContext context, List<OrderRecord> paidOrders) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEAE2D8)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales & Activity Trend',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF332722),
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getTrendGroupingDescription(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF857770)),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<TrendMetric>(
                  segments: const [
                    ButtonSegment(value: TrendMetric.sales, label: Text('Sales (₱)')),
                    ButtonSegment(value: TrendMetric.orders, label: Text('Orders')),
                    ButtonSegment(value: TrendMetric.items, label: Text('Items')),
                  ],
                  selected: {_selectedMetric},
                  onSelectionChanged: (set) => setState(() => _selectedMetric = set.first),
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                    selectedBackgroundColor: const Color(0xFFFBECE6),
                    selectedForegroundColor: const Color(0xFFE87852),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              width: double.infinity,
              child: _SalesTrendChart(
                orders: paidOrders,
                startDate: _startDate,
                endDate: _endDate,
                metric: _selectedMetric,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTrendGroupingDescription() {
    final days = _endDate.difference(_startDate).inDays;
    if (days <= 1) return 'Hourly breakdown (24-hour cycle)';
    if (days <= 14) return 'Daily breakdown';
    if (days <= 90) return 'Weekly breakdown';
    if (days <= 365) return 'Monthly breakdown';
    return 'Multi-year / monthly breakdown';
  }

  // --- CATEGORIES & TOP PRODUCTS ---

  Widget _buildCategoryAndProductRow(
    BuildContext context,
    List<MapEntry<String, double>> categories,
    List<MapEntry<String, int>> products,
    double totalSales,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleColumn = constraints.maxWidth < 750;
        final leftWidget = _buildCategorySalesCard(context, categories, totalSales);
        final rightWidget = _buildTopProductsCard(context, products);

        if (isSingleColumn) {
          return Column(
            children: [
              leftWidget,
              const SizedBox(height: 16),
              rightWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: leftWidget),
            const SizedBox(width: 16),
            Expanded(child: rightWidget),
          ],
        );
      },
    );
  }

  Widget _buildCategorySalesCard(
    BuildContext context,
    List<MapEntry<String, double>> categories,
    double totalSales,
  ) {
    final topList = categories.take(5).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEAE2D8)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sales by Category',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF332722),
                        ),
                  ),
                ),
                if (categories.length > 5)
                  TextButton(
                    onPressed: () => _showAllCategoriesModal(context, categories, totalSales),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE87852),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No category sales recorded in this period.', style: TextStyle(color: Color(0xFF887971))),
                ),
              )
            else
              ...topList.map((entry) {
                final share = totalSales == 0 ? 0.0 : (entry.value / totalSales);
                final percentageStr = '${(share * 100).toStringAsFixed(1)}%';
                final color = _getCategoryColor(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF332722)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            percentageStr,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF756A63)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatCurrency(entry.value),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF221A16)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: share.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF4ECE4),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsCard(
    BuildContext context,
    List<MapEntry<String, int>> products,
  ) {
    final topList = products.take(5).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEAE2D8)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Top Selling Products',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF332722),
                        ),
                  ),
                ),
                if (products.length > 5)
                  TextButton(
                    onPressed: () => _showAllProductsModal(context, products),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE87852),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No product sales recorded in this period.', style: TextStyle(color: Color(0xFF887971))),
                ),
              )
            else
              ...topList.asMap().entries.map((item) {
                final rank = item.key + 1;
                final entry = item.value;
                final badgeColor = switch (rank) {
                  1 => const Color(0xFFD4AF37), // Gold
                  2 => const Color(0xFFA8A8A8), // Silver
                  3 => const Color(0xFFCD7F32), // Bronze
                  _ => const Color(0xFFE5DDD3),
                };

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: rank <= 3 ? Colors.white : const Color(0xFF554A43),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF332722)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBECE6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${entry.value} sold',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE87852),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodBreakdownCard(BuildContext context, List<OrderRecord> paidOrders) {
    final cashOrders = paidOrders.where((o) => o.paymentType == PaymentType.cash).toList();
    final cardOrders = paidOrders.where((o) => o.paymentType == PaymentType.card).toList();
    final eWalletOrders = paidOrders.where((o) => o.paymentType == PaymentType.eWallet).toList();

    final cashSales = cashOrders.fold<double>(0.0, (s, o) => s + o.total);
    final cardSales = cardOrders.fold<double>(0.0, (s, o) => s + o.total);
    final eWalletSales = eWalletOrders.fold<double>(0.0, (s, o) => s + o.total);
    final totalSales = cashSales + cardSales + eWalletSales;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEAE2D8)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Method Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF332722),
                  ),
            ),
            const SizedBox(height: 14),
            _paymentMethodRow('Cash', Icons.money, cashSales, cashOrders.length, totalSales, const Color(0xFF2E7D32)),
            const SizedBox(height: 10),
            _paymentMethodRow('Card', Icons.credit_card, cardSales, cardOrders.length, totalSales, const Color(0xFF1976D2)),
            const SizedBox(height: 10),
            _paymentMethodRow('E-Wallet', Icons.account_balance_wallet_outlined, eWalletSales, eWalletOrders.length, totalSales, const Color(0xFFE87852)),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodRow(
    String label,
    IconData icon,
    double amount,
    int count,
    double totalAll,
    Color color,
  ) {
    final share = totalAll == 0 ? 0.0 : (amount / totalAll);
    final pctStr = '${(share * 100).toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF332722))),
            const SizedBox(width: 8),
            Text('($count orders)', style: const TextStyle(fontSize: 12, color: Color(0xFF887971))),
            const Spacer(),
            Text(pctStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF756A63))),
            const SizedBox(width: 8),
            Text(_formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF221A16))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: const Color(0xFFF4ECE4),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    const palette = [
      Color(0xFFE87852),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFF6366F1),
    ];
    return palette[category.hashCode.abs() % palette.length];
  }

  // --- DETAILED SALES REPORT TABLE ---

  Widget _buildDetailedSalesTableCard(BuildContext context, List<OrderRecord> ordersInRange) {
    // 1. Gather all categories
    final categories = <String>{};
    for (final order in ordersInRange) {
      for (final item in order.items) {
        categories.add(_resolveCategory(item));
      }
    }
    final sortedCategoryFilterList = categories.toList()..sort();

    // 2. Filter records
    final filteredOrders = ordersInRange.where((order) {
      if (_filterPayment != null && order.paymentType != _filterPayment) return false;
      if (_filterOrderType != null && order.orderType != _filterOrderType) return false;
      if (_filterStatus != null && order.status != _filterStatus) return false;
      return true;
    }).toList(growable: false);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEAE2D8)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detailed Sales Report',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF332722),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTableControls(sortedCategoryFilterList),
            const SizedBox(height: 16),
            if (_groupBy == TableGroupBy.none)
              _buildItemizedTable(filteredOrders)
            else
              _buildGroupedTable(filteredOrders),
          ],
        ),
      ),
    );
  }

  Widget _buildTableControls(List<String> categories) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            onChanged: (val) => setState(() {
              _searchQuery = val.trim().toLowerCase();
              _currentPage = 0;
            }),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search order #, product, category...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E928A)),
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFFAF7F2),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5DDD3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5DDD3)),
              ),
            ),
          ),
        ),
        // Category Filter
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5DDD3)),
            ),
            child: DropdownButton<String?>(
              value: _filterCategory,
              hint: const Text('All Categories', style: TextStyle(fontSize: 12)),
              style: const TextStyle(fontSize: 12, color: Color(0xFF332722)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Categories'),
                ),
                ...categories.map(
                  (cat) => DropdownMenuItem<String?>(
                    value: cat,
                    child: Text(cat),
                  ),
                ),
              ],
              onChanged: (val) => setState(() {
                _filterCategory = val;
                _currentPage = 0;
              }),
            ),
          ),
        ),
        // Payment Type Filter
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5DDD3)),
            ),
            child: DropdownButton<PaymentType?>(
              value: _filterPayment,
              hint: const Text('All Payments', style: TextStyle(fontSize: 12)),
              style: const TextStyle(fontSize: 12, color: Color(0xFF332722)),
              items: const [
                DropdownMenuItem<PaymentType?>(value: null, child: Text('All Payments')),
                DropdownMenuItem(value: PaymentType.cash, child: Text('Cash')),
                DropdownMenuItem(value: PaymentType.card, child: Text('Card')),
                DropdownMenuItem(value: PaymentType.eWallet, child: Text('E-Wallet')),
              ],
              onChanged: (val) => setState(() {
                _filterPayment = val;
                _currentPage = 0;
              }),
            ),
          ),
        ),
        // Status Filter
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5DDD3)),
            ),
            child: DropdownButton<OrderStatus?>(
              value: _filterStatus,
              hint: const Text('All Statuses', style: TextStyle(fontSize: 12)),
              style: const TextStyle(fontSize: 12, color: Color(0xFF332722)),
              items: const [
                DropdownMenuItem<OrderStatus?>(value: null, child: Text('All Statuses')),
                DropdownMenuItem(value: OrderStatus.paid, child: Text('Paid')),
                DropdownMenuItem(value: OrderStatus.refunded, child: Text('Refunded')),
                DropdownMenuItem(value: OrderStatus.voided, child: Text('Cancelled')),
              ],
              onChanged: (val) => setState(() {
                _filterStatus = val;
                _currentPage = 0;
              }),
            ),
          ),
        ),
        // Group By Selector
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Group by:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF756A63))),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBECE6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF2D1C4)),
                ),
                child: DropdownButton<TableGroupBy>(
                  value: _groupBy,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE87852)),
                  iconEnabledColor: const Color(0xFFE87852),
                  items: TableGroupBy.values.map(
                    (group) => DropdownMenuItem(
                      value: group,
                      child: Text(group.label),
                    ),
                  ).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _groupBy = val;
                        _currentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- ITEMIZED ROWS TABLE ---

  Widget _buildItemizedTable(List<OrderRecord> orders) {
    // Flatten order items
    final rows = <_ItemizedTableRow>[];
    for (final order in orders) {
      if (order.items.isEmpty) {
        final matchesQuery = _matchesItemQuery(order, null, 'No items', 'Other');
        final matchesCategory = _filterCategory == null || _filterCategory == 'Other';
        if (matchesQuery && matchesCategory) {
          rows.add(
            _ItemizedTableRow(
              date: order.createdAt,
              order: order,
              category: 'Other',
              productName: 'No items',
              quantity: 0,
              unitPrice: 0.0,
              lineTotal: order.total,
            ),
          );
        }
      } else {
        for (final item in order.items) {
          final cat = _resolveCategory(item);
          final matchesQuery = _matchesItemQuery(order, item, item.productName, cat);
          final matchesCategory = _filterCategory == null || _filterCategory == cat;
          if (matchesQuery && matchesCategory) {
            rows.add(
              _ItemizedTableRow(
                date: order.createdAt,
                order: order,
                category: cat,
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                lineTotal: item.lineTotal,
              ),
            );
          }
        }
      }
    }

    // Sort rows
    rows.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: // Date
          cmp = a.date.compareTo(b.date);
          break;
        case 1: // Time
          cmp = a.date.compareTo(b.date);
          break;
        case 2: // Order #
          cmp = a.order.orderNumber.compareTo(b.order.orderNumber);
          break;
        case 3: // Category
          cmp = a.category.compareTo(b.category);
          break;
        case 4: // Product
          cmp = a.productName.compareTo(b.productName);
          break;
        case 5: // Quantity
          cmp = a.quantity.compareTo(b.quantity);
          break;
        case 6: // Unit Price
          cmp = a.unitPrice.compareTo(b.unitPrice);
          break;
        case 7: // Total
        default:
          cmp = a.lineTotal.compareTo(b.lineTotal);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 36, color: Color(0xFFB5A8A0)),
              SizedBox(height: 8),
              Text('No matching sales records found.', style: TextStyle(color: Color(0xFF756A63))),
            ],
          ),
        ),
      );
    }

    // Pagination slice
    final totalRows = rows.length;
    final totalPages = (totalRows / _rowsPerPage).ceil();
    final safePage = _currentPage.clamp(0, math.max<int>(0, totalPages - 1));
    final startIdx = safePage * _rowsPerPage;
    final endIdx = math.min<int>(startIdx + _rowsPerPage, totalRows);
    final pageRows = rows.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF7F2EB)),
            dataRowMinHeight: 48,
            dataRowMaxHeight: 52,
            columnSpacing: 20,
            horizontalMargin: 12,
            columns: [
              DataColumn(
                label: const Text('Date', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                label: const Text('Time', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                label: const Text('Order #', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                label: const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                label: const Text('Product', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Qty', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Unit Price', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
            ],
            rows: pageRows.map((r) {
              return DataRow(
                cells: [
                  DataCell(Text(_formatDate(r.date), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_formatTime(r.date), style: const TextStyle(fontSize: 12))),
                  DataCell(
                    InkWell(
                      onTap: () => _showReceiptDetails(context, r.order),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              r.order.orderNumber,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE87852),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.open_in_new, size: 12, color: Color(0xFFE87852)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(r.category).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getCategoryColor(r.category),
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(r.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text('${r.quantity}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_formatCurrency(r.unitPrice), style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Text(
                      _formatCurrency(r.lineTotal),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF221A16)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildPaginationControls(totalRows, startIdx, endIdx, safePage, totalPages),
      ],
    );
  }

  bool _matchesItemQuery(OrderRecord order, OrderLineSnapshot? item, String productName, String category) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    if (order.orderNumber.toLowerCase().contains(q)) return true;
    if (order.id.toLowerCase().contains(q)) return true;
    if (order.cashierName.toLowerCase().contains(q)) return true;
    if (productName.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    return false;
  }

  // --- GROUPED SUMMARY TABLE ---

  Widget _buildGroupedTable(List<OrderRecord> orders) {
    // Accumulate metrics per group
    final map = <String, _GroupSummaryData>{};

    for (final order in orders) {
      if (order.status != OrderStatus.paid) continue; // Only completed sales

      if (_groupBy == TableGroupBy.category || _groupBy == TableGroupBy.product) {
        for (final item in order.items) {
          final cat = _resolveCategory(item);
          if (_filterCategory != null && _filterCategory != cat) continue;

          final groupKey = _groupBy == TableGroupBy.category ? cat : item.productName;
          if (_searchQuery.isNotEmpty && !groupKey.toLowerCase().contains(_searchQuery)) continue;

          final data = map.putIfAbsent(groupKey, () => _GroupSummaryData(groupKey));
          data.orders.add(order.id);
          data.itemCount += item.quantity;
          data.totalSales += item.lineTotal;
        }
      } else {
        // Date based grouping: Day, Week, Month, Year
        final groupKey = switch (_groupBy) {
          TableGroupBy.day => '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}',
          TableGroupBy.week => 'W${_getWeekOfYear(order.createdAt)} ${order.createdAt.year}',
          TableGroupBy.month => '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}',
          TableGroupBy.year => '${order.createdAt.year}',
          _ => '',
        };

        if (_searchQuery.isNotEmpty && !groupKey.toLowerCase().contains(_searchQuery)) continue;

        final data = map.putIfAbsent(groupKey, () => _GroupSummaryData(groupKey));
        data.orders.add(order.id);
        data.totalSales += order.total;
        for (final item in order.items) {
          data.itemCount += item.quantity;
        }
      }
    }

    final groupList = map.values.toList();

    // Sort grouped rows
    groupList.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.groupKey.compareTo(b.groupKey);
          break;
        case 1:
          cmp = a.orders.length.compareTo(b.orders.length);
          break;
        case 2:
          cmp = a.itemCount.compareTo(b.itemCount);
          break;
        case 3:
        default:
          cmp = a.totalSales.compareTo(b.totalSales);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    if (groupList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text('No grouped sales data for this filter.', style: TextStyle(color: Color(0xFF756A63))),
        ),
      );
    }

    final totalRows = groupList.length;
    final totalPages = (totalRows / _rowsPerPage).ceil();
    final safePage = _currentPage.clamp(0, math.max<int>(0, totalPages - 1));
    final startIdx = safePage * _rowsPerPage;
    final endIdx = math.min<int>(startIdx + _rowsPerPage, totalRows);
    final pageRows = groupList.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF7F2EB)),
            columnSpacing: 28,
            columns: [
              DataColumn(
                label: Text('${_groupBy.label} Group', style: const TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Orders', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Items Sold', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Total Sales', style: TextStyle(fontWeight: FontWeight.w700)),
                onSort: (idx, asc) => setState(() {
                  _sortColumnIndex = idx;
                  _sortAscending = asc;
                }),
              ),
              const DataColumn(
                numeric: true,
                label: Text('Avg / Order', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
            rows: pageRows.map((g) {
              final avg = g.orders.isEmpty ? 0.0 : g.totalSales / g.orders.length;
              return DataRow(
                cells: [
                  DataCell(Text(g.groupKey, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                  DataCell(Text('${g.orders.length}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${g.itemCount}', style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Text(
                      _formatCurrency(g.totalSales),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF221A16)),
                    ),
                  ),
                  DataCell(Text(_formatCurrency(avg), style: const TextStyle(fontSize: 12))),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildPaginationControls(totalRows, startIdx, endIdx, safePage, totalPages),
      ],
    );
  }

  int _getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final firstMonday = startOfYear.weekday == 1 ? startOfYear : startOfYear.add(Duration(days: 8 - startOfYear.weekday));
    if (date.isBefore(firstMonday)) return 1;
    return ((date.difference(firstMonday).inDays) / 7).floor() + 2;
  }

  // --- PAGINATION CONTROLS ---

  Widget _buildPaginationControls(int totalRows, int startIdx, int endIdx, int safePage, int totalPages) {
    return Row(
      children: [
        Text(
          'Showing ${totalRows == 0 ? 0 : startIdx + 1}–$endIdx of $totalRows records',
          style: const TextStyle(fontSize: 12, color: Color(0xFF756A63)),
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rows per page:', style: TextStyle(fontSize: 12, color: Color(0xFF756A63))),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: _rowsPerPage,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 100, child: Text('100', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _rowsPerPage = val;
                    _currentPage = 0;
                  });
                }
              },
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: safePage > 0
                  ? () => setState(() => _currentPage = safePage - 1)
                  : null,
            ),
            Text('${safePage + 1} of ${math.max<int>(1, totalPages)}', style: const TextStyle(fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: safePage < totalPages - 1
                  ? () => setState(() => _currentPage = safePage + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // --- MODALS & DIALOGS ---

  void _showAllCategoriesModal(
    BuildContext context,
    List<MapEntry<String, double>> categories,
    double totalSales,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Sales by Category'),
        content: SizedBox(
          width: 450,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const Divider(height: 12),
            itemBuilder: (ctx, i) {
              final entry = categories[i];
              final share = totalSales == 0 ? 0.0 : (entry.value / totalSales);
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${(share * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF756A63)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatCurrency(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showAllProductsModal(
    BuildContext context,
    List<MapEntry<String, int>> products,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Products Ranked'),
        content: SizedBox(
          width: 450,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 12),
            itemBuilder: (ctx, i) {
              final entry = products[i];
              return Row(
                children: [
                  Text(
                    '#${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE87852), fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${entry.value} sold',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF332722)),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showReceiptDetails(BuildContext context, OrderRecord order) {
    showDialog(
      context: context,
      builder: (ctx) => _ReceiptDetailsDialog(
        order: order,
        controller: widget.controller,
      ),
    );
  }

  // --- EXPORT HANDLERS ---

  Future<void> _handleExportCsv(
    List<OrderRecord> orders,
    double totalSales,
    int totalOrders,
    int totalItems,
    double aov,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final savedPath = await _exportService.exportToCsv(
        periodLabel: _periodBannerText(),
        startDate: _startDate,
        endDate: _endDate,
        orders: orders,
        totalSales: totalSales,
        totalOrders: totalOrders,
        itemsSold: totalItems,
        avgOrderValue: aov,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Report exported to CSV: $savedPath'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to export CSV: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleExportPdf(
    List<OrderRecord> orders,
    double totalSales,
    int totalOrders,
    int totalItems,
    double aov,
    Map<String, double> categorySales,
    List<MapEntry<String, int>> topProducts,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final savedPath = await _exportService.exportToPdf(
        periodLabel: _periodBannerText(),
        startDate: _startDate,
        endDate: _endDate,
        orders: orders,
        totalSales: totalSales,
        totalOrders: totalOrders,
        itemsSold: totalItems,
        avgOrderValue: aov,
        categorySales: categorySales,
        topProducts: topProducts,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Report exported to PDF: $savedPath'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to export PDF: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handlePrintReport(
    List<OrderRecord> orders,
    double totalSales,
    int totalOrders,
    int totalItems,
    double aov,
    Map<String, double> categorySales,
    List<MapEntry<String, int>> topProducts,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _exportService.printReport(
        periodLabel: _periodBannerText(),
        startDate: _startDate,
        endDate: _endDate,
        orders: orders,
        totalSales: totalSales,
        totalOrders: totalOrders,
        itemsSold: totalItems,
        avgOrderValue: aov,
        categorySales: categorySales,
        topProducts: topProducts,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to print report: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

// --- KPI CARD WIDGET ---

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.subtitle,
  });

  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEAE2D8)),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF756A63)),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2C221D),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E928A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- INTERACTIVE SALES TREND CHART ---

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({
    required this.orders,
    required this.startDate,
    required this.endDate,
    required this.metric,
  });

  final List<OrderRecord> orders;
  final DateTime startDate;
  final DateTime endDate;
  final TrendMetric metric;

  @override
  Widget build(BuildContext context) {
    final points = _generateDataPoints();

    if (points.isEmpty || points.every((p) => p.value == 0)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'No sales activity in this period',
              style: TextStyle(color: Color(0xFF887971), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _TrendChartPainter(points: points, metric: metric),
    );
  }

  List<_ChartPoint> _generateDataPoints() {
    final days = endDate.difference(startDate).inDays;

    if (days <= 1) {
      // Hourly (0..23)
      final hours = List<_ChartPoint>.generate(24, (h) {
        final label = '${h.toString().padLeft(2, '0')}:00';
        return _ChartPoint(label: label, fullLabel: '$label on ${startDate.month}/${startDate.day}', value: 0.0);
      });
      for (final order in orders) {
        final h = order.createdAt.hour;
        if (h >= 0 && h < 24) {
          final addVal = _getMetricValue(order);
          hours[h] = hours[h].copyWith(value: hours[h].value + addVal);
        }
      }
      return hours;
    } else if (days <= 14) {
      // Daily
      final list = <_ChartPoint>[];
      for (var d = 0; d <= days; d++) {
        final dt = startDate.add(Duration(days: d));
        if (dt.isAfter(endDate)) break;
        final label = '${dt.month}/${dt.day}';
        list.add(_ChartPoint(label: label, fullLabel: '${dt.year}-${dt.month}-${dt.day}', value: 0.0));
      }
      for (final order in orders) {
        final oDay = order.createdAt.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays;
        if (oDay >= 0 && oDay < list.length) {
          final addVal = _getMetricValue(order);
          list[oDay] = list[oDay].copyWith(value: list[oDay].value + addVal);
        }
      }
      return list;
    } else if (days <= 90) {
      // Weekly intervals
      final list = <_ChartPoint>[];
      var current = startDate;
      var wk = 1;
      while (!current.isAfter(endDate)) {
        final endOfWk = current.add(const Duration(days: 6));
        final label = '${current.month}/${current.day}';
        list.add(_ChartPoint(label: 'W$wk ($label)', fullLabel: 'Week $wk', value: 0.0));
        current = endOfWk.add(const Duration(days: 1));
        wk++;
      }
      for (final order in orders) {
        final diffDays = order.createdAt.difference(startDate).inDays;
        final idx = (diffDays / 7).floor();
        if (idx >= 0 && idx < list.length) {
          final addVal = _getMetricValue(order);
          list[idx] = list[idx].copyWith(value: list[idx].value + addVal);
        }
      }
      return list;
    } else {
      // Monthly intervals
      final list = <_ChartPoint>[];
      var y = startDate.year;
      var m = startDate.month;
      const mNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      while (y < endDate.year || (y == endDate.year && m <= endDate.month)) {
        final label = days > 365 ? '${mNames[m - 1]} $y' : mNames[m - 1];
        list.add(_ChartPoint(label: label, fullLabel: '${mNames[m - 1]} $y', value: 0.0));
        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
      }

      for (final order in orders) {
        final orderY = order.createdAt.year;
        final orderM = order.createdAt.month;
        final monthIdx = (orderY - startDate.year) * 12 + (orderM - startDate.month);
        if (monthIdx >= 0 && monthIdx < list.length) {
          final addVal = _getMetricValue(order);
          list[monthIdx] = list[monthIdx].copyWith(value: list[monthIdx].value + addVal);
        }
      }
      return list;
    }
  }

  double _getMetricValue(OrderRecord order) {
    return switch (metric) {
      TrendMetric.sales => order.total,
      TrendMetric.orders => 1.0,
      TrendMetric.items => order.items.fold<int>(0, (s, i) => s + i.quantity).toDouble(),
    };
  }
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.fullLabel, required this.value});

  final String label;
  final String fullLabel;
  final double value;

  _ChartPoint copyWith({double? value}) => _ChartPoint(
        label: label,
        fullLabel: fullLabel,
        value: value ?? this.value,
      );
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({required this.points, required this.metric});

  final List<_ChartPoint> points;
  final TrendMetric metric;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 50.0;
    const rightPad = 20.0;
    const topPad = 15.0;
    const bottomPad = 30.0;

    final drawWidth = size.width - leftPad - rightPad;
    final drawHeight = size.height - topPad - bottomPad;

    if (drawWidth <= 0 || drawHeight <= 0 || points.isEmpty) return;

    final maxVal = math.max(1.0, points.map((p) => p.value).reduce(math.max));

    // Y Grid lines (4 divisions)
    final gridPaint = Paint()
      ..color = const Color(0xFFF0EAE1)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i <= 3; i++) {
      final y = topPad + drawHeight - (i / 3) * drawHeight;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);

      final val = (i / 3) * maxVal;
      final label = metric == TrendMetric.sales
          ? val >= 1000
              ? '₱${(val / 1000).toStringAsFixed(1)}k'
              : '₱${val.toStringAsFixed(0)}'
          : val.toStringAsFixed(0);

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF9E928A), fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPad - textPainter.width - 8, y - textPainter.height / 2));
    }

    // Coordinates for each point
    final coords = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? leftPad + drawWidth / 2
          : leftPad + (i / (points.length - 1)) * drawWidth;
      final y = topPad + drawHeight - (points[i].value / maxVal) * drawHeight;
      coords.add(Offset(x, y));
    }

    // Fill gradient path
    final fillPath = Path();
    fillPath.moveTo(coords.first.dx, topPad + drawHeight);
    for (final pt in coords) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(coords.last.dx, topPad + drawHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x40E87852), Color(0x00E87852)],
      ).createShader(Rect.fromLTWH(leftPad, topPad, drawWidth, drawHeight));

    canvas.drawPath(fillPath, fillPaint);

    // Line path
    final linePath = Path();
    linePath.moveTo(coords.first.dx, coords.first.dy);
    for (var i = 1; i < coords.length; i++) {
      linePath.lineTo(coords[i].dx, coords[i].dy);
    }

    final linePaint = Paint()
      ..color = const Color(0xFFE87852)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Draw nodes
    final nodePaint = Paint()..color = const Color(0xFFE87852);
    final innerNodePaint = Paint()..color = Colors.white;

    // Determine x-axis label step to prevent text overlapping
    final maxLabels = math.max<int>(2, (drawWidth / 65).floor());
    final step = (points.length / maxLabels).ceil();

    for (var i = 0; i < coords.length; i++) {
      // Draw circular node
      canvas.drawCircle(coords[i], 4, nodePaint);
      canvas.drawCircle(coords[i], 2, innerNodePaint);

      // Draw bottom X-axis label
      if (i % step == 0 || i == coords.length - 1) {
        textPainter.text = TextSpan(
          text: points[i].label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF756A63), fontWeight: FontWeight.w600),
        );
        textPainter.layout();
        final xPos = coords[i].dx - textPainter.width / 2;
        textPainter.paint(canvas, Offset(xPos.clamp(leftPad, size.width - rightPad - textPainter.width), topPad + drawHeight + 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.metric != metric;
  }
}

// --- DATA STRUCTURES ---

class _ItemizedTableRow {
  _ItemizedTableRow({
    required this.date,
    required this.order,
    required this.category,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final DateTime date;
  final OrderRecord order;
  final String category;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

class _GroupSummaryData {
  _GroupSummaryData(this.groupKey);

  final String groupKey;
  final Set<String> orders = {};
  int itemCount = 0;
  double totalSales = 0.0;
}

// --- CUSTOM DATE RANGE DIALOG ---

class _CustomDateRangeDialog extends StatefulWidget {
  const _CustomDateRangeDialog({required this.initialRange});

  final DateTimeRange initialRange;

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange.start;
    _end = widget.initialRange.end;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select Start Date',
    );
    if (picked != null) {
      setState(() {
        _start = picked;
        if (_end.isBefore(_start)) {
          _end = _start;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime(2035),
      helpText: 'Select End Date',
    );
    if (picked != null) {
      setState(() {
        _end = picked;
      });
    }
  }

  void _setYear(int year) {
    setState(() {
      _start = DateTime(year, 1, 1);
      _end = DateTime(year, 12, 31);
    });
  }

  String _format(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.date_range, color: Color(0xFFE87852)),
          SizedBox(width: 10),
          Text('Select Date Range', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Jump to Year:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF756A63)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var y = currentYear; y >= currentYear - 3; y--)
                  ActionChip(
                    label: Text('$y'),
                    backgroundColor: _start.year == y && _end.year == y ? const Color(0xFFFBECE6) : null,
                    side: BorderSide(
                      color: _start.year == y && _end.year == y ? const Color(0xFFE87852) : const Color(0xFFDCCFC3),
                    ),
                    onPressed: () => _setYear(y),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('From Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF756A63))),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickStartDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDCCFC3)),
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFFAF7F2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Color(0xFFE87852)),
                              const SizedBox(width: 8),
                              Text(_format(_start), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('To Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF756A63))),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickEndDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFDCCFC3)),
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFFAF7F2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Color(0xFFE87852)),
                              const SizedBox(width: 8),
                              Text(_format(_end), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            setState(() {
              _start = DateTime(now.year, now.month, 1);
              _end = now;
            });
          },
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, DateTimeRange(start: _start, end: _end)),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE87852)),
          child: const Text('Apply Range'),
        ),
      ],
    );
  }
}

// --- RECEIPT DETAILS DIALOG ---

class _ReceiptDetailsDialog extends StatefulWidget {
  const _ReceiptDetailsDialog({
    required this.order,
    required this.controller,
  });

  final OrderRecord order;
  final CoffeePosController controller;

  @override
  State<_ReceiptDetailsDialog> createState() => _ReceiptDetailsDialogState();
}

class _ReceiptDetailsDialogState extends State<_ReceiptDetailsDialog> {
  bool _isPrintingCustomer = false;
  bool _isPrintingKitchen = false;

  String _format(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  String _money(num value) => '₱${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusColor = switch (order.status) {
      OrderStatus.paid => const Color(0xFF2E7D32),
      OrderStatus.refunded => const Color(0xFFD32F2F),
      OrderStatus.voided => const Color(0xFF757575),
      _ => const Color(0xFFE87852),
    };

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2C221D)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _format(order.createdAt),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF887971)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    order.status.name.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text('Cashier: ${order.cashierName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${order.orderType.toUpperCase()} • ${order.paymentType.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF756A63))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                if (item.modifierLabels.isNotEmpty)
                                  Text(
                                    item.modifierLabels.join(' • '),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF887971)),
                                  ),
                              ],
                            ),
                          ),
                          Text(_money(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  const Divider(height: 16),
                  _calcRow('Subtotal', _money(order.subtotal)),
                  if (order.discount > 0) _calcRow('Discount', '-${_money(order.discount)}', isDiscount: true),
                  if (order.tax > 0) _calcRow('Tax / VAT', _money(order.tax)),
                  if (order.serviceCharge > 0) _calcRow('Service Charge', _money(order.serviceCharge)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const Spacer(),
                      Text(_money(order.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFE87852))),
                    ],
                  ),
                  if (order.paymentType == PaymentType.cash && order.cashReceived > 0) ...[
                    const SizedBox(height: 6),
                    _calcRow('Cash Received', _money(order.cashReceived)),
                    _calcRow('Change Given', _money(order.change)),
                  ],
                  if (order.statusHistory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Audit History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF756A63))),
                    const SizedBox(height: 4),
                    for (final h in order.statusHistory)
                      Text(
                        '• ${h.action.name.toUpperCase()} by ${h.cashierName} (${_format(h.at)})${h.reason.isNotEmpty ? " - ${h.reason}" : ""}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF887971)),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isPrintingCustomer
                      ? null
                      : () async {
                          setState(() => _isPrintingCustomer = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final res = await widget.controller.printReceipt(order, manualReprint: true);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res.isSuccess ? 'Customer receipt sent to printer' : 'Print submitted to system dialog'),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Print error: $e')));
                          } finally {
                            if (mounted) setState(() => _isPrintingCustomer = false);
                          }
                        },
                  icon: const Icon(Icons.receipt, size: 16),
                  label: const Text('Reprint Customer Copy'),
                ),
                OutlinedButton.icon(
                  onPressed: _isPrintingKitchen
                      ? null
                      : () async {
                          setState(() => _isPrintingKitchen = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final res = await widget.controller.printOrderPackage(order, manualReprint: true);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res.isSuccess ? 'Kitchen package sent to printer' : 'Print submitted to system dialog'),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Print error: $e')));
                          } finally {
                            if (mounted) setState(() => _isPrintingKitchen = false);
                          }
                        },
                  icon: const Icon(Icons.kitchen, size: 16),
                  label: const Text('Reprint Kitchen Copy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A3E39)),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF756A63))),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDiscount ? const Color(0xFF2E7D32) : const Color(0xFF332722),
            ),
          ),
        ],
      ),
    );
  }
}

