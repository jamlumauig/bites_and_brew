import 'package:flutter/material.dart';
import '../../domain/coffee_pos_models.dart';
import '../../state/coffee_pos_controller.dart';
import '../../utils/category_icon.dart';
import '../../utils/receipt_printer.dart' as receipt_printer;
import 'auto_hiding_snack_bar.dart';
import 'discount_settings_dialog.dart';

const _cream = Color(0xFFFAF6F0);
const _coral = Color(0xFFE96755);
const _ink = Color(0xFF332D29);
const _muted = Color(0xFF83776D);
const _line = Color(0xFFECE4DA);

class CashierDashboard extends StatefulWidget {
  const CashierDashboard({super.key, required this.controller});
  final CoffeePosController controller;

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  late TextEditingController _search;
  late ScrollController _productsScroll;
  late ScrollController _categoriesScroll;
  late int _newOrderRevision;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _attachNavigation();
  }

  void _attachNavigation() {
    final controller = widget.controller;
    _query = controller.productsSearchQuery;
    _search = TextEditingController(text: _query);
    _productsScroll = ScrollController(
      initialScrollOffset: controller.productsScrollOffset,
      keepScrollOffset: false,
    )..addListener(_rememberScroll);
    _categoriesScroll = ScrollController(
      initialScrollOffset: controller.categoriesScrollOffset,
      keepScrollOffset: false,
    )..addListener(_rememberScroll);
    _newOrderRevision = controller.newOrderRevision;
    controller.addListener(_onOrderChanged);
  }

  void _rememberScroll() {
    if (_productsScroll.hasClients) {
      widget.controller.productsScrollOffset = _productsScroll.offset;
    }
    if (_categoriesScroll.hasClients) {
      widget.controller.categoriesScrollOffset = _categoriesScroll.offset;
    }
  }

  void _onOrderChanged() {
    if (_newOrderRevision == widget.controller.newOrderRevision) return;
    _newOrderRevision = widget.controller.newOrderRevision;
    _search.clear();
    setState(() => _query = '');
    if (_productsScroll.hasClients) _productsScroll.jumpTo(0);
    if (_categoriesScroll.hasClients) _categoriesScroll.jumpTo(0);
  }

  void _disposeNavigation(CoffeePosController controller) {
    controller.removeListener(_onOrderChanged);
    _search.dispose();
    _productsScroll.dispose();
    _categoriesScroll.dispose();
  }

  @override
  void didUpdateWidget(covariant CashierDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _disposeNavigation(oldWidget.controller);
      _attachNavigation();
    }
  }

  @override
  void dispose() {
    _disposeNavigation(widget.controller);
    super.dispose();
  }

  void _selectCategory(int index) {
    _search.clear();
    widget.controller.productsSearchQuery = '';
    widget.controller.productsScrollOffset = 0;
    setState(() => _query = '');
    widget.controller.selectCategory(index);
    if (_productsScroll.hasClients) _productsScroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final controller = widget.controller;
        final desktop = constraints.maxWidth >= 900;
        final phone = constraints.maxWidth < 600;
        final categories = controller.cashierCategories;
        final query = _query.trim().toLowerCase();
        final categoryNames = {
          for (final category in categories)
            category.id: category.name.toLowerCase(),
        };
        final products = query.isEmpty
            ? controller.visibleProducts
            : controller.products
                  .where(
                    (product) =>
                        product.name.toLowerCase().contains(query) ||
                        product.description.toLowerCase().contains(query) ||
                        (categoryNames[product.categoryId]?.contains(query) ??
                            false),
                  )
                  .toList();
        return ColoredBox(
          color: _cream,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  phone ? 4 : 8,
                  8,
                  8,
                  phone ? 12 : 20,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: _coral,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Products',
                            style: TextStyle(
                              fontSize: phone ? 23 : 28,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -.7,
                            ),
                          ),
                          if (!phone)
                            const Text(
                              'Good orders start here.',
                              style: TextStyle(color: _muted, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    if (!phone)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: _line),
                        ),
                        child: Text(
                          controller.storeName,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: phone
                          ? (constraints.maxWidth < 360 ? 70 : 80)
                          : 164,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              phone ? 4 : 12,
                              4,
                              4,
                              12,
                            ),
                            child: Text(
                              phone ? 'MENU' : 'CATEGORIES',
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Scrollbar(
                              controller: _categoriesScroll,
                              child: ListView.separated(
                                key: const ValueKey('category-rail'),
                                controller: _categoriesScroll,
                                padding: const EdgeInsets.only(
                                  right: 6,
                                  bottom: 12,
                                ),
                                itemCount: categories.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final category = categories[index];
                                  final selected =
                                      query.isEmpty &&
                                      controller.selectedCategory?.id ==
                                          category.id;
                                  final count = controller.products
                                      .where((p) => p.categoryId == category.id)
                                      .length;
                                  return Semantics(
                                    selected: selected,
                                    button: true,
                                    child: Tooltip(
                                      message: category.name,
                                      child: Material(
                                        color: selected
                                            ? _coral
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        child: InkWell(
                                          key: ValueKey(
                                            'category-${category.id}',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          onTap: () => _selectCategory(index),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: phone ? 5 : 12,
                                              vertical: 14,
                                            ),
                                            child: phone
                                                ? Column(
                                                    children: [
                                                      Icon(
                                                        categoryIconData(
                                                          category,
                                                        ),
                                                        size: 22,
                                                        color: selected
                                                            ? Colors.white
                                                            : _muted,
                                                      ),
                                                      const SizedBox(height: 7),
                                                      Text(
                                                        category.name,
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          height: 1.3,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: selected
                                                              ? Colors.white
                                                              : _ink,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : Row(
                                                    children: [
                                                      Icon(
                                                        categoryIconData(
                                                          category,
                                                        ),
                                                        size: 20,
                                                        color: selected
                                                            ? Colors.white
                                                            : _muted,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          category.name,
                                                          maxLines: 3,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: selected
                                                                ? Colors.white
                                                                : _ink,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$count',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: selected
                                                              ? Colors.white70
                                                              : _muted,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 48,
                            child: TextField(
                              key: const ValueKey('product-search'),
                              controller: _search,
                              onChanged: (value) {
                                controller.productsSearchQuery = value;
                                setState(() => _query = value);
                                if (_productsScroll.hasClients) {
                                  _productsScroll.jumpTo(0);
                                }
                              },
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search Products',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  size: 21,
                                  color: _muted,
                                ),
                                suffixIcon: query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          _search.clear();
                                          controller.productsSearchQuery = '';
                                          setState(() => _query = '');
                                        },
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: const BorderSide(color: _line),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: const BorderSide(color: _line),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Tooltip(
                                    message: query.isEmpty
                                        ? controller.selectedCategory?.name ??
                                              'Menu'
                                        : 'Results across all categories',
                                    child: Text(
                                      query.isEmpty
                                          ? controller.selectedCategory?.name ??
                                                'Menu'
                                          : 'Search results',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: phone ? 17 : 21,
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${products.length} items',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: products.isEmpty
                                ? _OrderingEmptyState(
                                    icon: query.isEmpty
                                        ? Icons.restaurant_menu
                                        : Icons.search_off,
                                    title: query.isEmpty
                                        ? 'No products yet'
                                        : 'No matches',
                                    subtitle: query.isEmpty
                                        ? 'Upload your menu in Settings to get started.'
                                        : 'Try another name or clear your search.',
                                  )
                                : LayoutBuilder(
                                    builder: (context, space) {
                                      if (phone) {
                                        return ListView.separated(
                                          key: const ValueKey(
                                            'mobile-products',
                                          ),
                                          controller: _productsScroll,
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          itemCount: products.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 8),
                                          itemBuilder: (_, index) =>
                                              _OrderingProductCard(
                                                product: products[index],
                                                controller: controller,
                                                compact: true,
                                              ),
                                        );
                                      }
                                      final columns = space.maxWidth >= 920
                                          ? 4
                                          : space.maxWidth >= 650
                                          ? 3
                                          : 2;
                                      return GridView.builder(
                                        key: const ValueKey('desktop-products'),
                                        controller: _productsScroll,
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                          right: 2,
                                        ),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: columns,
                                              mainAxisExtent:
                                                  318 +
                                                  (MediaQuery.textScalerOf(
                                                            context,
                                                          ).scale(14) -
                                                          14) *
                                                      5,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                            ),
                                        itemCount: products.length,
                                        itemBuilder: (_, index) =>
                                            _OrderingProductCard(
                                              product: products[index],
                                              controller: controller,
                                              compact: false,
                                            ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    if (desktop) ...[
                      const SizedBox(width: 20),
                      SizedBox(
                        width: constraints.maxWidth >= 1250 ? 340 : 304,
                        child: _CurrentOrderPanel(controller: controller),
                      ),
                    ],
                  ],
                ),
              ),
              if (!desktop) _StickyOrderBar(controller: controller),
            ],
          ),
        );
      },
    ),
  );
}

class _OrderingProductCard extends StatelessWidget {
  const _OrderingProductCard({
    required this.product,
    required this.controller,
    required this.compact,
  });
  final Product product;
  final CoffeePosController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lines = controller.cart
        .where((item) => item.product.id == product.id)
        .toList();
    final quantity = lines.fold<int>(0, (sum, item) => sum + item.quantity);
    final configurable = controller
        .modifierGroupsForProduct(product)
        .isNotEmpty;
    final enabled = product.isAvailable && !controller.isCheckingOut;
    final add = enabled
        ? () => _addMenuProduct(context, controller, product)
        : null;
    final name = Tooltip(
      message: product.name,
      child: Text(
        product.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 13 : 15,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
    );
    final description = Text(
      product.description,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: compact ? 10 : 12, height: 1.4, color: _muted),
    );
    final price = Text(
      _menuMoney(controller, product.price),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 13 : 17,
        color: _ink,
        fontWeight: FontWeight.w800,
      ),
    );
    final availability = Text(
      product.isAvailable
          ? (configurable ? 'Options available' : 'Available')
          : 'Unavailable',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        color: product.isAvailable ? const Color(0xFF687C61) : _coral,
      ),
    );
    final action = quantity == 0
        ? SizedBox(
            height: 44,
            child: FilledButton(
              key: ValueKey('add-${product.id}'),
              onPressed: add,
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: compact
                  ? const Icon(Icons.add, size: 22)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20),
                        SizedBox(width: 6),
                        Text('Add'),
                      ],
                    ),
            ),
          )
        : _OrderQuantityControl(
            quantity: quantity,
            label: product.name,
            onIncrement: add,
            onDecrement: controller.isCheckingOut
                ? null
                : () {
                    if (lines.length == 1) {
                      final item = lines.single;
                      controller.setCartItemQuantity(
                        item.lineId!,
                        item.quantity - 1,
                      );
                    } else {
                      _showVariantLines(context, controller, product);
                    }
                  },
          );
    return Material(
      color: product.isAvailable ? Colors.white : const Color(0xFFF4F0EB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: quantity > 0 ? _coral.withValues(alpha: .55) : _line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: add,
        child: compact
            ? Padding(
                padding: const EdgeInsets.all(9),
                child: LayoutBuilder(
                  builder: (context, size) {
                    // The narrowest phones keep the stepper under the description so its
                    // touch targets never squeeze the product name out of the row.
                    final narrow = quantity > 0 && size.maxWidth < 275;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProductImage(
                              product: product,
                              width: narrow ? 42 : 58,
                              height: narrow ? 52 : 66,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  name,
                                  const SizedBox(height: 4),
                                  description,
                                  const SizedBox(height: 4),
                                  availability,
                                ],
                              ),
                            ),
                            if (!narrow) ...[
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  price,
                                  const SizedBox(height: 6),
                                  action,
                                ],
                              ),
                            ],
                          ],
                        ),
                        if (narrow) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: price),
                              const SizedBox(width: 4),
                              action,
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        _ProductImage(
                          product: product,
                          height: 98,
                          width: double.infinity,
                        ),
                        if (quantity > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _coral,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$quantity in order',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    name,
                    const SizedBox(height: 5),
                    description,
                    const Spacer(),
                    availability,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: price),
                        if (configurable)
                          const Icon(Icons.tune, size: 16, color: _muted),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: action),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.product,
    required this.width,
    required this.height,
  });
  final Product product;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: const Color(0xFFF4EEE6),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: const Color(0xFFC8B5A2),
          size: height > 70 ? 32 : 23,
        ),
      ),
    );
    final url = product.imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null || url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : placeholder,
              ),
      ),
    );
  }
}

class _OrderQuantityControl extends StatelessWidget {
  const _OrderQuantityControl({
    required this.quantity,
    required this.label,
    this.onIncrement,
    this.onDecrement,
  });
  final int quantity;
  final String label;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFFFBEEE9),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Decrease $label',
          onPressed: onDecrement,
          icon: const Icon(Icons.remove, size: 18),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          color: _coral,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '$quantity',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _ink,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Increase $label',
          onPressed: onIncrement,
          icon: const Icon(Icons.add, size: 18),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          color: _coral,
        ),
      ],
    ),
  );
}

class _CurrentOrderPanel extends StatelessWidget {
  const _CurrentOrderPanel({required this.controller});
  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.checkoutSummary;
    return Container(
      key: const ValueKey('current-order'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: _coral,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Current Order',
                    style: TextStyle(
                      fontSize: 17,
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: controller.cart.isEmpty || controller.isCheckingOut
                      ? null
                      : controller.clearCart,
                  style: TextButton.styleFrom(
                    foregroundColor: _coral,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Expanded(
            child: controller.cart.isEmpty
                ? const _OrderingEmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Your order starts here',
                    subtitle: 'Tap Add on a product to start a ticket.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: _line),
                    ),
                    itemBuilder: (_, index) => _OrderLine(
                      item: controller.cart[index],
                      controller: controller,
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Column(
              children: [
                _OrderAmount(
                  label: 'Subtotal',
                  value: _menuMoney(controller, summary.subtotal),
                ),
                if (summary.discount > 0)
                  _OrderAmount(
                    label: 'Discount',
                    value: '-${_menuMoney(controller, summary.discount)}',
                  ),
                if (summary.vatExemptionAmount > 0)
                  _OrderAmount(
                    label: 'VAT exemption',
                    value:
                        '-${_menuMoney(controller, summary.vatExemptionAmount)}',
                  ),
                if (summary.serviceCharge > 0)
                  _OrderAmount(
                    label: 'Service charge',
                    value: _menuMoney(controller, summary.serviceCharge),
                  ),
                const SizedBox(height: 6),
                _OrderAmount(
                  label: 'Total',
                  value: _menuMoney(controller, summary.total),
                  large: true,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed:
                        controller.cart.isEmpty || controller.isCheckingOut
                        ? null
                        : () => _showCheckout(context, controller),
                    style: FilledButton.styleFrom(
                      backgroundColor: _coral,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Proceed to Checkout',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
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
}

class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.item, required this.controller});
  final CartItem item;
  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(product: item.product, width: 42, height: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_menuMoney(controller, item.singleItemPrice)} each',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            height: 44,
            child: IconButton(
              tooltip: 'Remove ${item.product.name}',
              onPressed: controller.isCheckingOut
                  ? null
                  : () => controller.removeCartItem(item.lineId!),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close, size: 17, color: _muted),
            ),
          ),
        ],
      ),
      if (item.selectedModifiers.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            item.selectedModifiers
                .map((modifier) => modifier.label)
                .join(' · '),
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
      if (controller.modifierGroupsForProduct(item.product).isNotEmpty)
        SizedBox(
          height: 44,
          child: TextButton.icon(
            onPressed: controller.isCheckingOut
                ? null
                : () => _editOrderLine(context, controller, item),
            style: TextButton.styleFrom(
              foregroundColor: _coral,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.tune, size: 14),
            label: const Text('Edit options', style: TextStyle(fontSize: 11)),
          ),
        ),
      const SizedBox(height: 8),
      Row(
        children: [
          _OrderQuantityControl(
            quantity: item.quantity,
            label: '${item.product.name} in order',
            onIncrement: controller.isCheckingOut
                ? null
                : () => controller.setCartItemQuantity(
                    item.lineId!,
                    item.quantity + 1,
                  ),
            onDecrement: controller.isCheckingOut
                ? null
                : () => controller.setCartItemQuantity(
                    item.lineId!,
                    item.quantity - 1,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _menuMoney(controller, item.lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _OrderAmount extends StatelessWidget {
  const _OrderAmount({
    required this.label,
    required this.value,
    this.large = false,
  });
  final String label;
  final String value;
  final bool large;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: large ? 17 : 12,
              color: large ? _ink : _muted,
              fontWeight: large ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: large ? 23 : 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StickyOrderBar extends StatelessWidget {
  const _StickyOrderBar({required this.controller});
  final CoffeePosController controller;
  @override
  Widget build(BuildContext context) {
    final count = controller.cart.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('sticky-order-bar'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count ${count == 1 ? 'item' : 'items'} in order',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    _menuMoney(controller, controller.checkoutSummary.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 2,
              child: FilledButton(
                onPressed: count == 0
                    ? null
                    : () => _showCurrentOrder(context, controller),
                style: FilledButton.styleFrom(
                  backgroundColor: _coral,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white54,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'View Order / Checkout',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderingEmptyState extends StatelessWidget {
  const _OrderingEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFFC8B5A2)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _ink,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

String _menuMoney(CoffeePosController controller, num amount) =>
    '${controller.currencySymbol}${amount.toStringAsFixed(2)}';

Future<void> _addMenuProduct(
  BuildContext context,
  CoffeePosController controller,
  Product product,
) async {
  if (!product.isAvailable || controller.isCheckingOut) return;
  if (controller.modifierGroupsForProduct(product).isEmpty) {
    controller.addProductToCart(product, selectedModifiers: const []);
    return;
  }
  final result = await _showProductCustomizer(
    context,
    controller: controller,
    product: product,
  );
  if (result == null || !context.mounted) return;
  final current = controller.productById(product.id);
  if (current == null || !current.isAvailable) return;
  controller.addProductToCart(
    current,
    selectedModifiers: result.selectedModifiers,
    quantity: result.quantity,
  );
}

Future<void> _editOrderLine(
  BuildContext context,
  CoffeePosController controller,
  CartItem item,
) async {
  final result = await _showProductCustomizer(
    context,
    controller: controller,
    product: item.product,
    initialItem: item,
  );
  if (result == null || !context.mounted) return;
  controller.updateCartItemModifiers(item.lineId!, result.selectedModifiers);
  controller.setCartItemQuantity(item.lineId!, result.quantity);
}

Future<void> _showVariantLines(
  BuildContext context,
  CoffeePosController controller,
  Product product,
) => showDialog<void>(
  context: context,
  builder: (context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => AlertDialog(
      title: Text('Choose ${product.name} to change'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in controller.cart.where(
                (item) => item.product.id == product.id,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _OrderLine(item: item, controller: controller),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  ),
);

Future<void> _showCurrentOrder(
  BuildContext context,
  CoffeePosController controller,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  routeSettings: const RouteSettings(name: 'pos-current-order'),
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: _cream,
  builder: (context) => FractionallySizedBox(
    heightFactor: .92,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _CurrentOrderPanel(controller: controller),
      ),
    ),
  ),
);

Future<void> _showCheckout(
  BuildContext context,
  CoffeePosController controller,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  routeSettings: const RouteSettings(name: 'pos-checkout'),
  builder: (context) => Dialog(
    backgroundColor: _cream,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Checkout',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Back to order',
                    onPressed: controller.isCheckingOut
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              CheckoutDiscountSelector(controller: controller),
              _CheckoutForm(controller: controller),
            ],
          ),
        ),
      ),
    ),
  ),
);

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  @override
  Widget build(BuildContext context) => _OrderQuantityControl(
    quantity: quantity,
    label: 'Customization quantity',
    onIncrement: onIncrement,
    onDecrement: onDecrement,
  );
}

class _CartCustomizationResult {
  const _CartCustomizationResult({
    required this.quantity,
    required this.selectedModifiers,
  });

  final int quantity;
  final List<SelectedModifier> selectedModifiers;
}

Future<_CartCustomizationResult?> _showProductCustomizer(
  BuildContext context, {
  required CoffeePosController controller,
  required Product product,
  CartItem? initialItem,
}) async {
  final groups = controller.modifierGroupsForProduct(product);
  final initialSelection = <String, Set<String>>{};
  final initialModifiers =
      initialItem?.selectedModifiers ?? const <SelectedModifier>[];
  for (final group in groups) {
    final selectedForGroup = initialModifiers
        .where((modifier) => modifier.groupId == group.id)
        .map((modifier) => modifier.optionId)
        .toSet();
    if (selectedForGroup.isNotEmpty) {
      initialSelection[group.id] = selectedForGroup;
      continue;
    }
    final defaults = group.options
        .where((option) => option.isDefault)
        .map((option) => option.id)
        .toSet();
    for (final option in group.options) {
      if (defaults.length >= group.minSelected) break;
      defaults.add(option.id);
    }
    initialSelection[group.id] = group.maxSelected > 0
        ? defaults.take(group.maxSelected).toSet()
        : defaults;
  }

  var quantity = initialItem?.quantity ?? 1;
  final result = await showDialog<_CartCustomizationResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final selected = <String, Set<String>>{
        for (final entry in initialSelection.entries)
          entry.key: {...entry.value},
      };

      return StatefulBuilder(
        builder: (context, setState) {
          List<SelectedModifier> buildSelectedModifiers() {
            final modifiers = <SelectedModifier>[];
            for (final group in groups) {
              final groupSelection = selected[group.id] ?? <String>{};
              for (final option in group.options) {
                if (!groupSelection.contains(option.id)) {
                  continue;
                }
                final isDefault =
                    option.isDefault ||
                    (group.minSelected > 0 &&
                        group.options.first.id == option.id &&
                        option.priceDelta == 0);
                modifiers.add(
                  SelectedModifier(
                    groupId: group.id,
                    optionId: option.id,
                    label: option.name,
                    priceDelta: option.priceDelta,
                    isDefault: isDefault,
                  ),
                );
              }
            }
            return modifiers;
          }

          final valid = groups.every((group) {
            final count = selected[group.id]?.length ?? 0;
            return count >= group.minSelected &&
                (group.maxSelected == 0 || count <= group.maxSelected);
          });
          return AlertDialog(
            title: Text(
              initialItem == null
                  ? 'Customize ${product.name}'
                  : 'Edit add-ons',
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _menuMoney(controller, product.price),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Quantity',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        _QuantityStepper(
                          quantity: quantity,
                          onIncrement: () => setState(() => quantity += 1),
                          onDecrement: () {
                            if (quantity <= 1) {
                              return;
                            }
                            setState(() => quantity -= 1);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (groups.isEmpty)
                      Text(
                        'No add-ons available for this item.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ...groups.map((group) {
                        final groupSelection = selected[group.id] ?? <String>{};
                        final isSingleChoice = group.maxSelected == 1;
                        final helperText = group.selectionRuleLabel;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      group.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      helperText,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: group.options
                                    .map((option) {
                                      final isSelected = groupSelection
                                          .contains(option.id);
                                      if (isSingleChoice) {
                                        return ChoiceChip(
                                          label: Text(
                                            '${option.name}${option.priceDelta > 0 ? ' +${_menuMoney(controller, option.priceDelta)}' : ''}',
                                          ),
                                          selected: isSelected,
                                          onSelected: (_) {
                                            setState(() {
                                              if (group.minSelected == 0 && isSelected) {
                                                selected[group.id] = <String>{};
                                              } else {
                                                selected[group.id] = <String>{
                                                  option.id,
                                                };
                                              }
                                            });
                                          },
                                        );
                                      }
                                      return FilterChip(
                                        label: Text(
                                          '${option.name}${option.priceDelta > 0 ? ' +${_menuMoney(controller, option.priceDelta)}' : ''}',
                                        ),
                                        selected: isSelected,
                                        onSelected: (_) {
                                          setState(() {
                                            final next = <String>{
                                              ...groupSelection,
                                            };
                                            if (isSelected) {
                                              if (next.length <=
                                                  group.minSelected) {
                                                return;
                                              }
                                              next.remove(option.id);
                                            } else {
                                              if (group.maxSelected > 0 &&
                                                  next.length >=
                                                      group.maxSelected) {
                                                return;
                                              }
                                              next.add(option.id);
                                            }
                                            selected[group.id] = next;
                                          });
                                        },
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                            ],
                          ),
                        );
                      }),
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
                onPressed: !valid
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop(
                          _CartCustomizationResult(
                            quantity: quantity,
                            selectedModifiers: buildSelectedModifiers(),
                          ),
                        );
                      },
                child: Text(
                  initialItem == null ? 'Add to cart' : 'Update item',
                ),
              ),
            ],
          );
        },
      );
    },
  );
  return result;
}

class _CheckoutForm extends StatefulWidget {
  const _CheckoutForm({required this.controller});
  final CoffeePosController controller;
  @override
  State<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends State<_CheckoutForm> {
  late final _cash = TextEditingController(
    text: widget.controller.cashReceived == 0
        ? ''
        : widget.controller.cashReceived.toStringAsFixed(2),
  );
  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final summary = controller.checkoutSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in ['Dine-in', 'Take-out'])
              ChoiceChip(
                label: Text(type),
                selected: controller.orderType == type,
                onSelected: controller.isCheckingOut
                    ? null
                    : (_) => controller.updateOrderType(type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment method',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in PaymentType.values)
              ChoiceChip(
                label: Text(switch (type) {
                  PaymentType.card => 'Card',
                  PaymentType.cash => 'Cash',
                  PaymentType.eWallet => 'eWallet',
                }),
                selected: controller.paymentType == type,
                onSelected: controller.isCheckingOut
                    ? null
                    : (_) => controller.updatePaymentType(type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _OrderAmount(
          label: 'Subtotal',
          value: _menuMoney(controller, summary.subtotal),
        ),
        if (summary.vatEnabled)
          _OrderAmount(
            label: 'VAT (included)',
            value: _menuMoney(controller, summary.tax),
          ),
        if (summary.vatExemptionAmount > 0)
          _OrderAmount(
            label: 'VAT exemption',
            value: '-${_menuMoney(controller, summary.vatExemptionAmount)}',
          ),
        if (summary.discount > 0)
          _OrderAmount(
            label: 'Discount',
            value: '-${_menuMoney(controller, summary.discount)}',
          ),
        if (summary.serviceCharge > 0)
          _OrderAmount(
            label: 'Service charge',
            value: _menuMoney(controller, summary.serviceCharge),
          ),
        const Divider(height: 24),
        _OrderAmount(
          label: 'Total',
          value: _menuMoney(controller, summary.total),
          large: true,
        ),
        if (controller.paymentType == PaymentType.cash) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _cash,
            enabled: !controller.isCheckingOut,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cash received',
              prefixText: '${controller.currencySymbol} ',
              border: const OutlineInputBorder(),
            ),
            onChanged: (text) =>
                controller.updateCashReceived(double.tryParse(text) ?? 0),
          ),
          const SizedBox(height: 8),
          Text(
            controller.cashReceived < summary.total
                ? 'Amount remaining: ${_menuMoney(controller, summary.total - controller.cashReceived)}'
                : 'Change: ${_menuMoney(controller, summary.change)}',
            style: const TextStyle(color: _muted),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: !controller.canCheckout
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(
                      context,
                      rootNavigator: true,
                    );
                    final order = await controller.checkout();
                    if (order != null && navigator.mounted) {
                      // Close only the completed ticket's routes, before printing.
                      navigator.popUntil(
                        (route) =>
                            route.settings.name != 'pos-checkout' &&
                            route.settings.name != 'pos-current-order',
                      );
                      await _handlePostCheckoutPrinting(
                        context: navigator.context,
                        messenger: messenger,
                        controller: controller,
                        order: order,
                      );
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              foregroundColor: Colors.white,
            ),
            child: Text(
              controller.isCheckingOut
                  ? 'Processing…'
                  : 'Charge ${_menuMoney(controller, summary.total)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _handlePostCheckoutPrinting({
  required BuildContext context,
  required ScaffoldMessengerState messenger,
  required CoffeePosController controller,
  required OrderRecord order,
}) async {
  if (controller.autoPrintReceipts) {
    try {
      final result = await controller.printOrderPackage(order);
      if (result.isSuccess) {
        showAutoHidingSnackBar(
          messenger: messenger,
          content: Text(
            'Order #${order.orderNumber} paid. Customer & kitchen copies sent to printer.',
          ),
          duration: const Duration(seconds: 5),
        );
        return;
      }

      final reason = result.status == receipt_printer.PrintStatus.canceled
          ? 'Print canceled.'
          : 'Unable to print receipt. Please check printer connection.';

      showAutoHidingSnackBar(
        messenger: messenger,
        content: Text('Order #${order.orderNumber} saved. $reason'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Print Preview',
          onPressed: () {
            controller.printOrderPackage(
              order,
              manualReprint: true,
              transportOverride: 'System dialog',
            );
          },
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Receipt print failed for ${order.id}: $error\n$stackTrace');
      showAutoHidingSnackBar(
        messenger: messenger,
        content: Text(
          'Order #${order.orderNumber} saved. Unable to print receipt. Please check printer connection.',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Print Preview',
          onPressed: () {
            controller.printOrderPackage(
              order,
              manualReprint: true,
              transportOverride: 'System dialog',
            );
          },
        ),
      );
    }
  } else {
    showAutoHidingSnackBar(
      messenger: messenger,
      content: Text('Saved Order #${order.orderNumber} as a paid order.'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Print',
        onPressed: () {
          controller.printOrderPackage(order, manualReprint: true);
        },
      ),
    );
  }
}

@visibleForTesting
Future<void> handlePostCheckoutPrintingForTesting({
  required BuildContext context,
  required ScaffoldMessengerState messenger,
  required CoffeePosController controller,
  required OrderRecord order,
}) => _handlePostCheckoutPrinting(
  context: context,
  messenger: messenger,
  controller: controller,
  order: order,
);
