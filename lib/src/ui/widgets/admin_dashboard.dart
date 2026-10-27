import 'dart:math' as math;

import 'package:excel/excel.dart' as xl;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../data/menu_workbook.dart';
import '../../domain/checkout_calculator.dart';
import '../../domain/coffee_pos_models.dart';
import '../../state/coffee_pos_controller.dart';
import '../../utils/category_icon.dart';
import '../../utils/export_writer.dart';
import '../../utils/receipt_printer.dart' as receipt_printer;
import 'auto_hiding_snack_bar.dart';

enum _AdminSection { overview, products, customizations, inventory, orders }

enum _AdminDatePreset { today, yesterday, thisWeek, thisMonth, thisYear, custom }

String _presetLabel(_AdminDatePreset preset, DateTimeRange? customRange) {
  return switch (preset) {
    _AdminDatePreset.today => 'Today',
    _AdminDatePreset.yesterday => 'Yesterday',
    _AdminDatePreset.thisWeek => 'This Week',
    _AdminDatePreset.thisMonth => 'This Month',
    _AdminDatePreset.thisYear => 'This Year',
    _AdminDatePreset.custom => customRange != null
        ? '${_formatShortDate(customRange.start)} – ${_formatShortDate(customRange.end)}'
        : 'Custom Range',
  };
}

String _formatShortDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _formatDateTime(DateTime dt) {
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${_formatShortDate(dt)}, $hour:$minute $ampm';
}

List<OrderRecord> _filterOrdersByDate(
  List<OrderRecord> orders,
  _AdminDatePreset preset,
  DateTimeRange? customRange,
) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  DateTime start;
  DateTime end = endOfToday;

  switch (preset) {
    case _AdminDatePreset.today:
      start = startOfToday;
      break;
    case _AdminDatePreset.yesterday:
      start = startOfToday.subtract(const Duration(days: 1));
      end = DateTime(start.year, start.month, start.day, 23, 59, 59, 999);
      break;
    case _AdminDatePreset.thisWeek:
      final weekday = now.weekday; // 1 = Mon
      start = DateTime(now.year, now.month, now.day - (weekday - 1));
      break;
    case _AdminDatePreset.thisMonth:
      start = DateTime(now.year, now.month, 1);
      break;
    case _AdminDatePreset.thisYear:
      start = DateTime(now.year, 1, 1);
      break;
    case _AdminDatePreset.custom:
      if (customRange != null) {
        start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59, 999);
      } else {
        start = DateTime(2020);
      }
      break;
  }

  return orders.where((order) {
    return !order.createdAt.isBefore(start) && !order.createdAt.isAfter(end);
  }).toList();
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.controller});

  final CoffeePosController controller;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  _AdminSection _section = _AdminSection.overview;

  CoffeePosController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F2),
          body: Row(
            children: [
              _AdminSidebar(
                activeSection: _section,
                onSelectSection: (section) => setState(() => _section = section),
                controller: controller,
                isMobile: !isDesktop,
              ),
              const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEFE6DC)),
              Expanded(
                child: _buildSectionContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionContent() {
    return switch (_section) {
      _AdminSection.overview => _AdminOverviewView(controller: controller),
      _AdminSection.products => _AdminProductsView(controller: controller),
      _AdminSection.customizations => _AdminCustomizationsView(controller: controller),
      _AdminSection.inventory => _AdminInventoryView(controller: controller),
      _AdminSection.orders => _AdminOrdersView(controller: controller),
    };
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.activeSection,
    required this.onSelectSection,
    required this.controller,
    this.isMobile = false,
  });

  final _AdminSection activeSection;
  final ValueChanged<_AdminSection> onSelectSection;
  final CoffeePosController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobile ? 76 : 210,
      color: const Color(0xFFFFFDFB),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 12,
        vertical: isMobile ? 10 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Store Title
          if (isMobile) ...[
            Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8D2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF8F4F).withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.coffee_rounded,
                  color: Color(0xFF6B4423),
                  size: 19,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Center(
              child: controller.isDemo
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF856404),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEMO',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9E8D81),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEFE6DC)),
            const SizedBox(height: 8),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8D2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF8F4F).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.coffee_rounded,
                    color: Color(0xFF6B4423),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LUNAN',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF4A2C11),
                        ),
                      ),
                      if (controller.isDemo)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            border: Border.all(color: const Color(0xFFFFEEBA)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DEMO ADMIN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF856404),
                              letterSpacing: 0.4,
                            ),
                          ),
                        )
                      else
                        const Text(
                          'Back Office',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8C7564),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEFE6DC)),
            const SizedBox(height: 14),
          ],

          // Independently scrollable nav rail items
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Overview',
                    isActive: activeSection == _AdminSection.overview,
                    onTap: () => onSelectSection(_AdminSection.overview),
                    isMobile: isMobile,
                  ),
                  SizedBox(height: isMobile ? 6 : 4),
                  _SidebarItem(
                    icon: Icons.coffee_outlined,
                    activeIcon: Icons.coffee_rounded,
                    label: 'Products',
                    isActive: activeSection == _AdminSection.products,
                    onTap: () => onSelectSection(_AdminSection.products),
                    isMobile: isMobile,
                  ),
                  SizedBox(height: isMobile ? 6 : 4),
                  _SidebarItem(
                    icon: Icons.tune_outlined,
                    activeIcon: Icons.tune_rounded,
                    label: 'Customizations',
                    isActive: activeSection == _AdminSection.customizations,
                    onTap: () => onSelectSection(_AdminSection.customizations),
                    isMobile: isMobile,
                  ),
                  SizedBox(height: isMobile ? 6 : 4),
                  _SidebarItem(
                    icon: Icons.warehouse_outlined,
                    activeIcon: Icons.warehouse_rounded,
                    label: 'Inventory',
                    isActive: activeSection == _AdminSection.inventory,
                    onTap: () => onSelectSection(_AdminSection.inventory),
                    isMobile: isMobile,
                  ),
                  SizedBox(height: isMobile ? 6 : 4),
                  _SidebarItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    label: 'Orders',
                    isActive: activeSection == _AdminSection.orders,
                    onTap: () => onSelectSection(_AdminSection.orders),
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEFE6DC)),
          const SizedBox(height: 8),

          // Store Backup & Info
          if (isMobile) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Tooltip(
                  message: 'Backup Store Data',
                  child: InkWell(
                    onTap: () => _exportToFile(context, controller),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.download_rounded, size: 18, color: Color(0xFF6B4423)),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Restore Store Data',
                  child: InkWell(
                    onTap: () => _importFromFile(context, controller),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.upload_rounded, size: 18, color: Color(0xFF6B4423)),
                    ),
                  ),
                ),
                if (controller.isDemo)
                  Tooltip(
                    message: 'Reset Demo Data',
                    child: InkWell(
                      onTap: () => _showResetDemoDialog(context, controller),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.restore_rounded, size: 18, color: Color(0xFF856404)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportToFile(context, controller),
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Backup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B4423),
                      side: const BorderSide(color: Color(0xFFE0D4C5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _importFromFile(context, controller),
                    icon: const Icon(Icons.upload_rounded, size: 14),
                    label: const Text('Restore'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B4423),
                      side: const BorderSide(color: Color(0xFFE0D4C5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            if (controller.isDemo) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showResetDemoDialog(context, controller),
                  icon: const Icon(Icons.restore_rounded, size: 14),
                  label: const Text('Reset Demo Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF856404),
                    side: const BorderSide(color: Color(0xFFFFEEBA)),
                    backgroundColor: const Color(0xFFFFF3CD),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                controller.isDemo
                    ? '${controller.storeName} • Demo Mode'
                    : '${controller.storeName} • Admin',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: controller.isDemo ? FontWeight.w700 : FontWeight.normal,
                  color: controller.isDemo ? const Color(0xFF856404) : const Color(0xFF9E8D81),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showResetDemoDialog(
  BuildContext context,
  CoffeePosController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset Demo Data?'),
      content: const Text(
        'This will restore all demo products, categories, modifiers, inventory, and sample orders to their original demo state.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Reset Demo Data'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.resetDemoData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo data has been reset to original sample state.')),
      );
    }
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isMobile = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      const coral = Color(0xFFE96755);
      return Semantics(
        selected: isActive,
        button: true,
        child: Tooltip(
          message: label,
          child: Material(
            color: isActive ? coral : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? activeIcon : icon,
                      size: 20,
                      color: isActive ? Colors.white : const Color(0xFF7A6A5E),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.15,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                        color: isActive ? Colors.white : const Color(0xFF3E3027),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: isActive ? const Color(0xFFFFE8D2) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFFF8F4F).withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 19,
                color: isActive ? const Color(0xFF6B4423) : const Color(0xFF7A6A5E),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? const Color(0xFF6B4423) : const Color(0xFF4A3B32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPageHeader extends StatelessWidget {
  const _AdminPageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2F251E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7564)),
              ),
              if (trailing != null) ...[
                const SizedBox(height: 8),
                trailing!,
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2F251E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8C7564)),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        );
      },
    );
  }
}

class _AdminDateRangeSelector extends StatelessWidget {
  const _AdminDateRangeSelector({
    required this.preset,
    required this.customRange,
    required this.onPresetSelected,
    required this.onCustomRangeSelected,
  });

  final _AdminDatePreset preset;
  final DateTimeRange? customRange;
  final ValueChanged<_AdminDatePreset> onPresetSelected;
  final ValueChanged<DateTimeRange> onCustomRangeSelected;

  @override
  Widget build(BuildContext context) {
    final label = _presetLabel(preset, customRange);

    return PopupMenuButton<_AdminDatePreset>(
      tooltip: 'Filter date range',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFFDFB),
      onSelected: (value) async {
        if (value == _AdminDatePreset.custom) {
          final initial = customRange ??
              DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 30)),
                end: DateTime.now(),
              );
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDateRange: initial,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF6B4423),
                    onPrimary: Colors.white,
                    surface: Color(0xFFFFFBF6),
                    onSurface: Color(0xFF2F251E),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            onCustomRangeSelected(picked);
          }
        } else {
          onPresetSelected(value);
        }
      },
      itemBuilder: (context) => [
        _buildPopupItem(_AdminDatePreset.today, 'Today', Icons.today_rounded),
        _buildPopupItem(_AdminDatePreset.yesterday, 'Yesterday', Icons.history_rounded),
        _buildPopupItem(_AdminDatePreset.thisWeek, 'This Week', Icons.date_range_rounded),
        _buildPopupItem(_AdminDatePreset.thisMonth, 'This Month', Icons.calendar_month_rounded),
        _buildPopupItem(_AdminDatePreset.thisYear, 'This Year', Icons.calendar_today_rounded),
        const PopupMenuDivider(),
        _buildPopupItem(_AdminDatePreset.custom, 'Custom Range...', Icons.edit_calendar_rounded),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2D6CA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF6B4423)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A3B32),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF8C7564)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_AdminDatePreset> _buildPopupItem(
    _AdminDatePreset itemPreset,
    String text,
    IconData icon,
  ) {
    final isSelected = preset == itemPreset;
    return PopupMenuItem<_AdminDatePreset>(
      value: itemPreset,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? const Color(0xFF6B4423) : const Color(0xFF8C7564),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF6B4423) : const Color(0xFF2F251E),
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF6B4423)),
        ],
      ),
    );
  }
}

class _AdminOverviewView extends StatefulWidget {
  const _AdminOverviewView({required this.controller});

  final CoffeePosController controller;

  @override
  State<_AdminOverviewView> createState() => _AdminOverviewViewState();
}

class _AdminOverviewViewState extends State<_AdminOverviewView> {
  _AdminDatePreset _preset = _AdminDatePreset.thisMonth;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final allOrders = controller.recentOrders;
    final orders = _filterOrdersByDate(allOrders, _preset, _customRange);

    // Compute KPI metrics
    double totalSales = 0;
    int totalOrders = 0;
    for (final o in orders) {
      if (o.status != OrderStatus.voided) {
        totalSales += _orderSummary(o).total;
        totalOrders++;
      }
    }
    final avgOrder = totalOrders > 0 ? totalSales / totalOrders : 0.0;
    final lowStockCount = controller.inventoryHealth
        .where((item) => item.severity != InventorySeverity.good)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 10 : 16,
            vertical: isNarrow ? 10 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdminPageHeader(
                title: 'Overview',
                subtitle: 'Store performance, analytics, and sales breakdown',
                trailing: _AdminDateRangeSelector(
                  preset: _preset,
                  customRange: _customRange,
                  onPresetSelected: (preset) => setState(() {
                    _preset = preset;
                    _customRange = null;
                  }),
                  onCustomRangeSelected: (range) => setState(() {
                    _preset = _AdminDatePreset.custom;
                    _customRange = range;
                  }),
                ),
              ),
              const SizedBox(height: 14),

              if (controller.isDemo) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF856404), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'You are in Demo Admin Mode. All metrics, products, and orders are sample business records.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF856404),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('reset_demo_data_overview_btn'),
                        onPressed: () => _showResetDemoDialog(context, controller),
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Reset Demo Data', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF856404),
                          side: const BorderSide(color: Color(0xFF856404)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // KPI Cards (2 columns on mobile/tablet, 4 columns on wide screens)
              LayoutBuilder(
                builder: (context, kpiConstraints) {
                  final isWide = kpiConstraints.maxWidth >= 900;
                  final crossAxisCount = isWide ? 4 : 2;
                  final spacing = isNarrow ? 8.0 : 10.0;
                  final width = (kpiConstraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: width,
                        child: _KpiCard(
                          label: 'Total Sales',
                          value: _money(totalSales),
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF3B7D52),
                          fillColor: const Color(0xFFE8F5E9),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _KpiCard(
                          label: 'Total Orders',
                          value: '$totalOrders',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF6B4423),
                          fillColor: const Color(0xFFFFE8D2),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _KpiCard(
                          label: 'Average Order',
                          value: _money(avgOrder),
                          icon: Icons.point_of_sale_rounded,
                          color: const Color(0xFF2E6B9E),
                          fillColor: const Color(0xFFE1F0FA),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _KpiCard(
                          label: 'Low Stock Items',
                          value: '$lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: lowStockCount > 0 ? const Color(0xFFC62828) : const Color(0xFF3B7D52),
                          fillColor: lowStockCount > 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Native Sales Trend Chart
              _SalesTrendChartCard(orders: orders, preset: _preset, customRange: _customRange),
              const SizedBox(height: 14),

              // 2-Column bottom layout: Top Selling Products & Category Sales
              LayoutBuilder(
                builder: (context, btmConstraints) {
                  final isWide = btmConstraints.maxWidth >= 850;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _TopProductsCard(orders: orders, controller: controller),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 5,
                          child: _CategorySalesCard(orders: orders, controller: controller),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopProductsCard(orders: orders, controller: controller),
                      const SizedBox(height: 14),
                      _CategorySalesCard(orders: orders, controller: controller),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.fillColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 185;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 8 : 12,
            vertical: isSmall ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEFE6DC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isSmall ? 28 : 36,
                height: isSmall ? 28 : 36,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isSmall ? 16 : 19),
              ),
              SizedBox(width: isSmall ? 6 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: isSmall ? 10 : 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF8C7564),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: isSmall ? 14 : 16.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2F251E),
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SalesTrendChartCard extends StatelessWidget {
  const _SalesTrendChartCard({
    required this.orders,
    required this.preset,
    required this.customRange,
  });

  final List<OrderRecord> orders;
  final _AdminDatePreset preset;
  final DateTimeRange? customRange;

  @override
  Widget build(BuildContext context) {
    // Generate buckets based on preset
    final List<_ChartBucket> buckets = _buildBuckets();
    final double maxRevenue = buckets.fold(0.0, (max, b) => math.max(max, b.revenue));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFE6DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sales Trend',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F251E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Peak: ${_money(maxRevenue)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8C7564),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty || maxRevenue == 0)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: const Text(
                'No sales recorded for this period',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
              ),
            )
          else
            SizedBox(
              height: 125,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bucket in buckets)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (bucket.revenue > 0)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _money(bucket.revenue),
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8C7564),
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Container(
                              height: maxRevenue > 0
                                  ? math.max(4.0, (bucket.revenue / maxRevenue) * 85)
                                  : 4.0,
                              decoration: BoxDecoration(
                                color: bucket.revenue == maxRevenue && maxRevenue > 0
                                    ? const Color(0xFFFF8F4F)
                                    : const Color(0xFF6B4423).withValues(alpha: 0.8),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                bucket.label,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF7A6A5E),
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<_ChartBucket> _buildBuckets() {
    final validOrders = orders.where((o) => o.status != OrderStatus.voided).toList();

    if (preset == _AdminDatePreset.today || preset == _AdminDatePreset.yesterday) {
      // 8 time slots: 6AM, 8AM, 10AM, 12PM, 2PM, 4PM, 6PM, 8PM+
      final slots = ['6A', '8A', '10A', '12P', '2P', '4P', '6P', '8P'];
      final revenue = List.filled(slots.length, 0.0);
      for (final o in validOrders) {
        final h = o.createdAt.hour;
        final idx = h < 8
            ? 0
            : h < 10
                ? 1
                : h < 12
                    ? 2
                    : h < 14
                        ? 3
                        : h < 16
                            ? 4
                            : h < 18
                                ? 5
                                : h < 20
                                    ? 6
                                    : 7;
        revenue[idx] += _orderSummary(o).total;
      }
      return List.generate(slots.length, (i) => _ChartBucket(slots[i], revenue[i]));
    }

    if (preset == _AdminDatePreset.thisWeek) {
      // 7 days of week: Mon, Tue, Wed, Thu, Fri, Sat, Sun
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final revenue = List.filled(7, 0.0);
      for (final o in validOrders) {
        final weekday = o.createdAt.weekday; // 1 = Mon
        if (weekday >= 1 && weekday <= 7) {
          revenue[weekday - 1] += _orderSummary(o).total;
        }
      }
      return List.generate(7, (i) => _ChartBucket(days[i], revenue[i]));
    }

    if (preset == _AdminDatePreset.thisMonth) {
      // 4 weeks
      const weeks = ['W1 (1-7)', 'W2 (8-14)', 'W3 (15-21)', 'W4 (22+)'];
      final revenue = List.filled(4, 0.0);
      for (final o in validOrders) {
        final d = o.createdAt.day;
        final idx = d <= 7 ? 0 : d <= 14 ? 1 : d <= 21 ? 2 : 3;
        revenue[idx] += _orderSummary(o).total;
      }
      return List.generate(4, (i) => _ChartBucket(weeks[i], revenue[i]));
    }

    if (preset == _AdminDatePreset.thisYear) {
      // 12 months
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final revenue = List.filled(12, 0.0);
      for (final o in validOrders) {
        final m = o.createdAt.month;
        if (m >= 1 && m <= 12) {
          revenue[m - 1] += _orderSummary(o).total;
        }
      }
      return List.generate(12, (i) => _ChartBucket(months[i], revenue[i]));
    }

    // Custom
    const slots = ['Part 1', 'Part 2', 'Part 3', 'Part 4', 'Part 5'];
    final revenue = List.filled(slots.length, 0.0);
    if (validOrders.isNotEmpty && customRange != null) {
      final totalDuration = customRange!.duration.inMilliseconds;
      for (final o in validOrders) {
        final offset = o.createdAt.difference(customRange!.start).inMilliseconds;
        final ratio = totalDuration > 0 ? (offset / totalDuration).clamp(0.0, 0.99) : 0.0;
        final idx = (ratio * slots.length).floor().clamp(0, slots.length - 1);
        revenue[idx] += _orderSummary(o).total;
      }
    }
    return List.generate(slots.length, (i) => _ChartBucket(slots[i], revenue[i]));
  }
}

class _ChartBucket {
  _ChartBucket(this.label, this.revenue);
  final String label;
  final double revenue;
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({
    required this.orders,
    required this.controller,
  });

  final List<OrderRecord> orders;
  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    // Aggregate top sold items
    final Map<String, _ProductStat> stats = {};
    for (final order in orders) {
      if (order.status == OrderStatus.voided) continue;
      for (final item in order.items) {
        final existing = stats[item.productId];
        if (existing == null) {
          stats[item.productId] = _ProductStat(
            productId: item.productId,
            name: item.productName,
            unitsSold: item.quantity,
            revenue: item.lineTotal,
          );
        } else {
          stats[item.productId] = _ProductStat(
            productId: item.productId,
            name: item.productName,
            unitsSold: existing.unitsSold + item.quantity,
            revenue: existing.revenue + item.lineTotal,
          );
        }
      }
    }

    final sorted = stats.values.toList()..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
    final top5 = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFE6DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, size: 18, color: Color(0xFFFF8F4F)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Top Selling Products',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F251E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (top5.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: const Text(
                'No sales data recorded yet',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
              ),
            )
          else ...[
            for (int i = 0; i < top5.length; i++) ...[
              if (i > 0) const Divider(height: 12, thickness: 1, color: Color(0xFFF3ECE4)),
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? const Color(0xFFFFE8D2)
                          : i == 1
                              ? const Color(0xFFEFE6DC)
                              : const Color(0xFFF7F2EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? const Color(0xFF8B4513) : const Color(0xFF6B584C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      top5[i].name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2F251E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _money(top5[i].revenue),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2F251E),
                        ),
                      ),
                      Text(
                        '${top5[i].unitsSold} sold',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7A6A5E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProductStat {
  _ProductStat({
    required this.productId,
    required this.name,
    required this.unitsSold,
    required this.revenue,
  });
  final String productId;
  final String name;
  final int unitsSold;
  final double revenue;
}

class _CategorySalesCard extends StatelessWidget {
  const _CategorySalesCard({
    required this.orders,
    required this.controller,
  });

  final List<OrderRecord> orders;
  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    // Map productId -> categoryId
    final Map<String, String> productCategoryMap = {
      for (final p in controller.products) p.id: p.categoryId,
    };

    final Map<String, _CategoryStat> stats = {};
    double totalRevenueAll = 0;

    for (final order in orders) {
      if (order.status == OrderStatus.voided) continue;
      for (final item in order.items) {
        final catId = productCategoryMap[item.productId] ?? '';
        final cat = _categoryForProduct(controller, catId);
        final catName = cat?.name ?? 'Other';
        final catIcon = cat?.icon;

        totalRevenueAll += item.lineTotal;

        final existing = stats[catName];
        if (existing == null) {
          stats[catName] = _CategoryStat(
            name: catName,
            icon: catIcon,
            unitsSold: item.quantity,
            revenue: item.lineTotal,
          );
        } else {
          stats[catName] = _CategoryStat(
            name: catName,
            icon: catIcon,
            unitsSold: existing.unitsSold + item.quantity,
            revenue: existing.revenue + item.lineTotal,
          );
        }
      }
    }

    final list = stats.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFE6DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 18, color: Color(0xFF6B4423)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sales by Category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F251E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: const Text(
                'No category sales data yet',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
              ),
            )
          else ...[
            for (int i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _buildCategoryRow(list[i], totalRevenueAll),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(_CategoryStat stat, double totalRevenueAll) {
    final share = totalRevenueAll > 0 ? (stat.revenue / totalRevenueAll).clamp(0.0, 1.0) : 0.0;
    final percent = (share * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F251E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${stat.unitsSold} sold  •  ${_money(stat.revenue)} ($percent%)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7A6A5E),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFF3ECE4),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: share,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8F4F),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryStat {
  _CategoryStat({
    required this.name,
    this.icon,
    required this.unitsSold,
    required this.revenue,
  });
  final String name;
  final String? icon;
  final int unitsSold;
  final double revenue;
}

class _AdminProductsView extends StatefulWidget {
  const _AdminProductsView({required this.controller});

  final CoffeePosController controller;

  @override
  State<_AdminProductsView> createState() => _AdminProductsViewState();
}

class _AdminProductsViewState extends State<_AdminProductsView> {
  String _search = '';
  String? _categoryId;
  String _status = 'All';
  int _page = 0;
  static const int _pageSize = 12;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    var list = controller.products;

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((p) => p.name.toLowerCase().contains(q) || p.badge.toLowerCase().contains(q))
          .toList();
    }
    if (_categoryId != null && _categoryId!.isNotEmpty) {
      list = list.where((p) => p.categoryId == _categoryId).toList();
    }
    if (_status == 'Active') {
      list = list.where((p) => p.isAvailable).toList();
    } else if (_status == 'Inactive') {
      list = list.where((p) => !p.isAvailable).toList();
    } else if (_status == 'With Badge') {
      list = list.where((p) => p.badge.isNotEmpty).toList();
    }

    final totalItems = list.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    if (_page >= totalPages) _page = totalPages - 1;

    final startIndex = _page * _pageSize;
    final pageItems = list.skip(startIndex).take(_pageSize).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 10 : 16,
            vertical: isNarrow ? 10 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          _AdminPageHeader(
            title: 'Products',
            subtitle: 'Manage catalog items, pricing, and availability',
            trailing: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ActionButton(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload Menu',
                  onPressed: () => importProductsExcel(context, controller),
                ),
                _ActionButton(
                  icon: Icons.download_rounded,
                  label: 'Download Menu',
                  onPressed: () => _exportProductsExcel(context, controller),
                ),
                FilledButton.icon(
                  onPressed: () => _openProductDialog(context, controller),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Product'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4423),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filters Toolbar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFE6DC)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() {
                      _search = val;
                      _page = 0;
                    }),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF8C7564)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2D6CA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2D6CA)),
                      ),
                    ),
                  ),
                ),

                // Category Dropdown Filter
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D6CA)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _categoryId,
                      hint: const Text('All Categories', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Categories', style: TextStyle(fontSize: 12)),
                        ),
                        for (final cat in controller.categories)
                          DropdownMenuItem<String?>(
                            value: cat.id,
                            child: Text(cat.name, style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                      onChanged: (val) => setState(() {
                        _categoryId = val;
                        _page = 0;
                      }),
                    ),
                  ),
                ),

                // Status Filter
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D6CA)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Active', child: Text('Active Only', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Inactive', child: Text('Inactive Only', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'With Badge', child: Text('With Badge', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _status = val;
                            _page = 0;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Products Table
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFE6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 52,
                    columnSpacing: 18,
                    horizontalMargin: 16,
                    headingTextStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B4423),
                    ),
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Badge')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final product in pageItems)
                        DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE8D2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: () {
                                      final cat = _categoryForProduct(controller, product.categoryId);
                                      return Icon(
                                        cat != null ? categoryIconData(cat) : Icons.coffee_outlined,
                                        size: 16,
                                        color: const Color(0xFF6B4423),
                                      );
                                    }(),
                                  ),
                                  const SizedBox(width: 10),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2F251E),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (product.description.isNotEmpty)
                                          Text(
                                            product.description,
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF8C7564)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              _CategoryLabel(
                                category: _categoryForProduct(controller, product.categoryId),
                                fallback: '—',
                              ),
                            ),
                            DataCell(
                              Text(
                                _money(product.price),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2F251E),
                                ),
                              ),
                            ),
                            DataCell(
                              product.badge.isNotEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEDE1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFFF8F4F).withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        product.badge.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF8B4513),
                                        ),
                                      ),
                                    )
                                  : const Text('—', style: TextStyle(color: Color(0xFF9E8D81))),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: product.isAvailable ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  product.isAvailable ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: product.isAvailable ? const Color(0xFF2E7D32) : const Color(0xFF757575),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    tooltip: 'Edit product',
                                    color: const Color(0xFF6B4423),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _openProductDialog(context, controller, initial: product),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                    tooltip: 'Delete product',
                                    color: const Color(0xFFB5442F),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmDelete(
                                      context,
                                      title: 'Delete Product',
                                      message: 'Are you sure you want to delete "${product.name}"?',
                                      onConfirm: () => controller.deleteProduct(product.id),
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
                if (pageItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    alignment: Alignment.center,
                    child: const Text(
                      'No products found matching filters',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
                    ),
                  ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFEFE6DC)),
                _PaginationBar(
                  currentPage: _page,
                  totalPages: totalPages,
                  totalItems: totalItems,
                  pageSize: _pageSize,
                  onPageChanged: (page) => setState(() => _page = page),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _AdminCustomizationsView extends StatefulWidget {
  const _AdminCustomizationsView({required this.controller});

  final CoffeePosController controller;

  @override
  State<_AdminCustomizationsView> createState() => _AdminCustomizationsViewState();
}

class _AdminCustomizationsViewState extends State<_AdminCustomizationsView> {
  String _search = '';
  String? _categoryId;
  String _ruleFilter = 'All';
  String _statusFilter = 'All';
  int _page = 0;
  static const int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    var list = controller.modifierGroups;

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((g) {
        if (g.name.toLowerCase().contains(q)) return true;
        return g.options.any((o) => o.name.toLowerCase().contains(q));
      }).toList();
    }

    if (_categoryId != null && _categoryId!.isNotEmpty) {
      list = list.where((g) {
        return g.targetCategoryIds.contains(_categoryId) ||
            controller.categories
                .where((c) => c.id == _categoryId)
                .any((c) => c.modifierGroupIds.contains(g.id));
      }).toList();
    }

    if (_ruleFilter == 'Single Choice') {
      list = list.where((g) => g.isSingleSelect).toList();
    } else if (_ruleFilter == 'Multiple Choice') {
      list = list.where((g) => !g.isSingleSelect).toList();
    } else if (_ruleFilter == 'Required') {
      list = list.where((g) => g.isRequired).toList();
    } else if (_ruleFilter == 'Optional') {
      list = list.where((g) => !g.isRequired).toList();
    }

    if (_statusFilter == 'Active') {
      list = list.where((g) => g.enabled).toList();
    } else if (_statusFilter == 'Inactive') {
      list = list.where((g) => !g.enabled).toList();
    }

    final totalItems = list.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    if (_page >= totalPages) _page = totalPages - 1;

    final startIndex = _page * _pageSize;
    final pageItems = list.skip(startIndex).take(_pageSize).toList();

    final allGroups = controller.modifierGroups;
    final totalOptionsCount = allGroups.fold<int>(0, (sum, g) => sum + g.options.length);
    final activeCount = allGroups.where((g) => g.enabled).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 10 : 16,
            vertical: isNarrow ? 10 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdminPageHeader(
                title: 'Customizations',
                subtitle: 'Dynamic modifier groups, add-ons, sizes, and menu options',
                trailing: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _ActionButton(
                      icon: Icons.upload_file_rounded,
                      label: 'Upload Menu',
                      onPressed: () => importProductsExcel(context, controller),
                    ),
                    _ActionButton(
                      icon: Icons.download_rounded,
                      label: 'Download Menu',
                      onPressed: () => _exportProductsExcel(context, controller),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openModifierGroupDialog(context, controller),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Group'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4423),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mini Stats Strip (2 columns on mobile)
              LayoutBuilder(
                builder: (context, statConstraints) {
                  final isSmall = statConstraints.maxWidth < 600;
                  final crossAxisCount = isSmall ? 2 : 3;
                  final spacing = isNarrow ? 8.0 : 10.0;
                  final cardWidth = (statConstraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _CustomizationStatCard(
                          title: 'Total Groups',
                          value: '${allGroups.length}',
                          icon: Icons.tune_rounded,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _CustomizationStatCard(
                          title: 'Active Groups',
                          value: '$activeCount',
                          icon: Icons.check_circle_outline_rounded,
                          accentColor: const Color(0xFF2E7D32),
                        ),
                      ),
                      SizedBox(
                        width: isSmall ? statConstraints.maxWidth : cardWidth,
                        child: _CustomizationStatCard(
                          title: 'Total Options',
                          value: '$totalOptionsCount',
                          icon: Icons.format_list_bulleted_rounded,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

          // Filters Toolbar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFE6DC)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isNarrow ? double.infinity : 220,
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() {
                      _search = val;
                      _page = 0;
                    }),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search groups or options...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF8C7564)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2D6CA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2D6CA)),
                      ),
                    ),
                  ),
                ),

                // Category Dropdown
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D6CA)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _categoryId,
                      hint: const Text('All Categories', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Categories', style: TextStyle(fontSize: 12)),
                        ),
                        ...controller.categories.map(
                          (cat) => DropdownMenuItem<String?>(
                            value: cat.id,
                            child: Text(cat.name, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() {
                        _categoryId = val;
                        _page = 0;
                      }),
                    ),
                  ),
                ),

                // Rule filter
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D6CA)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _ruleFilter,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Rules', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Single Choice', child: Text('Single Choice', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Multiple Choice', child: Text('Multiple Choice', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Required', child: Text('Required Only', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Optional', child: Text('Optional Only', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setState(() {
                        if (val != null) {
                          _ruleFilter = val;
                          _page = 0;
                        }
                      }),
                    ),
                  ),
                ),

                // Status filter
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D6CA)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Status', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Active', child: Text('Active Only', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Inactive', child: Text('Inactive Only', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setState(() {
                        if (val != null) {
                          _statusFilter = val;
                          _page = 0;
                        }
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Customization Groups List Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFE6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pageItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                    child: Column(
                      children: [
                        Icon(Icons.tune_rounded, size: 40, color: const Color(0xFF8C7564).withValues(alpha: 0.5)),
                        const SizedBox(height: 10),
                        const Text(
                          'No customization groups found',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4A2C11)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add groups like Size, Milk, Flavor, Rice Type, or Add-ons.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8C7564)),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _openModifierGroupDialog(context, controller),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Group'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6B4423),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...pageItems.asMap().entries.map((entry) {
                    final itemIndex = startIndex + entry.key;
                    final group = entry.value;
                    final isFirst = itemIndex == 0;
                    final isLast = itemIndex == list.length - 1;
                    return _ModifierGroupCardRow(
                      group: group,
                      controller: controller,
                      isFirst: isFirst,
                      isLast: isLast,
                      onMoveUp: isFirst
                          ? null
                          : () {
                              final globalIndex = controller.modifierGroups.indexWhere((g) => g.id == group.id);
                              if (globalIndex > 0) {
                                controller.reorderModifierGroups(globalIndex, globalIndex - 1);
                              }
                            },
                      onMoveDown: isLast
                          ? null
                          : () {
                              final globalIndex = controller.modifierGroups.indexWhere((g) => g.id == group.id);
                              if (globalIndex >= 0 && globalIndex < controller.modifierGroups.length - 1) {
                                controller.reorderModifierGroups(globalIndex, globalIndex + 1);
                              }
                            },
                      onEdit: () => _openModifierGroupDialog(context, controller, group),
                      onDelete: () => _confirmDeleteGroup(context, controller, group),
                      onToggleEnabled: (val) => controller.toggleModifierGroupEnabled(group.id, val),
                    );
                  }),
                const Divider(height: 1, thickness: 1, color: Color(0xFFEFE6DC)),
                _PaginationBar(
                  currentPage: _page,
                  totalPages: totalPages,
                  totalItems: totalItems,
                  pageSize: _pageSize,
                  onPageChanged: (page) => setState(() => _page = page),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    CoffeePosController controller,
    ModifierGroup group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customization Group'),
        content: Text(
          'Are you sure you want to delete "${group.name}"? It will be unassigned from all products and categories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.deleteModifierGroup(group.id);
      showAutoHidingSnackBar(
        messenger: messenger,
        content: Text('Customization group "${group.name}" deleted'),
      );
    }
  }
}

class _CustomizationStatCard extends StatelessWidget {
  const _CustomizationStatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 185;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 8 : 12,
            vertical: isSmall ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEFE6DC)),
          ),
          child: Row(
            children: [
              Container(
                width: isSmall ? 28 : 34,
                height: isSmall ? 28 : 34,
                decoration: BoxDecoration(
                  color: (accentColor ?? const Color(0xFF6B4423)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: isSmall ? 15 : 18,
                  color: accentColor ?? const Color(0xFF6B4423),
                ),
              ),
              SizedBox(width: isSmall ? 6 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmall ? 10 : 11,
                        color: const Color(0xFF8C7564),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: isSmall ? 14 : 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4A2C11),
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModifierGroupCardRow extends StatelessWidget {
  const _ModifierGroupCardRow({
    required this.group,
    required this.controller,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
  });

  final ModifierGroup group;
  final CoffeePosController controller;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final categoryNames = group.targetCategoryIds
        .map((id) => controller.categories.where((c) => c.id == id).firstOrNull?.name ?? id)
        .toList();

    for (final cat in controller.categories) {
      if (cat.modifierGroupIds.contains(group.id) && !categoryNames.contains(cat.name)) {
        categoryNames.add(cat.name);
      }
    }

    final productNames = group.targetProductIds
        .map((id) => controller.products.where((p) => p.id == id).firstOrNull?.name ?? id)
        .toList();

    for (final prod in controller.products) {
      if (prod.modifierGroupIds.contains(group.id) && !productNames.contains(prod.name)) {
        productNames.add(prod.name);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        Widget buildReorderButtons({bool horizontal = false}) {
          final up = InkWell(
            onTap: onMoveUp,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 18,
                color: isFirst ? const Color(0xFFD0C4B8) : const Color(0xFF6B4423),
              ),
            ),
          );
          final down = InkWell(
            onTap: onMoveDown,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isLast ? const Color(0xFFD0C4B8) : const Color(0xFF6B4423),
              ),
            ),
          );
          if (horizontal) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [up, down],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [up, down],
          );
        }

        Widget buildScopeBadges() {
          return Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (categoryNames.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category_outlined, size: 11, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 3),
                      Text(
                        'Categories: ${categoryNames.join(', ')}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              if (productNames.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.coffee_outlined, size: 11, color: Color(0xFF5E35B1)),
                      const SizedBox(width: 3),
                      Text(
                        '${productNames.length} Product${productNames.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF5E35B1), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              if (categoryNames.isEmpty && productNames.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Unassigned / Menu-wide',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          );
        }

        Widget buildRuleBadge() {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: group.isRequired
                  ? const Color(0xFFFFF0E5)
                  : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: group.isRequired
                    ? const Color(0xFFFF8F4F).withValues(alpha: 0.4)
                    : const Color(0xFFB0C4DE).withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              group.selectionRuleLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: group.isRequired
                    ? const Color(0xFFB25010)
                    : const Color(0xFF335577),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        Widget buildActiveToggle({bool compact = false}) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                group.enabled ? 'Active' : 'Disabled',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: group.enabled ? const Color(0xFF2E7D32) : const Color(0xFF9E8D81),
                ),
              ),
              const SizedBox(width: 4),
              Transform.scale(
                scale: compact ? 0.78 : 0.8,
                child: Switch(
                  value: group.enabled,
                  onChanged: onToggleEnabled,
                  activeThumbColor: const Color(0xFF6B4423),
                  materialTapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
                ),
              ),
            ],
          );
        }

        Widget buildActionButtons() {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17),
                color: const Color(0xFF6B4423),
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                color: const Color(0xFFC62828),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: onDelete,
              ),
            ],
          );
        }

        Widget buildOptionsWrap() {
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: group.options.map((option) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: option.isDefault
                        ? const Color(0xFFFF8F4F).withValues(alpha: 0.5)
                        : const Color(0xFFE2D6CA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: option.isDefault ? FontWeight.w700 : FontWeight.w500,
                        color: const Color(0xFF4A3B32),
                      ),
                    ),
                    if (option.priceDelta > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '+${_money(option.priceDelta)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8C7564),
                        ),
                      ),
                    ],
                    if (option.isDefault) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8D2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF8D4004)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        }

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 14,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEFE6DC))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                // Row 1: Drag/reorder icon + customization name + edit/delete actions
                Row(
                  children: [
                    buildReorderButtons(horizontal: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: group.enabled ? const Color(0xFF4A2C11) : const Color(0xFF9E8D81),
                          decoration: group.enabled ? null : TextDecoration.lineThrough,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    buildActionButtons(),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 2: Selection type badge (Single/Multi, Required/Optional) + Active toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: buildRuleBadge()),
                    const SizedBox(width: 8),
                    buildActiveToggle(compact: true),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 3: Assigned products/categories badge
                buildScopeBadges(),
              ] else ...[
                // Desktop: Single horizontal header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    buildReorderButtons(horizontal: false),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  group.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: group.enabled ? const Color(0xFF4A2C11) : const Color(0xFF9E8D81),
                                    decoration: group.enabled ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              buildRuleBadge(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          buildScopeBadges(),
                        ],
                      ),
                    ),
                    buildActiveToggle(compact: false),
                    buildActionButtons(),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              buildOptionsWrap(),
            ],
          ),
        );
      },
    );
  }
}


class _AdminInventoryView extends StatefulWidget {
  const _AdminInventoryView({required this.controller});

  final CoffeePosController controller;

  @override
  State<_AdminInventoryView> createState() => _AdminInventoryViewState();
}

class _AdminInventoryViewState extends State<_AdminInventoryView> {
  String _search = '';
  String _status = 'All';
  int _page = 0;
  static const int _pageSize = 12;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    var list = controller.inventoryHealth;

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((item) => item.itemName.toLowerCase().contains(q)).toList();
    }
    if (_status == 'Low Stock') {
      list = list.where((item) => item.severity != InventorySeverity.good).toList();
    } else if (_status == 'In Stock') {
      list = list.where((item) => item.severity == InventorySeverity.good).toList();
    } else if (_status == 'Out of Stock') {
      list = list.where((item) => item.onHand == 0).toList();
    }

    final totalItems = list.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    if (_page >= totalPages) _page = totalPages - 1;

    final startIndex = _page * _pageSize;
    final pageItems = list.skip(startIndex).take(_pageSize).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 10 : 16,
            vertical: isNarrow ? 10 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          _AdminPageHeader(
            title: 'Inventory',
            subtitle: 'Stock levels, reorder thresholds, and inventory health',
            trailing: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ActionButton(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload Stock',
                  onPressed: () => _importInventoryExcel(context, controller),
                ),
                _ActionButton(
                  icon: Icons.download_rounded,
                  label: 'Download Stock',
                  onPressed: () => _exportInventoryExcel(context, controller),
                ),
                FilledButton.icon(
                  onPressed: () => _openInventoryDialog(context, controller),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Item'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4423),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter Toolbar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFE6DC)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() {
                      _search = val;
                      _page = 0;
                    }),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search inventory...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF8C7564)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2D6CA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2D6CA)),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D6CA)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Stock', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Low Stock', child: Text('Low Stock', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'In Stock', child: Text('In Stock', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Out of Stock', child: Text('Out of Stock', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _status = val;
                            _page = 0;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Inventory Table or Empty State
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFE6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.inventoryHealth.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.warehouse_outlined, size: 40, color: Color(0xFFBCAAA4)),
                        const SizedBox(height: 10),
                        const Text(
                          'No inventory items yet',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4A3B32)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add items or import an Excel inventory sheet to track stock.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8C7564)),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _openInventoryDialog(context, controller),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Item'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6B4423),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 46,
                      dataRowMaxHeight: 52,
                      columnSpacing: 24,
                      horizontalMargin: 16,
                      headingTextStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B4423),
                      ),
                      columns: const [
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('On Hand')),
                        DataColumn(label: Text('Threshold')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final item in pageItems)
                          DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _severityColor(item.severity),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2F251E),
                                          ),
                                        ),
                                        if (item.statusLabel.isNotEmpty)
                                          Text(
                                            item.statusLabel,
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF8C7564)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${item.onHand}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _severityColor(item.severity),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${item.threshold}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF4A3B32)),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.severity == InventorySeverity.good
                                        ? const Color(0xFFE8F5E9)
                                        : item.severity == InventorySeverity.warning
                                            ? const Color(0xFFFFF3E0)
                                            : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _severityLabel(item.severity).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: _severityColor(item.severity),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      tooltip: 'Edit item',
                                      color: const Color(0xFF6B4423),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _openInventoryDialog(context, controller, initial: item),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                      tooltip: 'Delete item',
                                      color: const Color(0xFFB5442F),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDelete(
                                        context,
                                        title: 'Delete Inventory Item',
                                        message: 'Are you sure you want to delete "${item.itemName}"?',
                                        onConfirm: () => controller.deleteInventoryItem(item.id),
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
                  if (pageItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      alignment: Alignment.center,
                      child: const Text(
                        'No inventory items matching filter',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
                      ),
                    ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFEFE6DC)),
                  _PaginationBar(
                    currentPage: _page,
                    totalPages: totalPages,
                    totalItems: totalItems,
                    pageSize: _pageSize,
                    onPageChanged: (page) => setState(() => _page = page),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _AdminOrdersView extends StatefulWidget {
  const _AdminOrdersView({required this.controller});

  final CoffeePosController controller;

  @override
  State<_AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<_AdminOrdersView> {
  _AdminDatePreset _preset = _AdminDatePreset.thisMonth;
  DateTimeRange? _customRange;
  String _search = '';
  PaymentType? _paymentType;
  OrderStatus? _status;
  int _page = 0;
  static const int _pageSize = 12;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    var list = _filterOrdersByDate(controller.recentOrders, _preset, _customRange);

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((o) =>
          o.orderNumber.toLowerCase().contains(q) ||
          o.cashierName.toLowerCase().contains(q) ||
          ((o.originalQueue?.customerName != null) &&
              o.originalQueue!.customerName.toLowerCase().contains(q))).toList();
    }
    if (_paymentType != null) {
      list = list.where((o) => o.paymentType == _paymentType).toList();
    }
    if (_status != null) {
      list = list.where((o) => o.status == _status).toList();
    }

    final totalItems = list.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    if (_page >= totalPages) _page = totalPages - 1;

    final startIndex = _page * _pageSize;
    final pageItems = list.skip(startIndex).take(_pageSize).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 10 : 16,
            vertical: isNarrow ? 10 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          _AdminPageHeader(
            title: 'Orders',
            subtitle: 'Order history, activity logs, and customer receipts',
            trailing: _AdminDateRangeSelector(
              preset: _preset,
              customRange: _customRange,
              onPresetSelected: (preset) => setState(() {
                _preset = preset;
                _customRange = null;
                _page = 0;
              }),
              onCustomRangeSelected: (range) => setState(() {
                _preset = _AdminDatePreset.custom;
                _customRange = range;
                _page = 0;
              }),
            ),
          ),
          const SizedBox(height: 14),

          // Filters Toolbar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFE6DC)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() {
                      _search = val;
                      _page = 0;
                    }),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search order #, cashier...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF8C7564)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2D6CA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2D6CA)),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D6CA)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PaymentType?>(
                      value: _paymentType,
                      hint: const Text('All Payments', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem<PaymentType?>(
                          value: null,
                          child: Text('All Payments', style: TextStyle(fontSize: 12)),
                        ),
                        for (final pt in PaymentType.values)
                          DropdownMenuItem<PaymentType?>(
                            value: pt,
                            child: Text(pt.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                      onChanged: (val) => setState(() {
                        _paymentType = val;
                        _page = 0;
                      }),
                    ),
                  ),
                ),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D6CA)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<OrderStatus?>(
                      value: _status,
                      hint: const Text('All Statuses', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem<OrderStatus?>(
                          value: null,
                          child: Text('All Statuses', style: TextStyle(fontSize: 12)),
                        ),
                        for (final s in OrderStatus.values)
                          DropdownMenuItem<OrderStatus?>(
                            value: s,
                            child: Text(s.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                      onChanged: (val) => setState(() {
                        _status = val;
                        _page = 0;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Orders Table
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFE6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 52,
                    columnSpacing: 18,
                    horizontalMargin: 16,
                    headingTextStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B4423),
                    ),
                    columns: const [
                      DataColumn(label: Text('Order #')),
                      DataColumn(label: Text('Date & Time')),
                      DataColumn(label: Text('Cashier')),
                      DataColumn(label: Text('Payment')),
                      DataColumn(label: Text('Total')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: [
                      for (final order in pageItems) ...[
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2F251E),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatDateTime(order.createdAt),
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B584C)),
                              ),
                            ),
                            DataCell(
                              Text(
                                order.cashierName.isEmpty ? 'Staff' : order.cashierName,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF2F251E)),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3ECE4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  order.paymentType.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6B4423),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _money(_orderSummary(order).total),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2F251E),
                                ),
                              ),
                            ),
                            DataCell(
                              _buildOrderStatusBadge(order),
                            ),
                            DataCell(
                              OutlinedButton.icon(
                                onPressed: () => _openOrderDetailsDialog(context, controller, order),
                                icon: const Icon(Icons.visibility_outlined, size: 14),
                                label: const Text('View'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6B4423),
                                  side: const BorderSide(color: Color(0xFFD4C3B3)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (pageItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    alignment: Alignment.center,
                    child: const Text(
                      'No orders found matching filters',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9E8D81)),
                    ),
                  ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFEFE6DC)),
                _PaginationBar(
                  currentPage: _page,
                  totalPages: totalPages,
                  totalItems: totalItems,
                  pageSize: _pageSize,
                  onPageChanged: (page) => setState(() => _page = page),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildOrderStatusBadge(OrderRecord order) {
    final isVoided = order.status == OrderStatus.voided;
    final isCompleted = order.status == OrderStatus.paid &&
        order.statusHistory.any((entry) => entry.action == OrderAction.complete);
    final isRefunded = order.status == OrderStatus.refunded;
    final String label = isVoided
        ? 'CANCELLED'
        : isCompleted
            ? 'COMPLETED'
            : isRefunded
                ? 'REFUNDED'
                : order.status.name.toUpperCase();

    final Color bg = isCompleted
        ? const Color(0xFFE8F5E9)
        : isVoided
            ? const Color(0xFFFFEBEE)
            : isRefunded
                ? const Color(0xFFFFF3E0)
                : const Color(0xFFFFEDE1);

    final Color text = isCompleted
        ? const Color(0xFF2E7D32)
        : isVoided
            ? const Color(0xFFC62828)
            : isRefunded
                ? const Color(0xFFE65100)
                : const Color(0xFF8B4513);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: text.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : (currentPage * pageSize) + 1;
    final end = math.min((currentPage + 1) * pageSize, totalItems);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          final info = Text(
            'Showing $start–$end of $totalItems',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7564)),
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: const Color(0xFF6B4423),
                onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Page ${currentPage + 1} of $totalPages',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A3B32),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: const Color(0xFF6B4423),
                onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                info,
                const SizedBox(height: 6),
                controls,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              info,
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6B4423);
    const fill = Color(0xFFFFE8D2);
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(height: 34),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: fill,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withValues(alpha: 0.18)),
          ),
          visualDensity: VisualDensity.compact,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

Future<void> _openOrderDetailsDialog(
  BuildContext context,
  CoffeePosController controller,
  OrderRecord order,
) async {
  final isVoided = order.status == OrderStatus.voided;
  final isCompleted = order.status == OrderStatus.paid &&
      order.statusHistory.any((entry) => entry.action == OrderAction.complete);
  final isRefunded = order.status == OrderStatus.refunded;
  final String statusLabel = isVoided
      ? 'CANCELLED'
      : isCompleted
          ? 'COMPLETED'
          : isRefunded
              ? 'REFUNDED'
              : order.status.name.toUpperCase();

  final Color badgeBg = isCompleted
      ? const Color(0xFFE8F5E9)
      : isVoided
          ? const Color(0xFFFFEBEE)
          : isRefunded
              ? const Color(0xFFFFF3E0)
              : const Color(0xFFFFEDE1);

  final Color badgeText = isCompleted
      ? const Color(0xFF2E7D32)
      : isVoided
          ? const Color(0xFFC62828)
          : isRefunded
              ? const Color(0xFFE65100)
              : const Color(0xFF8B4513);

  final discountLabel = order.discountApplication.label;
  final hasDiscountLabel = discountLabel != null && discountLabel.isNotEmpty;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      bool isPrinting = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: const Color(0xFFFFFDFB),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE8D2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFF6B4423),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #${order.orderNumber}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2F251E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDateTime(order.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8C7564),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: badgeText.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFEFE6DC)),
                    const SizedBox(height: 10),

                    // Meta Information
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F5F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cashier',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF8C7564)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  order.cashierName.isEmpty ? 'Staff' : order.cashierName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2F251E)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Method',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF8C7564)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  order.paymentType.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2F251E)),
                                ),
                              ],
                            ),
                          ),
                          if (order.originalQueue?.customerName != null && order.originalQueue!.customerName.isNotEmpty)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Customer',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF8C7564)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.originalQueue!.customerName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2F251E)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items list
                    const Text(
                      'Ordered Items',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A3B32),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFEFE6DC)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  for (int i = 0; i < order.items.length; i++) ...[
                                    if (i > 0) const Divider(height: 1, color: Color(0xFFF3ECE4)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFE8D2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${order.items[i].quantity}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF6B4423),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  order.items[i].productName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2F251E),
                                                  ),
                                                ),
                                                if (order.items[i].selectedModifiers.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    order.items[i].selectedModifiers
                                                        .map((m) => m.name)
                                                        .join(', '),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontStyle: FontStyle.italic,
                                                      color: Color(0xFF8C7564),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _money(order.items[i].lineTotal),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2F251E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Calculations breakdown
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBF7),
                                border: Border.all(color: const Color(0xFFEFE6DC)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  _ReceiptSummaryRow(label: 'Subtotal', value: _money(order.subtotal)),
                                  if (order.discount > 0)
                                    _ReceiptSummaryRow(
                                      label: 'Discount (${hasDiscountLabel ? discountLabel : "Promo"})',
                                      value: '-${_money(order.discount)}',
                                      valueColor: const Color(0xFFC62828),
                                    ),
                                  if (order.tax > 0)
                                    _ReceiptSummaryRow(label: 'VAT (12%)', value: _money(order.tax)),
                                  if (order.serviceCharge > 0)
                                    _ReceiptSummaryRow(label: 'Service Charge', value: _money(order.serviceCharge)),
                                  const Divider(height: 16, color: Color(0xFFEFE6DC)),
                                  _ReceiptSummaryRow(
                                    label: 'Total',
                                    value: _money(order.total),
                                    isBold: true,
                                    fontSize: 15,
                                  ),
                                  if (order.paymentType == PaymentType.cash && order.cashReceived > 0) ...[
                                    const SizedBox(height: 4),
                                    _ReceiptSummaryRow(label: 'Cash Tendered', value: _money(order.cashReceived)),
                                    _ReceiptSummaryRow(label: 'Change', value: _money(order.change)),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Status history
                            if (order.statusHistory.isNotEmpty) ...[
                              const Text(
                                'Status History',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A3B32),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F5F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final change in order.statusHistory) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.circle, size: 6, color: Color(0xFFFF8F4F)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${switch (change.action) {
                                                  OrderAction.complete => 'Completed',
                                                  OrderAction.cancel => 'Cancelled',
                                                  OrderAction.refund => 'Refunded',
                                                }} by ${change.cashierName} • ${_formatDateTime(change.at)}',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF4A3B32)),
                                              ),
                                            ),
                                            if (change.action == OrderAction.refund)
                                              Text(
                                                'Refund: ${_money(change.amount)}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC62828)),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Actions
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Close'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B4423),
                            side: const BorderSide(color: Color(0xFFD4C3B3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: isPrinting
                              ? null
                              : () async {
                                  setState(() => isPrinting = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    final printResult = await controller.printReceipt(
                                      order,
                                      manualReprint: true,
                                    );
                                    final String msg;
                                    if (printResult.status ==
                                        receipt_printer.PrintStatus.submittedToDialog) {
                                      msg = 'Print dialog opened for ${order.id}';
                                    } else if (printResult.isSuccess) {
                                      msg = 'Receipt printed for ${order.orderNumber}';
                                    } else if (printResult.status ==
                                        receipt_printer.PrintStatus.canceled) {
                                      msg = 'Print cancelled.';
                                    } else {
                                      msg = 'Unable to print receipt. Check printer connection.';
                                    }
                                    showAutoHidingSnackBar(
                                      messenger: messenger,
                                      content: Text(msg),
                                      duration: const Duration(seconds: 5),
                                    );
                                  } catch (e) {
                                    showAutoHidingSnackBar(
                                      messenger: messenger,
                                      content: const Text(
                                        'Unable to print receipt. Please check the printer connection.',
                                      ),
                                      duration: const Duration(seconds: 5),
                                    );
                                  } finally {
                                    if (dialogContext.mounted) {
                                      setState(() => isPrinting = false);
                                    }
                                  }
                                },
                          icon: isPrinting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.print_outlined, size: 16),
                          label: Text(isPrinting ? 'Printing...' : 'Print Receipt'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6B4423),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ReceiptSummaryRow extends StatelessWidget {
  const _ReceiptSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.fontSize = 12,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
      color: valueColor ?? const Color(0xFF2F251E),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: const Color(0xFF7A6A5E))),
          Text(value, style: style),
        ],
      ),
    );
  }
}

Future<void> _openProductDialog(
  BuildContext context,
  CoffeePosController controller, {
  Product? initial,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _ProductFormDialog(controller: controller, initial: initial),
  );
}

Future<void> _openModifierGroupDialog(
  BuildContext context,
  CoffeePosController controller, [
  ModifierGroup? initial,
]) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _ModifierGroupFormDialog(controller: controller, initial: initial),
  );
}

Future<void> _openInventoryDialog(
  BuildContext context,
  CoffeePosController controller, {
  InventoryHealth? initial,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _InventoryFormDialog(controller: controller, initial: initial),
  );
}

Future<void> _exportToFile(
  BuildContext context,
  CoffeePosController controller,
) async {
  final fileName = _exportFileName(
    controller,
    kind: 'admin-backup',
    extension: 'json',
    now: DateTime.now(),
  );
  final savedTo = await saveTextToDownloads(
    text: controller.exportStateJson(),
    fileName: fileName,
    mimeType: 'application/json',
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup saved to ${_savedFileLabel(savedTo)}')),
    );
  }
}

Future<void> _importFromFile(
  BuildContext context,
  CoffeePosController controller,
) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'JSON', extensions: <String>['json']),
    ],
  );
  if (file == null) {
    return;
  }
  try {
    final text = await file.readAsString();
    if (!context.mounted) {
      return;
    }
    final confirmed = await _confirmImport(
      context,
      controller,
      fileName: file.name,
    );
    if (confirmed != true) {
      return;
    }
    controller.importStateJson(text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store records successfully restored from backup.')),
      );
    }
  } on FormatException catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to restore store records. Please check the backup file.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to restore data. The selected file format is invalid.')),
      );
    }
  }
}

Future<bool?> _confirmImport(
  BuildContext context,
  CoffeePosController controller, {
  required String fileName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Replace Store Data?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.isDemo
                  ? 'You are in Demo Mode. Restoring "$fileName" will replace demo data in this session only, and will never affect live store records.'
                  : 'You are about to restore "$fileName". This will replace your current store records with the backup file.',
            ),
            const SizedBox(height: 12),
            Text(
              'Replaced data includes ${controller.products.length} products, '
              '${controller.inventoryHealth.length} inventory rows, '
              '${controller.recentOrders.length} recent orders, '
              '${controller.activeOrders.length} active tickets, '
              '${controller.activeShifts.length} shifts, and current settings.',
            ),
            const SizedBox(height: 12),
            Text(
              controller.isDemo
                  ? 'This applies only to your demo session.'
                  : 'Use this only if you want to restore your store records from this backup file.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Replace Store Data'),
        ),
      ],
    ),
  );
}

Future<void> _exportProductsExcel(
  BuildContext context,
  CoffeePosController controller,
) async {
  final bytes = _buildProductsWorkbook(
    controller: controller,
    products: controller.products,
  );
  final savedTo = await saveBytesToDownloads(
    bytes: bytes,
    fileName: _exportFileName(
      controller,
      kind: 'products-export',
      extension: 'xlsx',
      now: DateTime.now(),
    ),
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menu downloaded to ${_savedFileLabel(savedTo)}'),
      ),
    );
  }
}

Future<void> importProductsExcel(
  BuildContext context,
  CoffeePosController controller,
) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: <String>['xlsx']),
    ],
  );
  if (file == null) {
    return;
  }

  try {
    final workbook = xl.Excel.decodeBytes(await file.readAsBytes());
    final menu = parseMenuWorkbook(
      workbook,
      existingGroups: controller.modifierGroups,
    );
    final products = menu.products;
    if (!context.mounted) {
      return;
    }
    final confirmed = await _confirmProductImport(
      context,
      fileName: file.name,
      productCount: products.length,
    );
    if (confirmed != true) {
      return;
    }
    controller.replaceProducts(
      products,
      categories: menu.categories,
      modifierGroups: menu.modifierGroups,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully loaded ${products.length} products to your menu.'),
        ),
      );
    }
  } on FormatException catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update menu. Please select a valid spreadsheet.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update menu. Please select a valid spreadsheet.')),
      );
    }
  }
}

Future<void> _exportInventoryExcel(
  BuildContext context,
  CoffeePosController controller,
) async {
  final bytes = _buildInventoryWorkbook(controller.inventoryHealth);
  final savedTo = await saveBytesToDownloads(
    bytes: bytes,
    fileName: _exportFileName(
      controller,
      kind: 'inventory-export',
      extension: 'xlsx',
      now: DateTime.now(),
    ),
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stock report downloaded to ${_savedFileLabel(savedTo)}'),
      ),
    );
  }
}

Future<void> _importInventoryExcel(
  BuildContext context,
  CoffeePosController controller,
) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: <String>['xlsx']),
    ],
  );
  if (file == null) {
    return;
  }

  try {
    final workbook = xl.Excel.decodeBytes(await file.readAsBytes());
    final inventoryItems = _parseInventoryFromWorkbook(workbook);
    if (!context.mounted) {
      return;
    }
    final confirmed = await _confirmInventoryImport(
      context,
      fileName: file.name,
      itemCount: inventoryItems.length,
    );
    if (confirmed != true) {
      return;
    }
    controller.replaceInventoryItems(inventoryItems);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully updated ${inventoryItems.length} stock items.'),
        ),
      );
    }
  } on FormatException catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update stock. Please select a valid spreadsheet.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update stock. Please select a valid spreadsheet.')),
      );
    }
  }
}

Future<bool?> _confirmInventoryImport(
  BuildContext context, {
  required String fileName,
  required int itemCount,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Replace Stock List?'),
      content: Text(
        'Upload "$fileName" and update your inventory list with $itemCount stock items?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Update Stock'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmProductImport(
  BuildContext context, {
  required String fileName,
  required int productCount,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Update Menu?'),
      content: Text(
        'Upload "$fileName" and update your menu with $productCount products?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Update Menu'),
        ),
      ],
    ),
  );
}

List<int> _buildProductsWorkbook({
  required CoffeePosController controller,
  required List<Product> products,
}) {
  final excel = xl.Excel.createExcel();
  final sheet = excel['Products'];
  if (excel.tables.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }
  excel.setDefaultSheet('Products');

  sheet.appendRow([
    xl.TextCellValue('Product ID'),
    xl.TextCellValue('Name'),
    xl.TextCellValue('Category ID'),
    xl.TextCellValue('Category Name'),
    xl.TextCellValue('Category Icon'),
    xl.TextCellValue('Price'),
    xl.TextCellValue('Description'),
    xl.TextCellValue('Badge'),
    xl.TextCellValue('Modifier Group IDs'),
    xl.TextCellValue('Image URL'),
    xl.TextCellValue('Available'),
  ]);

  for (final product in products) {
    final category = _categoryForProduct(controller, product.categoryId);
    sheet.appendRow([
      xl.TextCellValue(product.id),
      xl.TextCellValue(product.name),
      xl.TextCellValue(product.categoryId),
      xl.TextCellValue(category?.name ?? ''),
      xl.TextCellValue(category?.icon ?? ''),
      xl.DoubleCellValue(product.price),
      xl.TextCellValue(product.description),
      xl.TextCellValue(product.badge),
      xl.TextCellValue(
        controller
            .modifierGroupsForProduct(product)
            .map((group) => group.id)
            .join(', '),
      ),
      xl.TextCellValue(product.imageUrl ?? ''),
      xl.BoolCellValue(product.isAvailable),
    ]);
  }

  final allGroups = <String, ModifierGroup>{};
  for (final group in controller.modifierGroups) {
    allGroups[group.id] = group;
  }
  for (final product in products) {
    for (final group in controller.modifierGroupsForProduct(product)) {
      allGroups[group.id] = group;
    }
  }
  if (allGroups.isNotEmpty) {
    final sheet = excel['Modifiers'];
    sheet.appendRow(
      [
        'Group ID',
        'Group Name',
        'Option ID',
        'Option Name',
        'Price Delta',
        'Min Selected',
        'Max Selected',
        'Default',
        'Active',
        'Target Categories',
        'Target Products',
      ].map(xl.TextCellValue.new).toList(),
    );
    for (final group in allGroups.values) {
      final categoryNames = group.targetCategoryIds
          .map((id) => controller.categories.where((c) => c.id == id).firstOrNull?.name ?? id)
          .join(', ');
      final productNames = group.targetProductIds
          .map((id) => controller.products.where((p) => p.id == id).firstOrNull?.name ?? id)
          .join(', ');

      for (final option in group.options) {
        sheet.appendRow([
          xl.TextCellValue(group.id),
          xl.TextCellValue(group.name),
          xl.TextCellValue(option.id),
          xl.TextCellValue(option.name),
          xl.DoubleCellValue(option.priceDelta),
          xl.IntCellValue(group.minSelected),
          xl.IntCellValue(group.maxSelected),
          xl.BoolCellValue(option.isDefault),
          xl.BoolCellValue(group.enabled),
          xl.TextCellValue(categoryNames),
          xl.TextCellValue(productNames),
        ]);
      }
    }
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('Unable to create the Excel workbook.');
  }
  return bytes;
}

List<int> _buildInventoryWorkbook(List<InventoryHealth> items) {
  final excel = xl.Excel.createExcel();
  final sheet = excel['Inventory'];
  if (excel.tables.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }
  excel.setDefaultSheet('Inventory');

  sheet.appendRow([
    xl.TextCellValue('Item ID'),
    xl.TextCellValue('Item Name'),
    xl.TextCellValue('Status Label'),
    xl.TextCellValue('On Hand'),
    xl.TextCellValue('Threshold'),
    xl.TextCellValue('Severity'),
  ]);

  for (final item in items) {
    sheet.appendRow([
      xl.TextCellValue(item.id),
      xl.TextCellValue(item.itemName),
      xl.TextCellValue(item.statusLabel),
      xl.IntCellValue(item.onHand),
      xl.IntCellValue(item.threshold),
      xl.TextCellValue(item.severity.name),
    ]);
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('Unable to create the Excel workbook.');
  }
  return bytes;
}

String _slugifyProductName(String value) {
  final normalized = value.trim().toLowerCase();
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return slug.replaceAll(RegExp(r'^-+|-+$'), '');
}

String _excelCellTextValue(xl.Data? cell) {
  return _excelCellValueText(cell?.value);
}

String _excelCellTextAt(List<xl.Data?> row, int index) {
  if (index < 0 || index >= row.length) {
    return '';
  }
  return _excelCellValueText(row[index]?.value);
}

/// Returns the displayed value of an Excel cell.
///
/// `TextCellValue.toString()` returns a `TextSpan` debug description rather
/// than the cell text. Reading the span's plain text keeps imports compatible
/// with Excel files created both by this app and by spreadsheet programs.
String _excelCellValueText(xl.CellValue? value) {
  if (value == null) {
    return '';
  }
  if (value is xl.TextCellValue) {
    return value.value.toString().trim();
  }
  if (value is xl.IntCellValue) {
    return value.value.toString();
  }
  if (value is xl.DoubleCellValue) {
    return value.value.toString();
  }
  if (value is xl.BoolCellValue) {
    return value.value.toString();
  }
  return value.toString().trim();
}

double _excelCellDoubleAt(List<xl.Data?> row, int index) {
  final value = _excelCellTextAt(row, index);
  return double.tryParse(value) ?? 0;
}

String _normalizeExcelHeader(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
}

String _exportFileName(
  CoffeePosController controller, {
  required String kind,
  required String extension,
  required DateTime now,
}) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final stamp =
      '${now.year}-${twoDigits(now.month)}-${twoDigits(now.day)}_${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}';
  final store = _slugifyFileComponent(controller.storeName);
  return '$store-$kind-$stamp.$extension';
}

String _savedFileLabel(String savedTo) {
  if (savedTo.trim().isEmpty) {
    return 'Downloads';
  }
  return savedTo.split(RegExp(r'[\\/]+')).last;
}

String _slugifyFileComponent(String value) {
  final normalized = value.trim().toLowerCase();
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return slug.replaceAll(RegExp(r'^-+|-+$'), '');
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required VoidCallback onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    onConfirm();
  }
}

List<InventoryHealth> _parseInventoryFromWorkbook(xl.Excel workbook) {
  final sheet =
      workbook.tables['Inventory'] ??
      workbook.tables[workbook.getDefaultSheet() ?? ''] ??
      (workbook.tables.values.isNotEmpty ? workbook.tables.values.first : null);
  if (sheet == null) {
    throw const FormatException('No worksheet found in the Excel file.');
  }

  final rows = sheet.rows
      .where((row) => row.any((cell) => _excelCellTextValue(cell).isNotEmpty))
      .toList(growable: false);
  if (rows.length < 2) {
    throw const FormatException(
      'The Excel file must include a header row and at least one inventory row.',
    );
  }

  final headerIndex = <String, int>{};
  final headers = rows.first;
  for (var index = 0; index < headers.length; index++) {
    final header = _normalizeExcelHeader(_excelCellTextValue(headers[index]));
    if (header.isNotEmpty && !headerIndex.containsKey(header)) {
      headerIndex[header] = index;
    }
  }

  int? findHeader(List<String> aliases) {
    for (final alias in aliases) {
      final index = headerIndex[_normalizeExcelHeader(alias)];
      if (index != null) {
        return index;
      }
    }
    return null;
  }

  final itemNameIndex = findHeader(const ['item name', 'name']);
  final statusIndex = findHeader(const ['status label', 'status']);
  final onHandIndex = findHeader(const ['on hand', 'onhand']);
  final thresholdIndex = findHeader(const ['threshold']);
  final itemIdIndex = findHeader(const ['item id', 'id']);
  final severityIndex = findHeader(const ['severity']);
  if (itemNameIndex == null ||
      statusIndex == null ||
      onHandIndex == null ||
      thresholdIndex == null) {
    throw const FormatException(
      'Missing required columns: Item Name, Status Label, On Hand, and Threshold.',
    );
  }

  final items = <InventoryHealth>[];
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    final itemName = _excelCellTextAt(row, itemNameIndex);
    if (itemName.isEmpty) {
      continue;
    }
    final onHand = _excelCellDoubleAt(row, onHandIndex).round();
    final threshold = _excelCellDoubleAt(row, thresholdIndex).round();
    final severityLabel = severityIndex == null
        ? ''
        : _excelCellTextAt(row, severityIndex);
    final severity = _parseSeverity(severityLabel);
    final importedId = itemIdIndex == null
        ? ''
        : _excelCellTextAt(row, itemIdIndex);

    items.add(
      InventoryHealth(
        id: importedId.isEmpty
            ? 'inv-${_slugifyProductName(itemName)}-${rowIndex + 1}'
            : _slugifyProductName(importedId),
        itemName: itemName,
        statusLabel: _excelCellTextAt(row, statusIndex),
        onHand: onHand,
        threshold: threshold,
        severity: severity,
      ),
    );
  }

  if (items.isEmpty) {
    throw const FormatException(
      'No inventory rows were found in the Excel file.',
    );
  }
  return items;
}

InventorySeverity _parseSeverity(String value) {
  switch (_normalizeExcelHeader(value)) {
    case 'warning':
      return InventorySeverity.warning;
    case 'critical':
      return InventorySeverity.critical;
    default:
      return InventorySeverity.good;
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({required this.controller, this.initial});

  final CoffeePosController controller;
  final Product? initial;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _badgeController;
  String? _categoryId;
  late Set<String> _modifierGroupIds;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _priceController = TextEditingController(
      text: initial == null ? '' : initial.price.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _badgeController = TextEditingController(text: initial?.badge ?? '');
    _categoryId =
        initial?.categoryId ?? widget.controller.categories.firstOrNull?.id;
    _modifierGroupIds = initial == null
        ? widget.controller
              .defaultModifierGroupIdsForCategory(_categoryId ?? '')
              .toSet()
        : widget.controller
              .modifierGroupsForProduct(initial)
              .map((group) => group.id)
              .toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.categories;
    final modifierGroups = widget.controller.modifierGroups;
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add product' : 'Edit product'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: _CategoryLabel(category: category),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _badgeController,
                  decoration: const InputDecoration(
                    labelText: 'Badge label (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Available add-ons',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 4),
                if (modifierGroups.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No add-ons have been configured.'),
                  )
                else
                  ...modifierGroups.map(
                    (group) {
                      final viaCategory = _categoryId != null &&
                          (group.targetCategoryIds.contains(_categoryId) ||
                              widget.controller.categories
                                  .where((c) => c.id == _categoryId)
                                  .any((c) => c.modifierGroupIds.contains(group.id)));
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Row(
                          children: [
                            Expanded(child: Text(group.name)),
                            if (viaCategory)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'via category',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${group.selectionRuleLabel} • ${group.options.isEmpty ? 'No options' : group.options.map((option) => option.name).join(', ')}',
                        ),
                        value: _modifierGroupIds.contains(group.id) || viaCategory,
                        onChanged: viaCategory
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected ?? false) {
                                    _modifierGroupIds.add(group.id);
                                  } else {
                                    _modifierGroupIds.remove(group.id);
                                  }
                                });
                              },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate() || _categoryId == null) {
              return;
            }
            final price = double.parse(_priceController.text);
            if (widget.initial == null) {
              widget.controller.createProduct(
                name: _nameController.text.trim(),
                categoryId: _categoryId!,
                price: price,
                description: _descriptionController.text.trim(),
                badge: _badgeController.text.trim(),
                modifierGroupIds: _modifierGroupIds.toList(),
              );
            } else {
              widget.controller.updateProduct(
                productId: widget.initial!.id,
                name: _nameController.text.trim(),
                categoryId: _categoryId!,
                price: price,
                description: _descriptionController.text.trim(),
                badge: _badgeController.text.trim(),
                modifierGroupIds: _modifierGroupIds.toList(),
              );
            }
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ModifierGroupFormDialog extends StatefulWidget {
  const _ModifierGroupFormDialog({required this.controller, this.initial});

  final CoffeePosController controller;
  final ModifierGroup? initial;

  @override
  State<_ModifierGroupFormDialog> createState() => _ModifierGroupFormDialogState();
}

class _OptionDraft {
  _OptionDraft({
    required this.id,
    required String name,
    required double priceDelta,
    required this.isDefault,
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(
          text: priceDelta == 0 ? '0.00' : priceDelta.toStringAsFixed(2),
        );

  final String id;
  final TextEditingController nameController;
  final TextEditingController priceController;
  bool isDefault;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class _ModifierGroupFormDialogState extends State<_ModifierGroupFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _minSelectedController;
  late final TextEditingController _maxSelectedController;

  late bool _isSingleSelect;
  late bool _isRequired;
  late bool _enabled;
  late Set<String> _targetCategoryIds;
  late Set<String> _targetProductIds;
  final List<_OptionDraft> _options = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _isSingleSelect = initial?.isSingleSelect ?? true;
    _isRequired = initial?.isRequired ?? true;
    _enabled = initial?.enabled ?? true;

    _minSelectedController = TextEditingController(
      text: initial == null ? '1' : initial.minSelected.toString(),
    );
    _maxSelectedController = TextEditingController(
      text: initial == null ? '1' : initial.maxSelected.toString(),
    );

    _targetCategoryIds = initial == null
        ? <String>{}
        : initial.targetCategoryIds.toSet();

    _targetProductIds = initial == null
        ? <String>{}
        : initial.targetProductIds.toSet();

    if (initial != null) {
      for (final cat in widget.controller.categories) {
        if (cat.modifierGroupIds.contains(initial.id)) {
          _targetCategoryIds.add(cat.id);
        }
      }
      for (final prod in widget.controller.products) {
        if (prod.modifierGroupIds.contains(initial.id)) {
          _targetProductIds.add(prod.id);
        }
      }
      for (final opt in initial.options) {
        _options.add(
          _OptionDraft(
            id: opt.id,
            name: opt.name,
            priceDelta: opt.priceDelta,
            isDefault: opt.isDefault,
          ),
        );
      }
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      _options.add(
        _OptionDraft(
          id: 'opt_${now}_1',
          name: '',
          priceDelta: 0.0,
          isDefault: true,
        ),
      );
      _options.add(
        _OptionDraft(
          id: 'opt_${now}_2',
          name: '',
          priceDelta: 0.0,
          isDefault: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minSelectedController.dispose();
    _maxSelectedController.dispose();
    for (final opt in _options) {
      opt.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      _options.add(
        _OptionDraft(
          id: 'opt_${now}_${_options.length + 1}',
          name: '',
          priceDelta: 0.0,
          isDefault: _isSingleSelect && _options.isEmpty,
        ),
      );
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 1) return;
    setState(() {
      final removed = _options.removeAt(index);
      final wasDefault = removed.isDefault;
      removed.dispose();
      if (wasDefault && _options.isNotEmpty) {
        _options.first.isDefault = true;
      }
    });
  }

  void _save() {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _errorMessage = 'Group name is required');
      return;
    }

    if (_options.isEmpty) {
      setState(() => _errorMessage = 'At least 1 option is required');
      return;
    }

    for (int i = 0; i < _options.length; i++) {
      if (_options[i].nameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Option #${i + 1} name cannot be empty');
        return;
      }
    }

    int minSelected;
    int maxSelected;
    if (_isSingleSelect) {
      minSelected = _isRequired ? 1 : 0;
      maxSelected = 1;
    } else {
      final parsedMin = int.tryParse(_minSelectedController.text) ?? (_isRequired ? 1 : 0);
      final parsedMax = int.tryParse(_maxSelectedController.text) ?? 0;
      minSelected = _isRequired ? math.max(1, parsedMin) : math.max(0, parsedMin);
      maxSelected = math.max(0, parsedMax);
      if (maxSelected > 0 && minSelected > maxSelected) {
        minSelected = maxSelected;
      }
    }

    if (_isSingleSelect) {
      var foundDefault = false;
      for (final opt in _options) {
        if (opt.isDefault && !foundDefault) {
          foundDefault = true;
        } else {
          opt.isDefault = false;
        }
      }
      if (!foundDefault && _isRequired && _options.isNotEmpty) {
        _options.first.isDefault = true;
      }
    }

    final options = _options.map((opt) {
      final price = double.tryParse(opt.priceController.text) ?? 0.0;
      return ModifierOption(
        id: opt.id,
        name: opt.nameController.text.trim(),
        priceDelta: price,
        isDefault: opt.isDefault,
      );
    }).toList();

    final isNew = widget.initial == null;
    final groupId = widget.initial?.id ??
        'mod_${trimmedName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';

    final group = ModifierGroup(
      id: groupId,
      name: trimmedName,
      minSelected: minSelected,
      maxSelected: maxSelected,
      options: options,
      enabled: _enabled,
      targetCategoryIds: _targetCategoryIds.toList(),
      targetProductIds: _targetProductIds.toList(),
    );

    if (isNew) {
      widget.controller.addModifierGroup(group);
    } else {
      widget.controller.updateModifierGroup(group);
    }

    widget.controller.assignModifierGroup(
      groupId,
      categoryIds: _targetCategoryIds.toList(),
      productIds: _targetProductIds.toList(),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.categories;
    final products = widget.controller.products;

    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Customization Group' : 'Edit Customization Group'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF9A9A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFC62828)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFC62828), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Group Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. Size, Milk, Flavor, Rice Type, Add-ons, Toppings',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Selection Mode & Requirement
                Text('Selection Type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _isSingleSelect = true;
                          _minSelectedController.text = _isRequired ? '1' : '0';
                          _maxSelectedController.text = '1';
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isSingleSelect ? const Color(0xFFFFE8D2) : const Color(0xFFFAF7F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isSingleSelect ? const Color(0xFFFF8F4F) : const Color(0xFFE2D6CA),
                              width: _isSingleSelect ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isSingleSelect ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: _isSingleSelect ? const Color(0xFF6B4423) : const Color(0xFF8C7564),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Single Choice',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _isSingleSelect ? const Color(0xFF6B4423) : const Color(0xFF4A3B32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text('Customer picks exactly 1', style: TextStyle(fontSize: 10.5, color: Color(0xFF8C7564))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _isSingleSelect = false;
                          _minSelectedController.text = _isRequired ? '1' : '0';
                          _maxSelectedController.text = '0';
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: !_isSingleSelect ? const Color(0xFFFFE8D2) : const Color(0xFFFAF7F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_isSingleSelect ? const Color(0xFFFF8F4F) : const Color(0xFFE2D6CA),
                              width: !_isSingleSelect ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    !_isSingleSelect ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    size: 16,
                                    color: !_isSingleSelect ? const Color(0xFF6B4423) : const Color(0xFF8C7564),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Multiple Choice',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: !_isSingleSelect ? const Color(0xFF6B4423) : const Color(0xFF4A3B32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text('Customer can select multiple', style: TextStyle(fontSize: 10.5, color: Color(0xFF8C7564))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Requirement Switch
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_isRequired ? 'Required Selection' : 'Optional Selection', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            _isRequired
                                ? 'Customer must choose from this group to add to cart'
                                : 'Customer can skip this group when ordering',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8C7564)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isRequired,
                      onChanged: (val) => setState(() {
                        _isRequired = val;
                        if (_isSingleSelect) {
                          _minSelectedController.text = val ? '1' : '0';
                        } else {
                          _minSelectedController.text = val ? '1' : '0';
                        }
                      }),
                      activeThumbColor: const Color(0xFF6B4423),
                    ),
                  ],
                ),

                if (!_isSingleSelect) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minSelectedController,
                          decoration: const InputDecoration(
                            labelText: 'Min Selection',
                            hintText: 'e.g. 0 or 1',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxSelectedController,
                          decoration: const InputDecoration(
                            labelText: 'Max Selection',
                            hintText: '0 for unlimited',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Options List Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Options (${_options.length})', style: Theme.of(context).textTheme.titleSmall),
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Option'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B4423),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                ..._options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final opt = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2D6CA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Default selector
                        Tooltip(
                          message: 'Default option',
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (_isSingleSelect) {
                                  for (final o in _options) {
                                    o.isDefault = false;
                                  }
                                  opt.isDefault = true;
                                } else {
                                  opt.isDefault = !opt.isDefault;
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                opt.isDefault
                                    ? (_isSingleSelect ? Icons.radio_button_checked : Icons.check_box_rounded)
                                    : (_isSingleSelect ? Icons.radio_button_unchecked : Icons.check_box_outline_blank_rounded),
                                size: 18,
                                color: opt.isDefault ? const Color(0xFF6B4423) : const Color(0xFF8C7564),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Option Name
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: opt.nameController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Option name (e.g. Oat Milk)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Price Delta
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: opt.priceController,
                            style: const TextStyle(fontSize: 12.5),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              prefixText: '+₱ ',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        // Remove button
                        if (_options.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Color(0xFFC62828)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => _removeOption(index),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Assignment to Categories
                Text('Apply to Categories', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                const Text(
                  'Products in these categories will automatically offer this customization.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8C7564)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categories.map((cat) {
                    final isAssigned = _targetCategoryIds.contains(cat.id);
                    return FilterChip(
                      label: Text(cat.name),
                      selected: isAssigned,
                      selectedColor: const Color(0xFFFFE8D2),
                      checkmarkColor: const Color(0xFF6B4423),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isAssigned ? FontWeight.w700 : FontWeight.w500,
                        color: isAssigned ? const Color(0xFF6B4423) : const Color(0xFF4A3B32),
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _targetCategoryIds.add(cat.id);
                          } else {
                            _targetCategoryIds.remove(cat.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Assignment to Specific Products
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Apply to Specific Products (${_targetProductIds.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: const Text(
                    'Optional: Assign to individual products outside or inside categories',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8C7564)),
                  ),
                  children: [
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (ctx, i) {
                          final prod = products[i];
                          final isAssigned = _targetProductIds.contains(prod.id);
                          final viaCat = _targetCategoryIds.contains(prod.categoryId);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(prod.name, style: const TextStyle(fontSize: 12.5)),
                            subtitle: viaCat ? const Text('Included via category', style: TextStyle(fontSize: 10.5, color: Color(0xFF2E7D32))) : null,
                            value: isAssigned || viaCat,
                            onChanged: viaCat
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected ?? false) {
                                        _targetProductIds.add(prod.id);
                                      } else {
                                        _targetProductIds.remove(prod.id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Enabled Toggle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_enabled ? 'Active' : 'Disabled', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            _enabled ? 'Available in POS cashier screens' : 'Hidden from POS cashier screens',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8C7564)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (val) => setState(() => _enabled = val),
                      activeThumbColor: const Color(0xFF6B4423),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6B4423),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _InventoryFormDialog extends StatefulWidget {
  const _InventoryFormDialog({required this.controller, this.initial});

  final CoffeePosController controller;
  final InventoryHealth? initial;

  @override
  State<_InventoryFormDialog> createState() => _InventoryFormDialogState();
}

class _InventoryFormDialogState extends State<_InventoryFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _statusController;
  late final TextEditingController _onHandController;
  late final TextEditingController _thresholdController;
  InventorySeverity? _severity;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.itemName ?? '');
    _statusController = TextEditingController(text: initial?.statusLabel ?? '');
    _onHandController = TextEditingController(
      text: initial == null ? '' : initial.onHand.toString(),
    );
    _thresholdController = TextEditingController(
      text: initial == null ? '' : initial.threshold.toString(),
    );
    _severity = initial?.severity ?? InventorySeverity.good;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    _onHandController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Add inventory item' : 'Edit inventory item',
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _statusController,
                  decoration: const InputDecoration(labelText: 'Status label'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<InventorySeverity>(
                  initialValue: _severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: InventorySeverity.values
                      .map(
                        (severity) => DropdownMenuItem<InventorySeverity>(
                          value: severity,
                          child: Text(_severityLabel(severity)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _severity = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _onHandController,
                  decoration: const InputDecoration(labelText: 'On hand'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _thresholdController,
                  decoration: const InputDecoration(labelText: 'Threshold'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate() || _severity == null) {
              return;
            }
            final onHand = int.parse(_onHandController.text);
            final threshold = int.parse(_thresholdController.text);
            if (widget.initial == null) {
              widget.controller.addInventoryItem(
                itemName: _nameController.text.trim(),
                statusLabel: _statusController.text.trim(),
                onHand: onHand,
                threshold: threshold,
                severity: _severity!,
              );
            } else {
              widget.controller.updateInventoryItem(
                itemId: widget.initial!.id,
                itemName: _nameController.text.trim(),
                statusLabel: _statusController.text.trim(),
                onHand: onHand,
                threshold: threshold,
                severity: _severity!,
              );
            }
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

String _money(num value) => '₱${value.toStringAsFixed(2)}';

CheckoutSummary _orderSummary(OrderRecord order) {
  final cartItems = order.items
      .map(
        (line) => CartItem(
          lineId: line.lineId,
          product: Product(
            id: line.productId,
            name: line.productName,
            categoryId: '',
            price: line.quantity == 0 ? 0 : line.unitPrice,
            description: '',
            badge: '',
            modifierGroupIds: const [],
          ),
          quantity: line.quantity,
          selectedModifiers: const [],
        ),
      )
      .toList(growable: false);
  final discountApplication =
      order.discountApplication.type == DiscountType.none
      ? const DiscountApplication.none()
      : order.discountApplication;
  final discountAmount = discountApplication.type == DiscountType.none
      ? order.discount
      : 0.0;
  final double grossBasis = order.grossAmount > 0
      ? order.grossAmount
      : order.subtotal;
  final double serviceChargeRate = grossBasis > 0
      ? order.serviceCharge / grossBasis
      : 0.0;
  return const CheckoutCalculator().summarize(
    cartItems: cartItems,
    discountAmount: discountAmount,
    taxRate: 0.12,
    serviceChargeRate: serviceChargeRate,
    cashReceived: order.cashReceived,
    discountApplication: discountApplication,
  );
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.category, this.fallback = ''});

  final Category? category;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final value = category;
    if (value == null) {
      return Text(fallback);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(categoryIconData(value), size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(value.name, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

Category? _categoryForProduct(
  CoffeePosController controller,
  String categoryId,
) {
  for (final category in controller.categories) {
    if (category.id == categoryId) {
      return category;
    }
  }
  return null;
}

Color _severityColor(InventorySeverity severity) {
  return switch (severity) {
    InventorySeverity.good => const Color(0xFF3B7D52),
    InventorySeverity.warning => const Color(0xFFC8833A),
    InventorySeverity.critical => const Color(0xFFB5442F),
  };
}

String _severityLabel(InventorySeverity severity) {
  return switch (severity) {
    InventorySeverity.good => 'Good',
    InventorySeverity.warning => 'Warning',
    InventorySeverity.critical => 'Critical',
  };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
