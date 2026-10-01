import 'package:excel/excel.dart' as xl;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../domain/checkout_calculator.dart';
import '../../domain/coffee_pos_models.dart';
import '../../state/coffee_pos_controller.dart';
import '../../utils/category_icon.dart';
import '../../utils/export_writer.dart';

enum _AdminSection { overview, products, inventory, orders }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.controller});

  final CoffeePosController controller;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  _AdminSection _section = _AdminSection.overview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final wide = constraints.maxWidth >= 1100;
        final compactLandscape = isLandscape && constraints.maxWidth >= 700;
        final useLandscapeNav = compactLandscape || wide;

        if (useLandscapeNav) {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _section.index,
                groupAlignment: -1.0,
                onDestinationSelected: (index) {
                  setState(() => _section = _AdminSection.values[index]);
                },
                labelType: compactLandscape
                    ? NavigationRailLabelType.selected
                    : NavigationRailLabelType.all,
                minWidth: compactLandscape ? 68 : 72,
                leading: const SizedBox(height: 6),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard),
                    label: Text('Overview'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.local_offer_outlined),
                    selectedIcon: Icon(Icons.local_offer),
                    label: Text('Products'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: Text('Inventory'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: Text('Orders'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(compactLandscape ? 12 : 20),
                  child: _buildLandscapeSection(context, compactLandscape),
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _AdminHero(controller: controller)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverGrid(
              delegate: SliverChildListDelegate([
                _MetricCard(
                  label: 'Sales today',
                  value: _money(controller.todaySales),
                  icon: Icons.payments_outlined,
                ),
                _MetricCard(
                  label: 'Open shifts',
                  value: '${controller.activeShifts.length}',
                  icon: Icons.badge_outlined,
                ),
                _MetricCard(
                  label: 'Low stock items',
                  value:
                      '${controller.inventoryHealth.where((item) => item.severity != InventorySeverity.good).length}',
                  icon: Icons.inventory_2_outlined,
                ),
                _MetricCard(
                  label: 'Recent orders',
                  value: '${controller.recentOrders.length}',
                  icon: Icons.receipt_long_outlined,
                ),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 132,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: (wide || compactLandscape)
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _SalesOverview(
                            controller: controller,
                            compactLandscape: compactLandscape,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _InventoryPanel(
                            controller: controller,
                            compactLandscape: compactLandscape,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _SalesOverview(
                          controller: controller,
                          compactLandscape: compactLandscape,
                        ),
                        const SizedBox(height: 16),
                        _InventoryPanel(
                          controller: controller,
                          compactLandscape: compactLandscape,
                        ),
                      ],
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: (wide || compactLandscape)
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ProductCrudPanel(
                            controller: controller,
                            compactLandscape: compactLandscape,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _InventoryCrudPanel(
                            controller: controller,
                            compactLandscape: compactLandscape,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _ProductCrudPanel(
                          controller: controller,
                          compactLandscape: compactLandscape,
                        ),
                        const SizedBox(height: 16),
                        _InventoryCrudPanel(
                          controller: controller,
                          compactLandscape: compactLandscape,
                        ),
                      ],
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: _RecentOrdersPanel(
                controller: controller,
                compactLandscape: compactLandscape,
              ),
            ),
          ],
        );
      },
    );
  }

  CoffeePosController get controller => widget.controller;

  Widget _buildLandscapeSection(BuildContext context, bool compactLandscape) {
    return switch (_section) {
      _AdminSection.overview => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _AdminHero(
              controller: controller,
              compactLandscape: compactLandscape,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: compactLandscape ? 12 : 16),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final crossAxisCount = width >= 1180
                  ? 4
                  : width >= 920
                  ? 3
                  : 2;
              return SliverGrid(
                delegate: SliverChildListDelegate([
                  _MetricCard(
                    label: 'Sales today',
                    value: _money(controller.todaySales),
                    icon: Icons.payments_outlined,
                    compactLandscape: compactLandscape,
                  ),
                  _MetricCard(
                    label: 'Open shifts',
                    value: '${controller.activeShifts.length}',
                    icon: Icons.badge_outlined,
                    compactLandscape: compactLandscape,
                  ),
                  _MetricCard(
                    label: 'Low stock items',
                    value:
                        '${controller.inventoryHealth.where((item) => item.severity != InventorySeverity.good).length}',
                    icon: Icons.inventory_2_outlined,
                    compactLandscape: compactLandscape,
                  ),
                  _MetricCard(
                    label: 'Recent orders',
                    value: '${controller.recentOrders.length}',
                    icon: Icons.receipt_long_outlined,
                    compactLandscape: compactLandscape,
                  ),
                ]),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: compactLandscape ? 112 : 132,
                  mainAxisSpacing: compactLandscape ? 10 : 14,
                  crossAxisSpacing: compactLandscape ? 10 : 14,
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: compactLandscape ? 12 : 16),
          ),
          SliverToBoxAdapter(
            child: _SalesOverview(
              controller: controller,
              compactLandscape: compactLandscape,
            ),
          ),
        ],
      ),
      _AdminSection.products => _SinglePanelScroll(
        child: _ProductCrudPanel(
          controller: controller,
          compactLandscape: compactLandscape,
        ),
      ),
      _AdminSection.inventory => _SinglePanelScroll(
        child: _InventoryCrudPanel(
          controller: controller,
          compactLandscape: compactLandscape,
        ),
      ),
      _AdminSection.orders => _SinglePanelScroll(
        child: _RecentOrdersPanel(
          controller: controller,
          compactLandscape: compactLandscape,
        ),
      ),
    };
  }
}

class _SinglePanelScroll extends StatelessWidget {
  const _SinglePanelScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // AnimatedSwitcher gives its children loose constraints; expanding here
    // prevents short admin panels from being centered in the available space.
    return SizedBox.expand(child: SingleChildScrollView(child: child));
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.controller, this.compactLandscape = false});

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compactLandscape ? 14 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6B4423), const Color(0xFF9C6538)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 720;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Haven & Co. back office',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compactLandscape ? 4 : 8),
              Text(
                compactLandscape
                    ? 'Manage menu, stock, and orders from one control surface.'
                    : 'Manage menu items, inventory, and order history from one control surface.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonal(
                onPressed: () => _exportToFile(context, controller),
                style: FilledButton.styleFrom(backgroundColor: Colors.white),
                child: const Text('Export file'),
              ),
              OutlinedButton(
                onPressed: () => _importFromFile(context, controller),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                child: const Text('Import file'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.compactLandscape = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compactLandscape ? 12 : 16),
        child: Row(
          children: [
            Container(
              width: compactLandscape ? 44 : 52,
              height: compactLandscape ? 44 : 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8D2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF6B4423)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  SizedBox(height: compactLandscape ? 4 : 6),
                  Text(
                    value,
                    style: compactLandscape
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesOverview extends StatelessWidget {
  const _SalesOverview({
    required this.controller,
    this.compactLandscape = false,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    final values = <double>[42, 68, 58, 83, 90, 74, 95];
    final labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final chartHeight = compactLandscape ? 150.0 : 220.0;
    final barHeight = chartHeight - 40;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compactLandscape ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Sales trend',
              subtitle:
                  'A simple native chart keeps the prototype dependency-light.',
              compactLandscape: compactLandscape,
            ),
            SizedBox(height: compactLandscape ? 12 : 18),
            SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compactLandscape ? 3 : 6,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: barHeight * (values[index] / 100),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.brown.shade300,
                                  Colors.orange.shade300,
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                          SizedBox(height: compactLandscape ? 6 : 10),
                          Text(labels[index]),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.controller,
    this.compactLandscape = false,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compactLandscape ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Inventory health',
              subtitle: 'Critical and low stock items need attention.',
              compactLandscape: compactLandscape,
            ),
            SizedBox(height: compactLandscape ? 10 : 14),
            ...controller.inventoryHealth.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: compactLandscape ? 8 : 12),
                child: _InventoryTile(item: item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCrudPanel extends StatelessWidget {
  const _ProductCrudPanel({
    required this.controller,
    this.compactLandscape = false,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compactLandscape ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeading(
              title: 'Products',
              subtitle: compactLandscape
                  ? 'Create, update, and delete menu items.'
                  : 'Create, update, and delete menu items.',
              compactLandscape: compactLandscape,
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openProductDialog(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('Add product'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportProductsExcel(context, controller),
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Export Excel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _importProductsExcel(context, controller),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import Excel'),
                  ),
                ],
              ),
            ),
            SizedBox(height: compactLandscape ? 10 : 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: compactLandscape ? 44 : 56,
                dataRowMaxHeight: compactLandscape ? 52 : 64,
                columnSpacing: compactLandscape ? 14 : 24,
                horizontalMargin: compactLandscape ? 12 : 24,
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Badge')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: controller.products
                    .map(
                      (product) => DataRow(
                        cells: [
                          DataCell(Text(product.name)),
                          DataCell(
                            _CategoryLabel(
                              category: _categoryForProduct(
                                controller,
                                product.categoryId,
                              ),
                              fallback: product.categoryId,
                            ),
                          ),
                          DataCell(Text(_money(product.price))),
                          DataCell(Text(product.badge)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionButton(
                                  label: 'Edit',
                                  icon: Icons.edit_outlined,
                                  compactLandscape: compactLandscape,
                                  onPressed: () => _openProductDialog(
                                    context,
                                    controller,
                                    initial: product,
                                  ),
                                ),
                                _ActionButton(
                                  label: 'Delete',
                                  icon: Icons.delete_outline,
                                  compactLandscape: compactLandscape,
                                  destructive: true,
                                  onPressed: () => _confirmDelete(
                                    context,
                                    title: 'Delete ${product.name}?',
                                    message:
                                        'This removes the product from the menu and cart.',
                                    onConfirm: () =>
                                        controller.deleteProduct(product.id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryCrudPanel extends StatelessWidget {
  const _InventoryCrudPanel({
    required this.controller,
    this.compactLandscape = false,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compactLandscape ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeading(
              title: 'Inventory',
              subtitle: 'Track stock levels, thresholds, and severity.',
              compactLandscape: compactLandscape,
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openInventoryDialog(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportInventoryExcel(context, controller),
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Export Excel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _importInventoryExcel(context, controller),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import Excel'),
                  ),
                ],
              ),
            ),
            SizedBox(height: compactLandscape ? 10 : 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: compactLandscape ? 44 : 56,
                dataRowMaxHeight: compactLandscape ? 52 : 64,
                columnSpacing: compactLandscape ? 14 : 24,
                horizontalMargin: compactLandscape ? 12 : 24,
                columns: const [
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('On hand')),
                  DataColumn(label: Text('Threshold')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: controller.inventoryHealth
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.itemName)),
                          DataCell(
                            Chip(
                              label: Text(item.statusLabel),
                              backgroundColor: _severityColor(
                                item.severity,
                              ).withValues(alpha: 0.14),
                            ),
                          ),
                          DataCell(Text('${item.onHand}')),
                          DataCell(Text('${item.threshold}')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionButton(
                                  label: 'Edit',
                                  icon: Icons.edit_outlined,
                                  compactLandscape: compactLandscape,
                                  onPressed: () => _openInventoryDialog(
                                    context,
                                    controller,
                                    initial: item,
                                  ),
                                ),
                                _ActionButton(
                                  label: 'Delete',
                                  icon: Icons.delete_outline,
                                  compactLandscape: compactLandscape,
                                  destructive: true,
                                  onPressed: () => _confirmDelete(
                                    context,
                                    title: 'Delete ${item.itemName}?',
                                    message:
                                        'This removes the inventory row from the dashboard.',
                                    onConfirm: () =>
                                        controller.deleteInventoryItem(item.id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.item});

  final InventoryHealth item;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(item.severity);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(item.statusLabel),
              ],
            ),
          ),
          Text(
            '${item.onHand}/${item.threshold}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersPanel extends StatelessWidget {
  const _RecentOrdersPanel({
    required this.controller,
    this.compactLandscape = false,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compactLandscape ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Recent orders',
              subtitle:
                  'Each receipt stores a snapshot so historical tickets do not drift.',
              compactLandscape: compactLandscape,
            ),
            SizedBox(height: compactLandscape ? 10 : 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: compactLandscape ? 40 : 52,
                dataRowMaxHeight: compactLandscape ? 48 : 60,
                columnSpacing: compactLandscape ? 14 : 24,
                horizontalMargin: compactLandscape ? 12 : 24,
                columns: const [
                  DataColumn(label: Text('Order')),
                  DataColumn(label: Text('Cashier')),
                  DataColumn(label: Text('Payment')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Status')),
                ],
                rows: controller.recentOrders
                    .map(
                      (order) => DataRow(
                        cells: [
                          DataCell(Text(order.id)),
                          DataCell(Text(order.cashierName)),
                          DataCell(Text(order.paymentType.name.toUpperCase())),
                          DataCell(Text(_money(_orderSummary(order).total))),
                          DataCell(Text(order.status.name.toUpperCase())),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.compactLandscape = false,
  });

  final String title;
  final String subtitle;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: compactLandscape ? 2 : 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.compactLandscape = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compactLandscape;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFB5442F)
        : const Color(0xFF6B4423);
    final fill = destructive
        ? const Color(0xFFFDE8E3)
        : const Color(0xFFFFE8D2);
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: compactLandscape ? 30 : 34),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: compactLandscape ? 15 : 16),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: fill,
          padding: EdgeInsets.symmetric(horizontal: compactLandscape ? 8 : 10),
          textStyle: TextStyle(
            fontSize: compactLandscape ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
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

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.compactLandscape = false,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: compactLandscape ? 2 : 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        trailing,
      ],
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
        const SnackBar(content: Text('Admin data imported from file')),
      );
    }
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${error.message}')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed: invalid JSON file.')),
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
      title: const Text('Replace admin data?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to import "$fileName". This will replace the current admin data.',
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
            const Text(
              'Use this only if you want to overwrite the live store state with the backup file.',
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
          child: const Text('Replace data'),
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
        content: Text('Products exported to ${_savedFileLabel(savedTo)}'),
      ),
    );
  }
}

Future<void> _importProductsExcel(
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
    final products = _parseProductsFromWorkbook(workbook, controller);
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
    controller.replaceProducts(products);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${products.length} products from Excel'),
        ),
      );
    }
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${error.message}')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed: invalid Excel file.')),
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
        content: Text('Inventory exported to ${_savedFileLabel(savedTo)}'),
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
          content: Text('Imported ${inventoryItems.length} inventory rows'),
        ),
      );
    }
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${error.message}')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed: invalid Excel file.')),
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
      title: const Text('Replace inventory?'),
      content: Text(
        'Import "$fileName" and replace the current inventory list with $itemCount rows?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Replace inventory'),
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
      title: const Text('Replace products?'),
      content: Text(
        'Import "$fileName" and replace the current product list with $productCount rows?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Replace products'),
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
      xl.TextCellValue(product.modifierGroupIds.join(', ')),
    ]);
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

List<Product> _parseProductsFromWorkbook(
  xl.Excel workbook,
  CoffeePosController controller,
) {
  final sheet =
      workbook.tables['Products'] ??
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
      'The Excel file must include a header row and at least one product row.',
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

  final nameIndex = findHeader(const ['name', 'product name']);
  final priceIndex = findHeader(const ['price', 'product price']);
  if (nameIndex == null || priceIndex == null) {
    throw const FormatException('Missing required columns: Name and Price.');
  }

  final idIndex = findHeader(const ['product id', 'id']);
  final categoryIdIndex = findHeader(const ['category id', 'categoryid']);
  final categoryNameIndex = findHeader(const ['category name', 'category']);
  final categoryIconIndex = findHeader(const ['category icon', 'icon']);
  final descriptionIndex = findHeader(const ['description']);
  final badgeIndex = findHeader(const ['badge']);
  final modifierGroupsIndex = findHeader(const [
    'modifier group ids',
    'modifier group',
    'modifier groups',
  ]);

  final existingIds = <String>{};
  final products = <Product>[];
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    final name = _excelCellTextAt(row, nameIndex);
    if (name.isEmpty) {
      continue;
    }
    final price = _excelCellDoubleAt(row, priceIndex);
    if (price <= 0) {
      throw FormatException('Row ${rowIndex + 1} has an invalid price.');
    }

    final categoryId = _resolveImportedCategoryId(
      controller,
      categoryId: categoryIdIndex == null
          ? ''
          : _excelCellTextAt(row, categoryIdIndex),
      categoryName: categoryNameIndex == null
          ? ''
          : _excelCellTextAt(row, categoryNameIndex),
      categoryIcon: categoryIconIndex == null
          ? ''
          : _excelCellTextAt(row, categoryIconIndex),
    );

    final rawId = idIndex == null ? '' : _excelCellTextAt(row, idIndex);
    final baseId = rawId.isEmpty
        ? _slugifyProductName(name)
        : _slugifyProductName(rawId);
    final productId = _uniqueProductId(baseId, existingIds, rowIndex);
    existingIds.add(productId);

    products.add(
      Product(
        id: productId,
        name: name,
        categoryId: categoryId,
        price: price,
        description: descriptionIndex == null
            ? ''
            : _excelCellTextAt(row, descriptionIndex),
        badge: badgeIndex == null ? '' : _excelCellTextAt(row, badgeIndex),
        modifierGroupIds: _parseModifierGroupIds(
          modifierGroupsIndex == null
              ? ''
              : _excelCellTextAt(row, modifierGroupsIndex),
        ),
      ),
    );
  }

  if (products.isEmpty) {
    throw const FormatException(
      'No product rows were found in the Excel file.',
    );
  }
  return products;
}

String _resolveImportedCategoryId(
  CoffeePosController controller, {
  required String categoryId,
  required String categoryName,
  required String categoryIcon,
}) {
  final normalizedId = categoryId.trim();
  if (normalizedId.isNotEmpty) {
    for (final category in controller.categories) {
      if (category.id.toLowerCase() == normalizedId.toLowerCase()) {
        return category.id;
      }
    }
  }

  final normalizedName = categoryName.trim();
  if (normalizedName.isNotEmpty) {
    for (final category in controller.categories) {
      if (category.name.toLowerCase() == normalizedName.toLowerCase()) {
        return category.id;
      }
    }
  }

  final resolvedId = normalizedId.isNotEmpty
      ? _slugifyProductName(normalizedId)
      : normalizedName.isNotEmpty
      ? _slugifyProductName(normalizedName)
      : '';
  if (resolvedId.isNotEmpty) {
    controller.ensureImportedCategory(
      id: resolvedId,
      name: normalizedName.isEmpty ? normalizedId : normalizedName,
      icon: categoryIcon.trim(),
    );
    return resolvedId;
  }

  if (controller.categories.isNotEmpty) {
    return controller.categories.first.id;
  }
  return normalizedId;
}

List<String> _parseModifierGroupIds(String value) {
  if (value.trim().isEmpty) {
    return const <String>[];
  }
  return value
      .split(RegExp(r'[,;\n]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

String _slugifyProductName(String value) {
  final normalized = value.trim().toLowerCase();
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return slug.replaceAll(RegExp(r'^-+|-+$'), '');
}

String _uniqueProductId(String baseId, Set<String> existingIds, int rowIndex) {
  var candidate = baseId.isEmpty ? 'product-$rowIndex' : baseId;
  var counter = 2;
  while (existingIds.contains(candidate)) {
    candidate = '${baseId.isEmpty ? 'product-$rowIndex' : baseId}-$counter';
    counter++;
  }
  return candidate;
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
                    (group) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(group.name),
                      subtitle: Text(
                        group.options.isEmpty
                            ? 'No options'
                            : group.options
                                  .map((option) => option.name)
                                  .join(', '),
                      ),
                      value: _modifierGroupIds.contains(group.id),
                      onChanged: (selected) {
                        setState(() {
                          if (selected ?? false) {
                            _modifierGroupIds.add(group.id);
                          } else {
                            _modifierGroupIds.remove(group.id);
                          }
                        });
                      },
                    ),
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
