import 'discount_settings_dialog.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../domain/checkout_calculator.dart';
import '../../domain/coffee_pos_models.dart';
import '../../state/coffee_pos_controller.dart';
import '../../state/demo_session_manager.dart';
import '../../utils/receipt_printer.dart' as receipt_printer;
import 'admin_dashboard.dart';
import 'cashier_dashboard.dart';
import 'order_status_dialog.dart';
import 'complete_all_orders_button.dart';
import 'auto_hiding_snack_bar.dart';
import 'reports/pos_reports_dashboard.dart';

enum _ShellSection {
  cashier,
  inProgress,
  orders,
  customers,
  admin,
  reports,
  settings,
}

class CoffeePosShell extends StatefulWidget {
  const CoffeePosShell({super.key, required this.controller});

  final CoffeePosController controller;

  @override
  State<CoffeePosShell> createState() => _CoffeePosShellState();
}

class _CoffeePosShellState extends State<CoffeePosShell> {
  _ShellSection _section = _ShellSection.cashier;

  CoffeePosController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final isWide =
            constraints.maxWidth >= 980 ||
            (isLandscape && constraints.maxWidth >= 720);
        final compactLandscape =
            isLandscape &&
            constraints.maxWidth >= 700 &&
            constraints.maxWidth < 1200;

        return Scaffold(
          appBar: isWide
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/lunan_logo.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const Text('LUNAN'),
                    ],
                  ),
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
          drawer: isWide
              ? null
              : _ShellDrawer(
                  controller: controller,
                  selectedSection: _section,
                  onSelect: (section) {
                    setState(() => _section = section);
                    Navigator.of(context).maybePop();
                  },
                  onLogout: _showLogoutMessage,
                ),
          body: SafeArea(
            child: Column(
              children: [
                if (controller.isDemo) _buildDemoBanner(context),
                Expanded(
                  child: isWide
                      ? Row(
                          children: [
                            _PermanentSidebar(
                              controller: controller,
                              selectedSection: _section,
                              onSelect: (section) =>
                                  setState(() => _section = section),
                              onLogout: _showLogoutMessage,
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(compactLandscape ? 12 : 18),
                                child: _SectionHost(
                                  section: _section,
                                  controller: controller,
                                  compactLandscape: compactLandscape,
                                  onNavigate: (section) =>
                                      setState(() => _section = section),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: EdgeInsets.all(
                            _section == _ShellSection.cashier ? 8 : 16,
                          ),
                          child: _SectionHost(
                            section: _section,
                            controller: controller,
                            compactLandscape: compactLandscape,
                            onNavigate: (section) =>
                                setState(() => _section = section),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDemoBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        border: Border(
          bottom: BorderSide(color: const Color(0xFFFFEEBA).withValues(alpha: 0.8)),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF856404),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'DEMO MODE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Demo store environment. Changes do not affect your live business records.',
                style: TextStyle(
                  color: Color(0xFF856404),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('reset_demo_data_header_button'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset Demo Data?'),
                      content: const Text(
                        'This will restore all demo menu items, customization options, stock counts, and sample orders to their original state.',
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
                        const SnackBar(
                          content: Text('Demo store data has been reset to original sample records.'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset Demo Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF856404),
                  side: const BorderSide(color: Color(0xFF856404)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('exit_demo_mode_button'),
                onPressed: _showLogoutMessage,
                icon: const Icon(Icons.exit_to_app, size: 16),
                label: const Text('Exit Demo'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF856404),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutMessage() async {
    await controller.flushPersistence();
    if (controller.isDemo) {
      await DemoSessionManager.instance.exitDemoMode();
      return;
    }
    await FirebaseAuth.instance.signOut();
  }
}

class _SectionHost extends StatelessWidget {
  const _SectionHost({
    required this.section,
    required this.controller,
    required this.compactLandscape,
    required this.onNavigate,
  });

  final _ShellSection section;
  final CoffeePosController controller;
  final bool compactLandscape;
  final ValueChanged<_ShellSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (controller.role != Role.admin &&
        !{
          _ShellSection.cashier,
          _ShellSection.inProgress,
          _ShellSection.orders,
        }.contains(section)) {
      return CashierDashboard(
        key: const ValueKey('cashier'),
        controller: controller,
      );
    }
    return SizedBox.expand(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: switch (section) {
          _ShellSection.cashier => CashierDashboard(
            key: const ValueKey('cashier'),
            controller: controller,
          ),
          _ShellSection.inProgress => _InProgressOrdersPage(
            key: const ValueKey('in-progress'),
            controller: controller,
            compactLandscape: compactLandscape,
            onContinue: (order) {
              controller.resumeOrder(order);
              onNavigate(_ShellSection.cashier);
            },
            onView: (order) => _showOrderDetails(context, order),
            onComplete: (order) => _changeOrderStatus(
              context,
              controller,
              order,
              OrderAction.complete,
            ),
          ),
          _ShellSection.orders => _OrderHistoryPage(
            key: const ValueKey('orders'),
            controller: controller,
            compactLandscape: compactLandscape,
          ),
          _ShellSection.customers => _CustomersPage(
            key: const ValueKey('customers'),
            controller: controller,
            compactLandscape: compactLandscape,
          ),
          _ShellSection.admin => AdminDashboard(
            key: const ValueKey('admin'),
            controller: controller,
          ),
          _ShellSection.reports => PosReportsDashboard(
            key: const ValueKey('reports'),
            controller: controller,
            compactLandscape: compactLandscape,
          ),
          _ShellSection.settings => _SettingsPage(
            key: const ValueKey('settings'),
            controller: controller,
          ),
        },
      ),
    );
  }
}

class _PermanentSidebar extends StatelessWidget {
  const _PermanentSidebar({
    required this.controller,
    required this.selectedSection,
    required this.onSelect,
    required this.onLogout,
  });

  final CoffeePosController controller;
  final _ShellSection selectedSection;
  final ValueChanged<_ShellSection> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final items = _visibleNavigationItems(<_SidebarItemData>[
      const _SidebarItemData(
        section: _ShellSection.cashier,
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
        label: 'Cashier',
      ),
      _SidebarItemData(
        section: _ShellSection.inProgress,
        icon: Icons.hourglass_top_outlined,
        selectedIcon: Icons.hourglass_top,
        label: 'In Progress',
        badge: controller.activeOrders.length,
      ),
      const _SidebarItemData(
        section: _ShellSection.orders,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: 'Orders',
      ),
      // const _SidebarItemData(
      //   section: _ShellSection.customers,
      //   icon: Icons.person_outline,
      //   selectedIcon: Icons.person,
      //   label: 'Customers',
      // ),
      const _SidebarItemData(
        section: _ShellSection.admin,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Admin',
      ),
      const _SidebarItemData(
        section: _ShellSection.reports,
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        label: 'Reports',
      ),
      const _SidebarItemData(
        section: _ShellSection.settings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
      ),
    ], controller.role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxHeight < 720;
        final veryDense = constraints.maxHeight < 620;
        final width = veryDense
            ? 102.0
            : dense
            ? 104.0
            : 106.0;
        final logoSize = veryDense
            ? 42.0
            : dense
            ? 46.0
            : 48.0;
        final brandFont = veryDense
            ? 10.25
            : dense
            ? 11.0
            : 11.5;
        final topPadding = veryDense
            ? const EdgeInsets.fromLTRB(8, 8, 8, 2)
            : dense
            ? const EdgeInsets.fromLTRB(9, 10, 9, 3)
            : const EdgeInsets.fromLTRB(10, 12, 10, 4);
        final sidePadding = veryDense ? 4.0 : 5.0;
        final tileGap = veryDense ? 2.0 : 3.0;

        return Container(
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            border: Border(right: BorderSide(color: const Color(0x1A7A5A4A))),
          ),
          child: Column(
            children: [
              Padding(
                padding: topPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(
                          veryDense ? 14 : 15,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 10,
                            color: Color(0x1A8A4D34),
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/lunan_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: veryDense ? 4 : 6),
                    Text(
                      'LUNAN',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: brandFont,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2F251E),
                      ),
                    ),
                    if (!veryDense) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'May lugar ka rito.',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B4423),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  child: Column(
                    children: [
                      for (final item in items)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: tileGap),
                            child: _SidebarNavTile(
                              label: item.label,
                              icon: item.icon,
                              selectedIcon: item.selectedIcon,
                              selected: selectedSection == item.section,
                              badge: item.badge,
                              compact: veryDense || dense,
                              onTap: () => onSelect(item.section),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  sidePadding + 2,
                  4,
                  sidePadding + 2,
                  veryDense ? 8 : 12,
                ),
                child: _SidebarNavTile(
                  label: controller.isDemo ? 'Exit Demo' : 'Logout',
                  icon: controller.isDemo
                      ? Icons.exit_to_app_outlined
                      : Icons.logout_outlined,
                  selectedIcon: controller.isDemo
                      ? Icons.exit_to_app
                      : Icons.logout,
                  selected: false,
                  isAction: true,
                  compact: veryDense || dense,
                  onTap: onLogout,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({
    required this.controller,
    required this.selectedSection,
    required this.onSelect,
    required this.onLogout,
  });

  final CoffeePosController controller;
  final _ShellSection selectedSection;
  final ValueChanged<_ShellSection> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF7D9C6), Color(0xFFFFF3E8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/lunan_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LUNAN',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2F251E),
                            ),
                          ),
                          Text(
                            'May lugar ka rito.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B4423),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final item in _drawerItems(controller))
              ListTile(
                leading: Icon(
                  selectedSection == item.section
                      ? item.selectedIcon
                      : item.icon,
                ),
                title: Text(item.label),
                trailing: item.badge == null || item.badge == 0
                    ? null
                    : _Badge(count: item.badge!),
                selected: selectedSection == item.section,
                onTap: () => onSelect(item.section),
              ),
            const Divider(height: 32),
            ListTile(
              leading: Icon(
                controller.isDemo
                    ? Icons.exit_to_app_outlined
                    : Icons.logout_outlined,
              ),
              title: Text(controller.isDemo ? 'Exit Demo' : 'Logout'),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

List<_SidebarItemData> _drawerItems(CoffeePosController controller) {
  return _visibleNavigationItems([
    const _SidebarItemData(
      section: _ShellSection.cashier,
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: 'Cashier',
    ),
    _SidebarItemData(
      section: _ShellSection.inProgress,
      icon: Icons.hourglass_top_outlined,
      selectedIcon: Icons.hourglass_top,
      label: 'In Progress',
      badge: controller.activeOrders.length,
    ),
    const _SidebarItemData(
      section: _ShellSection.orders,
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Orders',
    ),
    // const _SidebarItemData(
    //   section: _ShellSection.customers,
    //   icon: Icons.person_outline,
    //   selectedIcon: Icons.person,
    //   label: 'Customers',
    // ),
    const _SidebarItemData(
      section: _ShellSection.admin,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Admin',
    ),
    const _SidebarItemData(
      section: _ShellSection.reports,
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Reports',
    ),
    const _SidebarItemData(
      section: _ShellSection.settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ], controller.role);
}

List<_SidebarItemData> _visibleNavigationItems(
  List<_SidebarItemData> items,
  Role role,
) {
  if (role == Role.admin) {
    return items;
  }
  return items
      .where(
        (item) =>
            item.section == _ShellSection.cashier ||
            item.section == _ShellSection.inProgress ||
            item.section == _ShellSection.orders,
      )
      .toList(growable: false);
}

class _SidebarNavTile extends StatefulWidget {
  const _SidebarNavTile({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badge,
    this.isAction = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;
  final bool isAction;
  final bool compact;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;
    final selected = widget.selected;
    final dense = widget.compact;
    final background = selected
        ? const Color(0xFFFFBF8F)
        : active
        ? const Color(0xFFF9E7DA)
        : Colors.transparent;
    final borderColor = selected ? const Color(0xFFDF8750) : Colors.transparent;
    final iconColor = selected
        ? const Color(0xFF7A4330)
        : const Color(0xFF6C5548);
    final labelColor = selected
        ? const Color(0xFF3E2B23)
        : const Color(0xFF5E4C42);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isAction
                  ? 7
                  : dense
                  ? 4
                  : 5,
              vertical: widget.isAction
                  ? 8
                  : dense
                  ? 5
                  : 7,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(dense ? 21 : 23),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.8 : 1.0,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        blurRadius: 18,
                        color: Color(0x2BD26A31),
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? widget.selectedIcon : widget.icon,
                      color: iconColor,
                      size: widget.isAction
                          ? (dense ? 24 : 26)
                          : dense
                          ? 22
                          : 25,
                    ),
                    if (widget.badge != null && widget.badge! > 0) ...[
                      const SizedBox(width: 4),
                      _Badge(count: widget.badge!),
                    ],
                  ],
                ),
                SizedBox(height: dense ? 3 : 4),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.isAction
                        ? (dense ? 8.75 : 9.25)
                        : dense
                        ? 8.25
                        : 8.75,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF14F4F),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            blurRadius: 7,
            color: Color(0x26F14F4F),
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SidebarItemData {
  const _SidebarItemData({
    required this.section,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
  });

  final _ShellSection section;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? badge;
}

class _InProgressOrdersPage extends StatelessWidget {
  const _InProgressOrdersPage({
    super.key,
    required this.controller,
    required this.compactLandscape,
    required this.onContinue,
    required this.onView,
    required this.onComplete,
  });

  final CoffeePosController controller;
  final bool compactLandscape;
  final ValueChanged<OrderQueueRecord> onContinue;
  final ValueChanged<OrderQueueRecord> onView;
  final Future<void> Function(OrderQueueRecord) onComplete;

  @override
  Widget build(BuildContext context) {
    final activeOrders = controller.activeOrders;
    final completable = activeOrders
        .where(
          (order) =>
              controller.transactionForQueue(order)?.status == OrderStatus.paid,
        )
        .toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PageHeader(
          title: 'In Progress Orders',
          subtitle: 'Pending, preparing, held, and awaiting payment tickets.',
          compactLandscape: compactLandscape,
          trailing: _CountPill(count: activeOrders.length, label: 'active'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: CompleteAllOrdersButton(
            orders: completable,
            unpaidCount: activeOrders.length - completable.length,
            onComplete: controller.completeOrder,
          ),
        ),
        const SizedBox(height: 16),
        if (activeOrders.isEmpty)
          const _EmptyState(
            icon: Icons.hourglass_empty,
            title: 'No active orders',
            subtitle: 'Current in-progress tickets will appear here.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isVeryNarrow = width < 360;
              final isNarrow = width < 460;

              final int columns;
              final double childAspectRatio;

              if (width < 650) {
                columns = 2;
                childAspectRatio = isVeryNarrow
                    ? 0.90
                    : (isNarrow ? 0.98 : 1.15);
              } else if (width < 1000) {
                columns = 3;
                childAspectRatio = 1.45;
              } else if (width < 1400) {
                columns = 4;
                childAspectRatio = 1.65;
              } else {
                columns = 5;
                childAspectRatio = 1.75;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeOrders.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: isNarrow ? 8 : 12,
                  mainAxisSpacing: isNarrow ? 8 : 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final order = activeOrders[index];
                  return _OrderTicketCard(
                    title: 'Order #${order.displayOrderNumber}',
                    subtitle: '${order.orderType}  •  ${order.customerName}',
                    status: _queueStatusText(order.status),
                    time: _formatTime(context, order.createdAt),
                    itemCount: order.items.fold<int>(
                      0,
                      (sum, item) => sum + item.quantity,
                    ),
                    total:
                        controller.transactionForQueue(order)?.total ??
                        order.subtotal,
                    compactLandscape: compactLandscape,
                    primaryActionLabel: order.status == OrderQueueStatus.held
                        ? 'Continue Order'
                        : 'View',
                    onPrimaryAction: order.status == OrderQueueStatus.held
                        ? () => onContinue(order)
                        : () => onView(order),
                    onCancel: () => _changeOrderStatus(
                      context,
                      controller,
                      order,
                      OrderAction.cancel,
                    ),
                    onRefund:
                        controller.transactionForQueue(order)?.status ==
                            OrderStatus.paid
                        ? () => _changeOrderStatus(
                            context,
                            controller,
                            order,
                            OrderAction.refund,
                          )
                        : null,
                    secondaryActionLabel: 'Complete',
                    onSecondaryAction: () => onComplete(order),
                    onPrintTicket: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final result =
                          await controller.printPreparationTicket(order);
                      if (context.mounted) {
                        if (result.isSuccess) {
                          showAutoHidingSnackBar(
                            messenger: messenger,
                            content: Text(
                              'Preparation ticket printed for ${order.id}',
                            ),
                            duration: const Duration(seconds: 5),
                          );
                        } else {
                          showAutoHidingSnackBar(
                            messenger: messenger,
                            content: const Text(
                              'Unable to print preparation ticket. Please check the printer connection.',
                            ),
                            duration: const Duration(seconds: 5),
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _OrderHistoryPage extends StatefulWidget {
  const _OrderHistoryPage({
    super.key,
    required this.controller,
    required this.compactLandscape,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  State<_OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<_OrderHistoryPage> {
  _OrderHistoryFilter _filter = _OrderHistoryFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final orders = widget.controller.recentOrders
        .where((order) {
          final matchesQuery =
              _query.trim().isEmpty ||
              order.id.toLowerCase().contains(_query.toLowerCase()) ||
              order.orderNumber.toLowerCase().contains(_query.toLowerCase()) ||
              order.cashierName.toLowerCase().contains(_query.toLowerCase());
          final matchesFilter = switch (_filter) {
            _OrderHistoryFilter.all => true,
            _OrderHistoryFilter.today => _sameDay(
              order.createdAt,
              DateTime.now(),
            ),
            _OrderHistoryFilter.completed =>
              order.status == OrderStatus.paid &&
                  !widget.controller.activeOrders.any(
                    (queue) =>
                        widget.controller.transactionForQueue(queue)?.id ==
                        order.id,
                  ),
            _OrderHistoryFilter.cancelled => order.status == OrderStatus.voided,
            _OrderHistoryFilter.refunded =>
              order.status == OrderStatus.refunded,
            _ => true,
          };
          return matchesQuery && matchesFilter;
        })
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PageHeader(
          title: 'Orders / Order History',
          subtitle: 'Search receipts and review completed orders.',
          compactLandscape: widget.compactLandscape,
          trailing: _CountPill(count: orders.length, label: 'orders'),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by order number or cashier',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _OrderHistoryFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (orders.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long,
            title: 'No matching orders',
            subtitle: 'Try another filter or search term.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isVeryNarrow = width < 360;
              final isNarrow = width < 460;

              final int columns;
              final double childAspectRatio;

              if (width < 650) {
                columns = 2;
                childAspectRatio = isVeryNarrow
                    ? 0.88
                    : (isNarrow ? 0.96 : 1.15);
              } else if (width < 1000) {
                columns = 3;
                childAspectRatio = 1.40;
              } else if (width < 1400) {
                columns = 4;
                childAspectRatio = 1.55;
              } else {
                columns = 5;
                childAspectRatio = 1.65;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: isNarrow ? 8 : 12,
                  mainAxisSpacing: isNarrow ? 8 : 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _HistoryOrderCard(
                    controller: widget.controller,
                    order: order,
                    compactLandscape: widget.compactLandscape,
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _CustomersPage extends StatelessWidget {
  const _CustomersPage({
    super.key,
    required this.controller,
    required this.compactLandscape,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    final customers = controller.customers;
    final selectedCustomerId = controller.selectedCustomerId;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PageHeader(
          title: 'Customers',
          subtitle: 'Select a customer to attach them to the current order.',
          compactLandscape: compactLandscape,
          trailing: _CountPill(count: customers.length, label: 'profiles'),
        ),
        const SizedBox(height: 12),
        if (controller.selectedCustomer != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SelectedCustomerBanner(
              customer: controller.selectedCustomer!,
              onClear: () => controller.selectCustomer(null),
            ),
          ),
        if (customers.isEmpty)
          const _EmptyState(
            icon: Icons.person_outline,
            title: 'No customer records yet',
            subtitle: 'Add customer support when backend storage is available.',
          )
        else
          ...customers.map(
            (customer) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(compactLandscape ? 12 : 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: compactLandscape ? 18 : 22,
                        backgroundColor: const Color(0xFFF9D8C5),
                        child: Text(
                          customer.name.isNotEmpty ? customer.name[0] : '?',
                          style: const TextStyle(
                            color: Color(0xFF7A4A33),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(customer.contact),
                            const SizedBox(height: 8),
                            Text(
                              '${customer.orderCount} orders  •  ${_money(customer.totalSpent)} spent',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: selectedCustomerId == customer.id
                            ? null
                            : () => controller.selectCustomer(customer.id),
                        child: Text(
                          selectedCustomerId == customer.id
                              ? 'Selected'
                              : 'Use',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReportsPage extends StatefulWidget {
  const _ReportsPage({
    required this.controller,
    required this.compactLandscape,
  });

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  State<_ReportsPage> createState() => _ReportsPageState();
}

enum _ReportPeriod { week, month }

class _ReportsPageState extends State<_ReportsPage> {
  _ReportPeriod _period = _ReportPeriod.month;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final recentOrders = controller.recentOrders
        .where(_isCompletedSale)
        .toList(growable: false);
    final activeOrders = controller.activeOrders;
    final weekOrders = _ordersFor(recentOrders, _ReportPeriod.week);
    final monthOrders = _ordersFor(recentOrders, _ReportPeriod.month);
    final selectedOrders = _period == _ReportPeriod.week
        ? weekOrders
        : monthOrders;
    final salesTotal = _salesTotal(selectedOrders);
    final weekSales = _salesTotal(weekOrders);
    final monthSales = _salesTotal(monthOrders);
    final orderCount = selectedOrders.length;
    final avgOrder = orderCount == 0 ? 0 : salesTotal / orderCount;
    final itemsSold = selectedOrders.fold<int>(
      0,
      (sum, order) =>
          sum +
          order.items.fold<int>(0, (lineSum, item) => lineSum + item.quantity),
    );
    final topProducts = <String, int>{};
    for (final order in selectedOrders) {
      for (final item in order.items) {
        topProducts[item.productName] =
            (topProducts[item.productName] ?? 0) + item.quantity;
      }
    }
    final topEntries = topProducts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categorySales = _categorySales(selectedOrders, controller);
    final maxCategorySales = categorySales.isEmpty
        ? 0.0
        : categorySales.values.reduce(math.max);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PageHeader(
          title: 'Reports',
          subtitle: 'Track sales by time period and menu category.',
          compactLandscape: widget.compactLandscape,
          trailing: _CountPill(count: activeOrders.length, label: 'active'),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_ReportPeriod>(
          segments: const [
            ButtonSegment(
              value: _ReportPeriod.week,
              label: Text('This week'),
              icon: Icon(Icons.date_range_outlined),
            ),
            ButtonSegment(
              value: _ReportPeriod.month,
              label: Text('This month'),
              icon: Icon(Icons.calendar_month_outlined),
            ),
          ],
          selected: {_period},
          onSelectionChanged: (selection) {
            setState(() => _period = selection.first);
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ReportMetricCard(
              label: 'Today\'s Sales',
              value: _money(controller.todaySales),
            ),
            _ReportMetricCard(label: 'This Week', value: _money(weekSales)),
            _ReportMetricCard(label: 'This Month', value: _money(monthSales)),
            _ReportMetricCard(label: 'Average Order', value: _money(avgOrder)),
            _ReportMetricCard(label: 'Items Sold', value: '$itemsSold'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(widget.compactLandscape ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales by Category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _period == _ReportPeriod.week ? 'This week' : 'This month',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                if (categorySales.isEmpty)
                  const Text('No category sales data for this period.')
                else
                  ...categorySales.entries.map((entry) {
                    final share = maxCategorySales == 0
                        ? 0.0
                        : entry.value / maxCategorySales;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _money(entry.value),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: share,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFF4E4D7),
                              color: _categoryColor(entry.key),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(widget.compactLandscape ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Selling Products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (topEntries.isEmpty)
                  const Text('No sales data yet.')
                else
                  for (final entry in topEntries.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text('${entry.value} sold'),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(widget.compactLandscape ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method Breakdown',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _paymentBreakdownRow('Cash', selectedOrders, PaymentType.cash),
                _paymentBreakdownRow('Card', selectedOrders, PaymentType.card),
                _paymentBreakdownRow(
                  'E-Wallet',
                  selectedOrders,
                  PaymentType.eWallet,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<OrderRecord> _ordersFor(List<OrderRecord> orders, _ReportPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = period == _ReportPeriod.week
        ? today.subtract(const Duration(days: 6))
        : DateTime(now.year, now.month, 1);
    return orders
        .where(
          (order) =>
              !order.createdAt.isBefore(start) &&
              order.createdAt.isBefore(today.add(const Duration(days: 1))),
        )
        .toList(growable: false);
  }

  bool _isCompletedSale(OrderRecord order) => order.status == OrderStatus.paid;

  double _salesTotal(List<OrderRecord> orders) {
    return orders.fold<double>(0, (sum, order) => sum + order.total);
  }

  Map<String, double> _categorySales(
    List<OrderRecord> orders,
    CoffeePosController controller,
  ) {
    final totals = <String, double>{};
    for (final order in orders) {
      for (final item in order.items) {
        final product = controller.productById(item.productId);
        final category = product == null
            ? 'Other'
            : _categoryName(controller, product.categoryId);
        totals[category] = (totals[category] ?? 0) + item.lineTotal;
      }
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, double>.fromEntries(entries);
  }

  String _categoryName(CoffeePosController controller, String categoryId) {
    for (final category in controller.categories) {
      if (category.id == categoryId) return '${category.icon} ${category.name}';
    }
    return 'Other';
  }

  Color _categoryColor(String category) {
    final colors = [
      const Color(0xFFE87852),
      const Color(0xFFC8833A),
      const Color(0xFF6D9B78),
      const Color(0xFF8B73A8),
      const Color(0xFF5D91A6),
    ];
    return colors[category.hashCode.abs() % colors.length];
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({super.key, required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _PageHeader(
              title: 'Settings',
              subtitle: 'Store configuration and POS preferences.',
              compactLandscape: false,
              trailing: _CountPill(
                count: controller.role == Role.admin ? 13 : 12,
                label: 'sections',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SettingsTile(
                  icon: Icons.upload_file_outlined,
                  title: 'Upload Menu',
                  subtitle: 'Upload products and categories from a spreadsheet.',
                  onTap: () => importProductsExcel(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.store_outlined,
                  title: 'Store Information',
                  subtitle: controller.storeName,
                  onTap: () => _editStoreInformation(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Receipt Settings',
                  subtitle: controller.receiptHeader,
                  onTap: () => _editReceiptSettings(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.percent_outlined,
                  title: 'Tax Settings',
                  subtitle:
                      'VAT ${(controller.taxRate * 100).toStringAsFixed(0)}% · Service ${(controller.serviceChargeRate * 100).toStringAsFixed(0)}%',
                  onTap: () => _editTaxSettings(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.local_offer_outlined,
                  title: 'Discount Options',
                  subtitle: controller.discountsEnabled
                      ? '${controller.availableDiscounts.length} discount types enabled'
                      : 'Discounts off',
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        DiscountSettingsDialog(controller: controller),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.payments_outlined,
                  title: 'Currency',
                  subtitle:
                      '${controller.currencyCode} (${controller.currencySymbol})',
                  onTap: () => _editCurrencySettings(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.print_outlined,
                  title: 'Printer Settings',
                  subtitle:
                      '${controller.thermalTransport} · ${controller.thermalPaperWidth == 0 ? 'Auto size' : '${controller.thermalPaperWidth} mm'} · ${controller.autoPrintReceipts ? 'Auto print on' : 'Auto print off'}',
                  onTap: () => _editPrinterSettings(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.tune_outlined,
                  title: 'POS Preferences',
                  subtitle:
                      '${controller.compactReceiptStyle ? 'Compact receipts' : 'Standard receipts'} · ${controller.showBadges ? 'Badges on' : 'Badges off'}',
                  onTap: () => _editPreferencesSettings(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account',
                  subtitle:
                      '${controller.cashierName} · ${controller.role == Role.admin ? 'Administrator' : 'Staff'}',
                  onTap: () => _editAccountSettings(context, controller),
                ),
                if (controller.role == Role.admin)
                  _SettingsTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Staff Permissions',
                    subtitle: controller.isDemo
                        ? 'Disabled in Demo Mode.'
                        : 'Manage staff and manager accounts.',
                    onTap: () => _manageUserAccess(
                      context,
                      isDemo: controller.isDemo,
                    ),
                  ),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: controller.highContrastMode
                      ? 'High contrast mode'
                      : 'Warm neutral mode',
                  onTap: () => _editAppearanceSettings(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.restart_alt_outlined,
                  title: 'Restore Demo Data',
                  subtitle:
                      'Reset store to original sample menu, inventory, and orders.',
                  onTap: () => _confirmRestoreDemoData(context, controller),
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete All Data',
                  subtitle:
                      'Keep menu products and clear past orders, inventory, and sales records.',
                  onTap: () => _confirmDeleteAllData(context, controller),
                  danger: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Future<void> _editStoreInformation(
  BuildContext context,
  CoffeePosController controller,
) async {
  final nameController = TextEditingController(text: controller.storeName);
  final addressController = TextEditingController(
    text: controller.storeAddress,
  );
  final contactController = TextEditingController(
    text: controller.storeContact,
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Store Information'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Store name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.updateStoreInformation(
                name: nameController.text,
                address: addressController.text,
                contact: contactController.text,
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<void> _editReceiptSettings(
  BuildContext context,
  CoffeePosController controller,
) async {
  final headerController = TextEditingController(
    text: controller.receiptHeader,
  );
  final footerController = TextEditingController(
    text: controller.receiptFooter,
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Receipt Settings'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: headerController,
                  decoration: const InputDecoration(
                    labelText: 'Receipt header',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: footerController,
                  decoration: const InputDecoration(
                    labelText: 'Receipt footer',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.updateReceiptSettings(
                header: headerController.text,
                footer: footerController.text,
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<void> _editTaxSettings(
  BuildContext context,
  CoffeePosController controller,
) async {
  bool vatEnabled = controller.vatEnabled;
  final taxController = TextEditingController(
    text: (controller.taxRate * 100).toStringAsFixed(0),
  );
  final serviceController = TextEditingController(
    text: (controller.serviceChargeRate * 100).toStringAsFixed(0),
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Tax Settings'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('VAT'),
                      subtitle: Text(
                        vatEnabled
                            ? 'Enabled - Tax is computed and printed on receipts'
                            : 'Disabled - Non-VAT store orders; no tax line on receipts',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: vatEnabled,
                      onChanged: (value) => setState(() => vatEnabled = value),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taxController,
                      enabled: vatEnabled,
                      decoration: InputDecoration(
                        labelText: 'VAT rate (%)',
                        hintText: '12',
                        helperText: vatEnabled
                            ? 'Standard Philippine retail VAT is 12%'
                            : 'VAT is currently disabled',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: serviceController,
                      decoration: const InputDecoration(
                        labelText: 'Service charge (%)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final parsedRate = vatEnabled
                      ? ((double.tryParse(taxController.text) ?? 12) / 100)
                      : controller.taxRate;
                  final parsedService =
                      (double.tryParse(serviceController.text) ?? 0) / 100;
                  controller.updateTaxSettings(
                    vatEnabled: vatEnabled,
                    taxRate: parsedRate,
                    serviceChargeRate: parsedService,
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _editCurrencySettings(
  BuildContext context,
  CoffeePosController controller,
) async {
  final codeController = TextEditingController(text: controller.currencyCode);
  final symbolController = TextEditingController(
    text: controller.currencySymbol,
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Currency'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Currency code'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: symbolController,
                  decoration: const InputDecoration(
                    labelText: 'Currency symbol',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.updateCurrencySettings(
                code: codeController.text,
                symbol: symbolController.text,
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<void> _editPrinterSettings(
  BuildContext context,
  CoffeePosController controller,
) async {
  final printerController = TextEditingController(text: controller.printerName);
  String selectedPrinterUrl = controller.printerUrl;
  bool autoPrint = controller.autoPrintReceipts;
  String transport =
      const [
        'Direct print (no prompt)',
        'System dialog',
        'Thermal printer app',
        'Network (ESC/POS)',
      ].contains(controller.thermalTransport)
      ? controller.thermalTransport
      : 'Direct print (no prompt)';
  int paperWidth = controller.thermalPaperWidth;
  int feedLines = controller.thermalFeedLines;
  bool autoCut = controller.thermalAutoCut;
  bool openCashDrawer = controller.thermalOpenCashDrawer;
  bool webKioskPrinting = controller.thermalWebKiosk;
  String? connectionStatus;
  bool checkingConnection = false;
  final isSystemDialogSelected =
      transport == 'System dialog' &&
      (kIsWeb || defaultTargetPlatform == TargetPlatform.android);

  Future<void> checkConnection(StateSetter setState) async {
    setState(() {
      checkingConnection = true;
      connectionStatus = null;
    });
    try {
      final printers = await Printing.listPrinters();
      final desired = printerController.text.trim().toLowerCase();
      final desiredUrl = selectedPrinterUrl.trim();
      if (printers.isEmpty) {
        setState(() {
          connectionStatus = 'No printers detected on this device.';
        });
        return;
      }

      if (desiredUrl.isNotEmpty) {
        final byUrl = printers
            .where((printer) => printer.url == desiredUrl)
            .toList(growable: false);
        if (byUrl.isNotEmpty) {
          setState(() {
            selectedPrinterUrl = byUrl.first.url;
            printerController.text = byUrl.first.name;
            connectionStatus =
                'Connected to ${byUrl.first.name}. ${printers.length} printer(s) available.';
          });
          return;
        }
      }

      if (desired.isEmpty) {
        final defaultPrinter = printers.firstWhere(
          (printer) => printer.isDefault,
          orElse: () => printers.first,
        );
        setState(() {
          connectionStatus = 'Detected ${printers.length} printer(s).';
          printerController.text = defaultPrinter.name;
          selectedPrinterUrl = defaultPrinter.url;
        });
        return;
      }

      final matchedPrinter = printers
          .where((printer) {
            final name = printer.name.toLowerCase();
            return name == desired ||
                name.contains(desired) ||
                desired.contains(name);
          })
          .toList(growable: false);

      if (matchedPrinter.isEmpty) {
        setState(() {
          connectionStatus =
              'Printer not found. Detected ${printers.length} printer(s) nearby.';
        });
        return;
      }

      setState(() {
        printerController.text = matchedPrinter.first.name;
        selectedPrinterUrl = matchedPrinter.first.url;
        connectionStatus =
            'Connected to ${matchedPrinter.first.name}. ${printers.length} printer(s) available.';
      });
    } catch (_) {
      setState(() {
        connectionStatus = 'Unable to check printers on this device.';
      });
    } finally {
      setState(() {
        checkingConnection = false;
      });
    }
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Printer Settings'),
            content: SizedBox(
              width: math.min(
                420,
                math.max(280, MediaQuery.sizeOf(context).width - 48),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: checkingConnection
                          ? null
                          : () async {
                              setState(() {
                                checkingConnection = true;
                                connectionStatus = null;
                              });
                              final success = await controller
                                  .autoConfigurePrinter(force: true);
                              if (success) {
                                setState(() {
                                  printerController.text =
                                      controller.printerName;
                                  selectedPrinterUrl = controller.printerUrl;
                                  transport = controller.thermalTransport;
                                  paperWidth = controller.thermalPaperWidth;
                                  autoPrint = controller.autoPrintReceipts;
                                  connectionStatus =
                                      'Auto-configured: ${controller.printerName} (80mm roll, Direct print)';
                                });
                              } else {
                                await checkConnection(setState);
                              }
                              setState(() {
                                checkingConnection = false;
                              });
                            },
                      icon: checkingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      label: const Text('Auto-detect 80mm Printer'),
                    ),
                    const SizedBox(height: 12),
                    if (isSystemDialogSelected)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2A77F)),
                        ),
                        child: const Text(
                          'Your device will choose the printer when you print a receipt. Android opens its system print dialog; Chrome opens the browser print dialog.',
                          style: TextStyle(
                            color: Color(0xFF6B4423),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      TextField(
                        controller: printerController,
                        onChanged: (_) => setState(() {
                          selectedPrinterUrl = '';
                          connectionStatus = null;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Printer name',
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: transport,
                      decoration: const InputDecoration(
                        labelText: 'Connection method',
                      ),
                      items:
                          const [
                                'Direct print (no prompt)',
                                'System dialog',
                                'Thermal printer app',
                                'Network (ESC/POS)',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(growable: false),
                      onChanged: (value) =>
                          setState(() => transport = value ?? transport),
                    ),
                    if (transport == 'Direct print (no prompt)') ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          kIsWeb
                              ? 'Sends receipts directly to your receipt printer without showing a print dialog.\n(For browser kiosk mode or background printing).'
                              : 'Sends receipts directly to your connected thermal printer silently with zero print dialog prompts.',
                          style: TextStyle(
                            color: kIsWeb
                                ? const Color(0xFF6B4423)
                                : const Color(0xFF2E6B30),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (kIsWeb)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Kiosk Mode (Silent Printing)',
                          ),
                          subtitle: const Text(
                            'Enable if your browser is running in kiosk mode for silent receipt printing.',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: webKioskPrinting,
                          onChanged: (val) =>
                              setState(() => webKioskPrinting = val),
                        ),
                    ] else if (transport == 'Network (ESC/POS)') ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: selectedPrinterUrl,
                        decoration: const InputDecoration(
                          labelText: 'Printer network address (IP : Port)',
                          hintText: '192.168.1.100:9100',
                        ),
                        onChanged: (val) =>
                            setState(() => selectedPrinterUrl = val.trim()),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Sends receipts directly to your network thermal receipt printer over Wi-Fi or local network cable.',
                          style: TextStyle(
                            color: Color(0xFF6B4423),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ] else if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.android &&
                        transport == 'Thermal printer app')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'When printing, your device will let you select your receipt printer app (Bluetooth, USB, or Wi-Fi).',
                          style: TextStyle(
                            color: Color(0xFF6B4423),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: paperWidth,
                      decoration: const InputDecoration(
                        labelText: 'Paper size',
                      ),
                      items: const [0, 58, 80, 50]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(switch (value) {
                                0 => 'Auto-detect size',
                                58 => '58 mm roll (32 cols)',
                                80 => '80 mm roll (48 cols)',
                                _ => '$value mm roll',
                              }),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setState(() => paperWidth = value ?? paperWidth),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto print receipts'),
                      value: autoPrint,
                      onChanged: (value) => setState(() => autoPrint = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automatic cut'),
                      value: autoCut,
                      onChanged: (value) => setState(() => autoCut = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Open cash drawer after print'),
                      value: openCashDrawer,
                      onChanged: (value) =>
                          setState(() => openCashDrawer = value),
                    ),
                    Text('Paper feed: $feedLines lines'),
                    Slider(
                      value: feedLines.toDouble(),
                      min: 0,
                      max: 8,
                      divisions: 8,
                      label: '$feedLines',
                      onChanged: (value) =>
                          setState(() => feedLines = value.round()),
                    ),
                    const SizedBox(height: 4),
                    if (!isSystemDialogSelected &&
                        connectionStatus != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              connectionStatus!.startsWith('Connected') ||
                                  connectionStatus!.startsWith(
                                    'Auto-configured',
                                  )
                              ? const Color(0xFFEAF6EA)
                              : const Color(0xFFFFF0EE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                connectionStatus!.startsWith('Connected') ||
                                    connectionStatus!.startsWith(
                                      'Auto-configured',
                                    )
                                ? const Color(0xFF7BB57A)
                                : const Color(0xFFD65B57),
                          ),
                        ),
                        child: Text(
                          connectionStatus!,
                          style: TextStyle(
                            color:
                                connectionStatus!.startsWith('Connected') ||
                                    connectionStatus!.startsWith(
                                      'Auto-configured',
                                    )
                                ? const Color(0xFF2F6E30)
                                : const Color(0xFF9B453F),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!isSystemDialogSelected)
                      OutlinedButton.icon(
                        onPressed: checkingConnection
                            ? null
                            : () => checkConnection(setState),
                        icon: checkingConnection
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering_outlined),
                        label: Text(
                          checkingConnection
                              ? 'Checking...'
                              : 'Check connection',
                        ),
                      ),
                    if (!isSystemDialogSelected)
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final selected = await Printing.pickPrinter(
                              context: dialogContext,
                            );
                            if (selected != null) {
                              setState(() {
                                printerController.text = selected.name;
                                selectedPrinterUrl = selected.url;
                                connectionStatus =
                                    'Selected ${selected.name} from system printers.';
                              });
                            }
                          } catch (_) {
                            setState(() {
                              connectionStatus =
                                  'Printer selection is not available on this device.';
                            });
                          }
                        },
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Pick printer'),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  controller.updatePrinterSettings(
                    printerName: printerController.text,
                    printerUrl: selectedPrinterUrl,
                    autoPrintReceipts: autoPrint,
                    thermalTransport: transport,
                    thermalPaperWidth: paperWidth,
                    thermalFeedLines: feedLines,
                    thermalAutoCut: autoCut,
                    thermalOpenCashDrawer: openCashDrawer,
                    thermalWebKiosk: webKioskPrinting,
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _editPreferencesSettings(
  BuildContext context,
  CoffeePosController controller,
) async {
  bool compactReceiptStyle = controller.compactReceiptStyle;
  bool showBadges = controller.showBadges;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('POS Preferences'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compact receipt style'),
                    value: compactReceiptStyle,
                    onChanged: (value) =>
                        setState(() => compactReceiptStyle = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show badges'),
                    value: showBadges,
                    onChanged: (value) => setState(() => showBadges = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  controller.updatePreferences(
                    compactReceiptStyle: compactReceiptStyle,
                    showBadges: showBadges,
                    highContrastMode: controller.highContrastMode,
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _editAccountSettings(
  BuildContext context,
  CoffeePosController controller,
) async {
  final cashierController = TextEditingController(text: controller.cashierName);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Account'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: cashierController,
                    decoration: const InputDecoration(
                      labelText: 'Cashier name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.role == Role.admin
                        ? 'Administrator account'
                        : 'Standard user account',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  controller.updateCashierName(cashierController.text);
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _manageUserAccess(BuildContext context, {bool isDemo = false}) {
  if (isDemo) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFC48B28)),
              SizedBox(width: 8),
              Text('Staff Permissions (Demo)'),
            ],
          ),
          content: const Text(
            'Staff permissions cannot be modified in Demo Mode.\n\n'
            'Staff roles and account permissions can only be managed from your live store owner account.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC48B28),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Understood'),
            ),
          ],
        );
      },
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => const _UserAccessDialog(),
  );
}

class _UserAccessDialog extends StatefulWidget {
  const _UserAccessDialog();

  @override
  State<_UserAccessDialog> createState() => _UserAccessDialogState();
}

class _UserAccessDialogState extends State<_UserAccessDialog> {
  late Future<List<_ManagedUser>> _usersFuture;
  String? _updatingUserId;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<_ManagedUser>> _loadUsers() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('listUsers')
        .call();
    final data = result.data;
    final rawUsers = data is Map ? data['users'] : null;
    if (rawUsers is! List) {
      return const <_ManagedUser>[];
    }
    final users = rawUsers
        .whereType<Map>()
        .map((raw) {
          return _ManagedUser(
            uid: raw['uid'] as String? ?? '',
            email: raw['email'] as String? ?? 'Unknown account',
            role: raw['role'] == 'admin' ? 'admin' : 'user',
          );
        })
        .toList(growable: false);
    users.sort((a, b) => a.email.compareTo(b.email));
    return users;
  }

  Future<void> _setRole(_ManagedUser user, String role) async {
    setState(() => _updatingUserId = user.uid);
    try {
      await FirebaseFunctions.instance.httpsCallable('setUserRole').call(
        <String, dynamic>{'uid': user.uid, 'role': role},
      );
      if (!mounted) return;
      setState(() => _usersFuture = _loadUsers());
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to update this role.')),
      );
    } finally {
      if (mounted) setState(() => _updatingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Staff Permissions'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<List<_ManagedUser>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Text('Unable to load staff accounts.');
            }
            final users = snapshot.data ?? const <_ManagedUser>[];
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: users.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isUpdating = _updatingUserId == user.uid;
                  return ListTile(
                    title: Text(user.email),
                    subtitle: Text(
                      user.role == 'admin' ? 'Administrator' : 'Staff / Cashier',
                    ),
                    trailing: DropdownButton<String>(
                      value: user.role,
                      onChanged: isUpdating
                          ? null
                          : (role) {
                              if (role != null && role != user.role) {
                                _setRole(user, role);
                              }
                            },
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('Staff / Cashier')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ManagedUser {
  const _ManagedUser({
    required this.uid,
    required this.email,
    required this.role,
  });

  final String uid;
  final String email;
  final String role;
}

Future<void> _editAppearanceSettings(
  BuildContext context,
  CoffeePosController controller,
) async {
  bool highContrastMode = controller.highContrastMode;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Appearance'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('High contrast mode'),
                    value: highContrastMode,
                    onChanged: (value) =>
                        setState(() => highContrastMode = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  controller.updatePreferences(
                    compactReceiptStyle: controller.compactReceiptStyle,
                    showBadges: controller.showBadges,
                    highContrastMode: highContrastMode,
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _confirmRestoreDemoData(
  BuildContext context,
  CoffeePosController controller,
) async {
  final isDemo = controller.isDemo;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(isDemo ? 'Reset Demo Data?' : 'Restore Sample Data?'),
        content: Text(
          isDemo
              ? 'This will reset demo store records to original sample items, orders, and stock. Real store data is completely untouched.'
              : 'This will reload the initial sample menu, orders, inventory, and settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7A4A33),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isDemo ? 'Reset' : 'Restore'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await controller.restoreDemoData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDemo
                ? 'Demo store records have been reset to original sample data.'
                : 'Sample store data has been restored.',
          ),
        ),
      );
    }
  }
}

Future<void> _confirmDeleteAllData(
  BuildContext context,
  CoffeePosController controller,
) async {
  final isDemo = controller.isDemo;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(isDemo ? 'Delete Demo Data?' : 'Delete All Data?'),
        content: Text(
          isDemo
              ? 'This will keep demo menu products and clear all demo orders, inventory, and activity. Real store data is completely unaffected.'
              : 'This will keep your current menu products and clear past orders, inventory, customers, shifts, and sales records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC63E3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await controller.deleteAllData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDemo
                ? 'Demo orders and records have been cleared.'
                : 'Past orders, inventory, and sales records have been cleared.',
          ),
        ),
      );
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.compactLandscape,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: compactLandscape ? 2 : 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 8), trailing],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            trailing,
          ],
        );
      },
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8E0D1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count $label',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF7B513B),
        ),
      ),
    );
  }
}

class _OrderTicketCard extends StatelessWidget {
  const _OrderTicketCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.time,
    required this.itemCount,
    required this.total,
    required this.compactLandscape,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.secondaryActionLabel,
    required this.onSecondaryAction,
    this.onPrintTicket,
    this.onCancel,
    this.onRefund,
  });

  final String title;
  final String subtitle;
  final String status;
  final String time;
  final int itemCount;
  final double total;
  final bool compactLandscape;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String secondaryActionLabel;
  final VoidCallback onSecondaryAction;
  final VoidCallback? onPrintTicket;
  final VoidCallback? onCancel;
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 250;
        final isVeryCompact = constraints.maxWidth < 195;
        final padding = isVeryCompact ? 8.0 : (isCompact ? 10.0 : (compactLandscape ? 12.0 : 14.0));

        final Color statusBg;
        final Color statusFg;
        switch (status.toLowerCase()) {
          case 'pending':
            statusBg = const Color(0xFFFFEDE1);
            statusFg = const Color(0xFF8B4513);
            break;
          case 'preparing':
            statusBg = const Color(0xFFFFF3E0);
            statusFg = const Color(0xFFE65100);
            break;
          case 'held':
            statusBg = const Color(0xFFECEFF1);
            statusFg = const Color(0xFF455A64);
            break;
          case 'awaiting payment':
            statusBg = const Color(0xFFFFEBEE);
            statusFg = const Color(0xFFC62828);
            break;
          default:
            statusBg = const Color(0xFFFFE8D2);
            statusFg = const Color(0xFF6B4423);
        }

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFEFE6DC)),
          ),
          color: const Color(0xFFFFFDFB),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Title + Subtitle and Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: isVeryCompact ? 11.5 : (isCompact ? 12.5 : 14),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2F251E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: isVeryCompact ? 10 : (isCompact ? 10.5 : 11.5),
                              color: const Color(0xFF8C7564),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isVeryCompact ? 5 : 7,
                        vertical: isVeryCompact ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusFg.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: isVeryCompact ? 9 : 10,
                          fontWeight: FontWeight.w700,
                          color: statusFg,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Center Meta: Items count, time, and total
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '$itemCount items • $time',
                            style: TextStyle(
                              fontSize: isVeryCompact ? 10 : (isCompact ? 10.5 : 11.5),
                              color: const Color(0xFF8C7564),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _money(total),
                          style: TextStyle(
                            fontSize: isVeryCompact ? 12 : (isCompact ? 13 : 14),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6B4423),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Bottom Action buttons
                Row(
                  children: [
                    if (onCancel != null) ...[
                      if (isCompact)
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          color: const Color(0xFFB5442F),
                          tooltip: 'Cancel Order',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                          onPressed: onCancel!,
                        )
                      else ...[
                        _TicketActionButton(
                          label: 'Cancel',
                          icon: Icons.cancel_outlined,
                          onPressed: onCancel!,
                          destructive: true,
                          compact: isCompact,
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                    Expanded(
                      child: _TicketActionButton(
                        label: secondaryActionLabel,
                        icon: Icons.check_circle_outline,
                        onPressed: onSecondaryAction,
                        destructive: true,
                        compact: isCompact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _TicketActionButton(
                        label: isVeryCompact && primaryActionLabel == 'Continue Order'
                            ? 'Continue'
                            : primaryActionLabel,
                        icon: orderActionIcon(primaryActionLabel),
                        onPressed: onPrimaryAction,
                        filled: true,
                        compact: isCompact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

IconData orderActionIcon(String label) {
  return label == 'Continue Order'
      ? Icons.play_arrow_rounded
      : Icons.visibility_outlined;
}

class _TicketActionButton extends StatelessWidget {
  const _TicketActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.destructive = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final bool destructive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool useWarning = destructive && !filled;
    final Color foreground = destructive
        ? const Color(0xFFB5442F)
        : const Color(0xFF6B4423);
    final Color background = filled
        ? const Color(0xFFFF8F4F)
        : useWarning
            ? const Color(0xFFFDE8E3)
            : const Color(0xFFFFE8D2);
    final Color borderColor = foreground.withValues(alpha: 0.18);
    final fontSize = compact ? 10.5 : 12.0;
    final iconSize = compact ? 13.0 : 15.0;
    final padding = EdgeInsets.symmetric(
      horizontal: compact ? 4 : 8,
      vertical: compact ? 3 : 5,
    );
    final height = compact ? 28.0 : 32.0;

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: filled ? Colors.white : foreground),
        SizedBox(width: compact ? 3 : 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: height),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: filled ? BorderSide.none : BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HistoryOrderCard extends StatefulWidget {
  const _HistoryOrderCard({
    required this.controller,
    required this.order,
    required this.compactLandscape,
  });

  final CoffeePosController controller;
  final OrderRecord order;
  final bool compactLandscape;

  @override
  State<_HistoryOrderCard> createState() => _HistoryOrderCardState();
}

class _HistoryOrderCardState extends State<_HistoryOrderCard> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final controller = widget.controller;
    final compactLandscape = widget.compactLandscape;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 250;
        final isVeryCompact = constraints.maxWidth < 195;
        final padding = isVeryCompact ? 8.0 : (isCompact ? 10.0 : (compactLandscape ? 12.0 : 14.0));

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

        final Color statusBg = isCompleted
            ? const Color(0xFFE8F5E9)
            : isVoided
                ? const Color(0xFFFFEBEE)
                : isRefunded
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFFFEDE1);

        final Color statusFg = isCompleted
            ? const Color(0xFF2E7D32)
            : isVoided
                ? const Color(0xFFC62828)
                : isRefunded
                    ? const Color(0xFFE65100)
                    : const Color(0xFF8B4513);

        final String printLabel = _isPrinting
            ? 'Printing...'
            : (isCompact ? 'Print' : 'Print receipt');

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFEFE6DC)),
          ),
          color: const Color(0xFFFFFDFB),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Order Number and Status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: TextStyle(
                              fontSize: isVeryCompact ? 11.5 : (isCompact ? 12.5 : 14),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2F251E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatDateTime(context, order.createdAt)}  •  ${order.id}',
                            style: TextStyle(
                              fontSize: isVeryCompact ? 9.5 : (isCompact ? 10 : 11),
                              color: const Color(0xFF8C7564),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isVeryCompact ? 5 : 7,
                        vertical: isVeryCompact ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusFg.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: isVeryCompact ? 9 : 10,
                          fontWeight: FontWeight.w700,
                          color: statusFg,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Center: Details (Cashier, Payment, items count, and latest status change if any)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cashier: ${order.cashierName}',
                          style: TextStyle(
                            fontSize: isVeryCompact ? 10 : 11,
                            color: const Color(0xFF5D4634),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Payment: ${order.paymentType.name.toUpperCase()}  •  ${order.items.length} items',
                          style: TextStyle(
                            fontSize: isVeryCompact ? 10 : 11,
                            color: const Color(0xFF5D4634),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        for (final change in order.statusHistory) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${switch (change.action) {
                              OrderAction.complete => 'Completed',
                              OrderAction.cancel => 'Cancelled',
                              OrderAction.refund => 'Refunded',
                            }} by ${change.cashierName} • ${_formatDateTime(context, change.at)}',
                            style: TextStyle(
                              fontSize: isVeryCompact ? 9 : 10,
                              color: const Color(0xFF8C7564),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (change.action == OrderAction.refund)
                            Text(
                              'Refund amount: ${_money(change.amount)}',
                              style: TextStyle(
                                fontSize: isVeryCompact ? 9 : 10,
                                color: const Color(0xFFB5442F),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (change.reason.isNotEmpty)
                            Text(
                              'Reason: ${change.reason}',
                              style: TextStyle(
                                fontSize: isVeryCompact ? 9 : 10,
                                color: const Color(0xFF8C7564),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Bottom: Total and Print Receipt Button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total: ${_money(_orderSummary(order).total)}',
                        style: TextStyle(
                          fontSize: isVeryCompact ? 11.5 : (isCompact ? 12 : 13),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6B4423),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints.tightFor(
                        height: isVeryCompact ? 28 : 32,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: (order.status == OrderStatus.paid && !_isPrinting)
                            ? () async {
                                setState(() => _isPrinting = true);
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final printResult = await controller.printReceipt(
                                    order,
                                    manualReprint: true,
                                  );
                                  final String msg;
                                  if (printResult.status ==
                                      receipt_printer.PrintStatus.submittedToDialog) {
                                    msg = 'Print window opened for ${order.id}';
                                  } else if (printResult.isSuccess) {
                                    msg = 'Receipt printed for ${order.id}';
                                  } else if (printResult.status ==
                                      receipt_printer.PrintStatus.unknown) {
                                    msg =
                                        'Print status unknown. Please check your printer before reprinting.';
                                  } else if (printResult.status ==
                                      receipt_printer.PrintStatus.canceled) {
                                    msg = 'Print canceled.';
                                  } else {
                                    msg =
                                        'Unable to print receipt. Please check the printer connection.';
                                  }
                                  showAutoHidingSnackBar(
                                    messenger: messenger,
                                    content: Text(msg),
                                    duration: const Duration(seconds: 5),
                                  );
                                } catch (error, stackTrace) {
                                  debugPrint(
                                    'Receipt print failed for ${order.id}: '
                                    '$error\n$stackTrace',
                                  );
                                  showAutoHidingSnackBar(
                                    messenger: messenger,
                                    content: const Text(
                                      'Unable to print receipt. Please check the printer connection.',
                                    ),
                                    duration: const Duration(seconds: 5),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _isPrinting = false);
                                  }
                                }
                              }
                            : null,
                        icon: _isPrinting
                            ? SizedBox(
                                width: isVeryCompact ? 11 : 13,
                                height: isVeryCompact ? 11 : 13,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.receipt_long, size: isVeryCompact ? 13 : 15),
                        label: Text(printLabel),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B4423),
                          backgroundColor: const Color(0xFFFFE8D2),
                          side: BorderSide(
                            color: const Color(0xFF6B4423).withValues(alpha: 0.18),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isVeryCompact ? 6 : 8,
                            vertical: 0,
                          ),
                          textStyle: TextStyle(
                            fontSize: isVeryCompact ? 10 : 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          visualDensity: VisualDensity.compact,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectedCustomerBanner extends StatelessWidget {
  const _SelectedCustomerBanner({
    required this.customer,
    required this.onClear,
  });

  final CustomerProfile customer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF3EA),
      child: ListTile(
        leading: const Icon(Icons.person_pin_circle_outlined),
        title: Text(customer.name),
        subtitle: Text(customer.contact),
        trailing: TextButton(onPressed: onClear, child: const Text('Clear')),
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isPrinterSettings = title == 'Printer Settings';
    final titleLines = isPrinterSettings ? 2 : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? math.min(260.0, constraints.maxWidth)
            : 260.0;
        final narrow = width < 240;
        final details = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: titleLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 13.5,
                height: 1.0,
                color: danger ? const Color(0xFFC63E3A) : null,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 9.5,
                height: 1.0,
                color: danger ? const Color(0xFF9B453F) : null,
              ),
            ),
            const SizedBox(height: 5),
            if (danger)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE4E1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Color(0xFFC63E3A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Danger',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC63E3A),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
        final arrow = Icon(
          Icons.chevron_right,
          size: 20,
          color: danger ? const Color(0xFFC63E3A) : null,
        );
        final content = narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: danger ? const Color(0xFFC63E3A) : null,
                      ),
                      const Spacer(),
                      arrow,
                    ],
                  ),
                  const SizedBox(height: 6),
                  details,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: danger ? const Color(0xFFC63E3A) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 4),
                  arrow,
                ],
              );

        return SizedBox(
          width: width,
          height: 138,
          child: Card(
            color: danger ? const Color(0xFFFFF0EE) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: danger ? const Color(0xFFD65B57) : Colors.transparent,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(padding: const EdgeInsets.all(14), child: content),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42, color: const Color(0xFF9A7A60)),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _OrderHistoryFilter {
  const _OrderHistoryFilter._(this.label);

  final String label;

  static const all = _OrderHistoryFilter._('All');
  static const today = _OrderHistoryFilter._('Today');
  static const completed = _OrderHistoryFilter._('Completed');
  static const cancelled = _OrderHistoryFilter._('Cancelled');
  static const refunded = _OrderHistoryFilter._('Refunded');

  static const values = [all, today, completed, cancelled, refunded];
}

class _PaymentBreakdownLine extends StatelessWidget {
  const _PaymentBreakdownLine({
    required this.label,
    required this.value,
    required this.count,
  });

  final String label;
  final double value;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$count orders'),
          const SizedBox(width: 12),
          Text(_money(value)),
        ],
      ),
    );
  }
}

Widget _paymentBreakdownRow(
  String label,
  List<OrderRecord> orders,
  PaymentType type,
) {
  final filtered = orders
      .where((order) => order.paymentType == type)
      .toList(growable: false);
  final total = filtered.fold<double>(
    0,
    (sum, order) => sum + _orderSummary(order).total,
  );
  return _PaymentBreakdownLine(
    label: label,
    value: total,
    count: filtered.length,
  );
}

Future<void> _showOrderDetails(
  BuildContext context,
  OrderQueueRecord order,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              order.id,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8E0D1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _queueStatusText(order.status),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7B513B),
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.storefront_outlined,
                      label: order.orderType,
                    ),
                    _InfoChip(
                      icon: Icons.person_outline,
                      label: order.customerName,
                    ),
                    _InfoChip(
                      icon: Icons.schedule_outlined,
                      label: _formatTime(context, order.createdAt),
                    ),
                    _InfoChip(
                      icon: Icons.format_list_bulleted,
                      label:
                          '${order.items.length} line${order.items.length == 1 ? '' : 's'}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCF8F2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x1A9A7A60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.productName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity}x',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7B513B),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(_money(item.lineTotal)),
                                ],
                              ),
                              if (item.modifierLabels.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: item.modifierLabels
                                      .map(
                                        (modifier) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFEFE3),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            modifier,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF8A5F3D),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _money(order.subtotal),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1A9A7A60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7B513B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF5D4634),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _changeOrderStatus(
  BuildContext context,
  CoffeePosController controller,
  OrderQueueRecord order,
  OrderAction action,
) async {
  final amount = controller.transactionForQueue(order)?.total ?? order.subtotal;
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => OrderStatusDialog(
      action: action,
      orderNumber: order.displayOrderNumber,
      amount: amount,
      onConfirm: (reason) => controller.changeOrderStatus(
        order,
        action: action,
        reason: reason,
        expectedRefundAmount: action == OrderAction.refund ? amount : null,
      ),
    ),
  );
  if (changed == true && context.mounted) {
    showAutoHidingSnackBar(
      messenger: ScaffoldMessenger.of(context),
      content: Text(
        'Order #${order.displayOrderNumber} ${switch (action) {
          OrderAction.complete => 'completed',
          OrderAction.cancel => 'cancelled',
          OrderAction.refund => 'refunded',
        }}. Saved in order history.',
      ),
      duration: const Duration(seconds: 5),
    );
  }
}

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

String _queueStatusText(OrderQueueStatus status) {
  return switch (status) {
    OrderQueueStatus.pending => 'Pending',
    OrderQueueStatus.preparing => 'Preparing',
    OrderQueueStatus.held => 'Held',
    OrderQueueStatus.awaitingPayment => 'Awaiting Payment',
  };
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatTime(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(date));
}

String _formatDateTime(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatShortDate(date)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

String _money(num value) => '₱${value.toStringAsFixed(2)}';
