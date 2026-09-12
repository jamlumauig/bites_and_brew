import 'package:flutter/material.dart';
import '../../domain/coffee_pos_models.dart';
import '../../state/coffee_pos_controller.dart';

class CashierDashboard extends StatelessWidget {
  const CashierDashboard({super.key, required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final splitLandscape =
            constraints.maxWidth >= 700 &&
            constraints.maxWidth > constraints.maxHeight;
        final wideDesktop = constraints.maxWidth >= 1200;
        final useTabletLandscape = splitLandscape && !wideDesktop;
        final useSplitLayout = wideDesktop || splitLandscape;
        if (useTabletLandscape) {
          return _TabletLandscapeCashierLayout(controller: controller);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              controller: controller,
              compact: splitLandscape || constraints.maxHeight < 700,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: useSplitLayout
                  ? Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _CatalogPanel(
                            controller: controller,
                            compactLandscape: splitLandscape,
                            expandGrid: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _CartPanel(
                            controller: controller,
                            compactLandscape: splitLandscape,
                          ),
                        ),
                      ],
                    )
                  : _MobileCashierBody(controller: controller),
            ),
          ],
        );
      },
    );
  }
}

class _TabletLandscapeCashierLayout extends StatelessWidget {
  const _TabletLandscapeCashierLayout({required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final isShortLandscape = size.height < 760;
        final horizontalPadding = size.width >= 1100 ? 14.0 : 12.0;
        final verticalPadding = isShortLandscape ? 8.0 : 10.0;
        final splitFlex = size.width >= 1400
            ? (7, 5)
            : size.width >= 1100
            ? (6, 5)
            : (3, 2);
        final gap = size.width >= 1300 ? 8.0 : 10.0;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF6E3D2), Color(0xFFFFF7F0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                left: -48,
                top: 46,
                child: _BackgroundOrb(size: 104, color: Color(0x44FFB08A)),
              ),
              const Positioned(
                right: -28,
                top: 112,
                child: _BackgroundOrb(size: 118, color: Color(0x42F58B6F)),
              ),
              const Positioned(
                left: 158,
                top: 108,
                child: _BackgroundOrb(size: 388, color: Color(0x1FE98E78)),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TabletLandscapeHeader(controller: controller),
                      SizedBox(height: isShortLandscape ? 6 : 8),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: splitFlex.$1,
                              child: _CatalogPanel(
                                controller: controller,
                                compactLandscape: true,
                                expandGrid: true,
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              flex: splitFlex.$2,
                              child: _CartPanel(
                                controller: controller,
                                compactLandscape: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _TabletLandscapeHeader extends StatelessWidget {
  const _TabletLandscapeHeader({required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    final scale = _tabletTextScale(context, max: 0.84);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Products & Cart',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize:
                          (Theme.of(
                                context,
                              ).textTheme.headlineMedium?.fontSize ??
                              28) *
                          scale,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFBFC6CD),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _TabletStatusStrip(
          todaySales: controller.todaySales,
          openOrders: controller.recentOrders.length,
          activeShifts: controller.activeShifts.length,
          scale: scale,
        ),
      ],
    );
  }
}

class _TabletStatusStrip extends StatelessWidget {
  const _TabletStatusStrip({
    required this.todaySales,
    required this.openOrders,
    required this.activeShifts,
    required this.scale,
  });

  final double todaySales;
  final int openOrders;
  final int activeShifts;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale.clamp(0.9, 1.0),
        vertical: 7 * scale.clamp(0.9, 1.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14926C55)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x10000000),
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 7 * scale.clamp(0.9, 1.0),
            height: 7 * scale.clamp(0.9, 1.0),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF07A4D),
            ),
          ),
          SizedBox(width: 8 * scale.clamp(0.9, 1.0)),
          Expanded(
            child: Text(
              'Open now',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10 * scale,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6D5548),
              ),
            ),
          ),
          _StripMetric(label: 'Orders', value: '$openOrders', scale: scale),
          _StripDot(scale: scale),
          _StripMetric(label: 'Shifts', value: '$activeShifts', scale: scale),
          _StripDot(scale: scale),
          _StripMetric(
            label: 'Sales',
            value: _money(todaySales),
            scale: scale,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _StripMetric extends StatelessWidget {
  const _StripMetric({
    required this.label,
    required this.value,
    required this.scale,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final double scale;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 1 * scale.clamp(0.9, 1.0)),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 8.5 * scale,
                color: const Color(0xFF8D7767),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: (emphasized ? 10.5 : 9.5) * scale,
                color: const Color(0xFF31271F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StripDot extends StatelessWidget {
  const _StripDot({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale.clamp(0.9, 1.0)),
      child: Container(
        width: 3 * scale.clamp(0.9, 1.0),
        height: 3 * scale.clamp(0.9, 1.0),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x3A9A7A60),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.compact});

  final CoffeePosController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 220 : 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Haven & Co. cashier',
                style: compact
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Fast product selection, visible totals, and clean order snapshots.',
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.brown.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        _StatChip(
          label: 'Today sales',
          value: _money(controller.todaySales),
          compactLandscape: compact,
        ),
        _StatChip(
          label: 'Open orders',
          value: '${controller.recentOrders.length}',
          compactLandscape: compact,
        ),
        _StatChip(
          label: 'Active shifts',
          value: '${controller.activeShifts.length}',
          compactLandscape: compact,
        ),
      ],
    );
  }
}

class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({
    required this.controller,
    required this.compactLandscape,
    required this.expandGrid,
  });

  final CoffeePosController controller;
  final bool compactLandscape;
  final bool expandGrid;

  @override
  Widget build(BuildContext context) {
    if (compactLandscape) {
      return _LandscapeMenuPanel(controller: controller);
    }
    return Card(
      color: const Color(0xFFFCF8F2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compactLandscape ? 28 : 30),
        side: const BorderSide(color: Color(0x1A9A7A60)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compactLandscape ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeading(
              title: 'Menu',
              subtitle: compactLandscape
                  ? 'Quick tap-to-add menu.'
                  : 'Tap-to-add products with modifiers and quick categories.',
              trailing: TextButton.icon(
                onPressed: () => _openQuickSearch(context, controller),
                icon: const Icon(Icons.search),
                label: const Text('Quick search'),
              ),
            ),
            SizedBox(height: compactLandscape ? 10 : 16),
            SizedBox(
              height: compactLandscape ? 48 : 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final category = controller.cashierCategories[index];
                  final selected = controller.selectedCategoryIndex == index;
                  return ChoiceChip(
                    avatar: Icon(_categoryIconData(category), size: 18),
                    label: Text(category.name),
                    selected: selected,
                    onSelected: (_) => controller.selectCategory(index),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemCount: controller.cashierCategories.length,
              ),
            ),
            SizedBox(height: compactLandscape ? 10 : 18),
            expandGrid
                ? Expanded(
                    child: _ProductGrid(
                      controller: controller,
                      compactLandscape: compactLandscape,
                      scrollable: true,
                    ),
                  )
                : _ProductGrid(
                    controller: controller,
                    compactLandscape: compactLandscape,
                    scrollable: false,
                  ),
          ],
        ),
      ),
    );
  }
}

void _openQuickSearch(BuildContext context, CoffeePosController controller) {
  showSearch<Product?>(
    context: context,
    delegate: _ProductSearchDelegate(controller),
  );
}

class _ProductSearchDelegate extends SearchDelegate<Product?> {
  _ProductSearchDelegate(this.controller)
    : super(
        searchFieldLabel: 'Search products',
        keyboardType: TextInputType.text,
      );

  final CoffeePosController controller;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear search',
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Close search',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final products = controller.products
        .where((product) {
          if (normalizedQuery.isEmpty) return true;
          final category = _categoryName(product.categoryId).toLowerCase();
          return product.name.toLowerCase().contains(normalizedQuery) ||
              category.contains(normalizedQuery) ||
              product.description.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    if (products.isEmpty) {
      return const Center(child: Text('No matching products.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          tileColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFFFE0CC),
            child: Text(product.badge.isEmpty ? '☕' : product.badge),
          ),
          title: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_categoryName(product.categoryId)}  •  ${_money(product.price)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () {
            controller.addProduct(product);
            close(context, product);
          },
        );
      },
    );
  }

  String _categoryName(String categoryId) {
    for (final category in controller.categories) {
      if (category.id == categoryId) return category.name;
    }
    return 'Product';
  }
}

class _LandscapeMenuPanel extends StatelessWidget {
  const _LandscapeMenuPanel({required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    final products = controller.visibleProducts;

    return Card(
      color: const Color(0xFFFDF8F4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(36),
        side: const BorderSide(color: Color(0x24C58E6A)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          children: [
            Positioned(
              left: -132,
              top: -132,
              child: _BackgroundOrb(size: 290, color: const Color(0x18F6A57D)),
            ),
            Positioned(
              right: -118,
              top: 192,
              child: _BackgroundOrb(size: 236, color: const Color(0x1FF39A4E)),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LandscapeMenuHeader(controller: controller),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            top: 30,
                            child: products.isEmpty
                                ? const _LandscapeMenuEmptyState()
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final availableWidth =
                                          constraints.maxWidth;
                                      final crossAxisCount =
                                          availableWidth >= 1140
                                          ? 4
                                          : availableWidth >= 840
                                          ? 3
                                          : 2;
                                      final spacing = availableWidth >= 1000
                                          ? 6.0
                                          : 5.0;
                                      final tileWidth =
                                          (availableWidth -
                                              (spacing *
                                                  (crossAxisCount - 1))) /
                                          crossAxisCount;
                                      final tileHeight = availableWidth >= 1000
                                          ? 176.0
                                          : 150.0;
                                      final childAspectRatio =
                                          tileWidth / tileHeight;
                                      return GridView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                          0,
                                          14,
                                          0,
                                          6,
                                        ),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: crossAxisCount,
                                              mainAxisSpacing: spacing,
                                              crossAxisSpacing: spacing,
                                              childAspectRatio:
                                                  childAspectRatio,
                                            ),
                                        itemCount: products.length,
                                        itemBuilder: (context, index) {
                                          final product = products[index];
                                          final quantity = _cartQuantityFor(
                                            controller.cart,
                                            product.id,
                                          );
                                          return _LandscapeMenuSquareCard(
                                            product: product,
                                            quantity: quantity,
                                            active:
                                                controller.activeProductId ==
                                                product.id,
                                            onTap: () async {
                                              final result =
                                                  await _showProductCustomizer(
                                                    context,
                                                    controller: controller,
                                                    product: product,
                                                  );
                                              if (result == null ||
                                                  !context.mounted) {
                                                return;
                                              }
                                              controller.addProductToCart(
                                                product,
                                                selectedModifiers:
                                                    result.selectedModifiers,
                                                quantity: result.quantity,
                                              );
                                            },
                                            onIncrement: () =>
                                                controller.setCartQuantity(
                                                  product.id,
                                                  quantity + 1,
                                                ),
                                            onDecrement: () =>
                                                controller.setCartQuantity(
                                                  product.id,
                                                  quantity - 1,
                                                ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: _LandscapeCategoryStrip(
                              controller: controller,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
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

class _LandscapeMenuHeader extends StatelessWidget {
  const _LandscapeMenuHeader({required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    final scale = _tabletTextScale(context, max: 0.84);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x26B37A55)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                color: Color(0x1F000000),
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.menu, size: 20, color: Color(0xFF6A4A34)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Products',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize:
                      (Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) *
                      scale,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A352B),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                controller.selectedCategory?.name ?? 'Products',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize:
                      (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
                      scale,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB48765),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _openQuickSearch(context, controller),
          icon: const Icon(Icons.search),
        ),
      ],
    );
  }
}

class _LandscapeCategoryStrip extends StatelessWidget {
  const _LandscapeCategoryStrip({required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x26C19B7C)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 26,
            color: Color(0x1E000000),
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: controller.cashierCategories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = controller.cashierCategories[index];
          final selected = controller.selectedCategoryIndex == index;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => controller.selectCategory(index),
            label: Text(category.name),
            avatar: Icon(_categoryIconData(category), size: 16),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF6E5847),
            ),
            backgroundColor: const Color(0xFFF6E7DD),
            selectedColor: const Color(0xFFF25C54),
            side: selected
                ? BorderSide.none
                : const BorderSide(color: Color(0x22B37A55)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

class _LandscapeMenuSquareCard extends StatelessWidget {
  const _LandscapeMenuSquareCard({
    required this.product,
    required this.quantity,
    required this.active,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Product product;
  final int quantity;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final accent = _productAccent(product.categoryId);
    final displayQuantity = quantity > 0 ? quantity : 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactTile =
            constraints.maxHeight < 100 || constraints.maxWidth < 180;
        final scale = _tabletTextScale(context, max: compactTile ? 0.84 : 0.88);
        final imageSize = compactTile ? 38.0 : 68.0;
        final radius = compactTile ? 16.0 : 20.0;
        final innerPadding = compactTile ? 5.0 : 7.0;
        return InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(innerPadding),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFFEFE7) : const Color(0xFFFFFCFA),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: active
                    ? const Color(0xFFE76F55)
                    : const Color(0x28BF8E71),
                width: active ? 1.4 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 22,
                  color: Color(0x1E000000),
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: compactTile
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _MenuArtwork(
                        product: product,
                        size: imageSize,
                        accent: accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize:
                                        (Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.fontSize ??
                                            12) *
                                        scale,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF222222),
                                  ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _money(product.price),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontSize:
                                              (Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.fontSize ??
                                                  12) *
                                              scale,
                                          color: const Color(0xFFF14F43),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (displayQuantity == 0)
                                  TextButton(
                                    onPressed: onTap,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFF14F43),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      side: const BorderSide(
                                        color: Color(0x28D65E50),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('ADD'),
                                  )
                                else
                                  _QuantityStepper(
                                    quantity: displayQuantity,
                                    onIncrement: onIncrement,
                                    onDecrement: onDecrement,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Center(
                          child: _MenuArtwork(
                            product: product,
                            size: imageSize,
                            accent: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize:
                              (Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.fontSize ??
                                  14) *
                              scale,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        product.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize:
                              (Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.fontSize ??
                                  12) *
                              scale,
                          height: 1.0,
                          color: const Color(0xFF847A80),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _money(product.price),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.fontSize ??
                                          14) *
                                      scale,
                                  color: const Color(0xFFF14F43),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          if (displayQuantity == 0)
                            TextButton.icon(
                              onPressed: onTap,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFF14F43),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                side: const BorderSide(
                                  color: Color(0x28D65E50),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 12),
                              label: const Text('ADD'),
                            )
                          else
                            _QuantityStepper(
                              quantity: displayQuantity,
                              onIncrement: onIncrement,
                              onDecrement: onDecrement,
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

class _MenuArtwork extends StatelessWidget {
  const _MenuArtwork({
    required this.product,
    required this.size,
    required this.accent,
  });

  final Product product;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.98),
            Color.lerp(accent, Colors.white, 0.28) ?? accent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            color: Color(0x26000000),
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.local_cafe_outlined,
              size: size * 0.34,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF6EF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E9DF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: Icons.remove, onTap: onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$quantity',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3C3C3C),
              ),
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: const Color(0xFF6A6F7A)),
        ),
      ),
    );
  }
}

class _LandscapeMenuEmptyState extends StatelessWidget {
  const _LandscapeMenuEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No products found in this category.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8A7A6B)),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.controller,
    required this.compactLandscape,
    required this.scrollable,
  });

  final CoffeePosController controller;
  final bool compactLandscape;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final crossAxisCount = compactLandscape
            ? (availableWidth >= 780 ? 3 : 2)
            : availableWidth >= 1200
            ? 3
            : availableWidth >= 720
            ? 2
            : 1;
        final aspectRatio = compactLandscape ? 1.28 : 1.15;
        return GridView.builder(
          shrinkWrap: !scrollable,
          physics: scrollable
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: compactLandscape ? 10 : 14,
            crossAxisSpacing: compactLandscape ? 10 : 14,
            childAspectRatio: aspectRatio,
          ),
          itemCount: controller.visibleProducts.length,
          itemBuilder: (context, index) {
            final product = controller.visibleProducts[index];
            final active = controller.activeProductId == product.id;
            return _ProductCard(
              product: product,
              active: active,
              compactLandscape: compactLandscape,
              onTap: () => controller.addProduct(product),
              onDetails: () => controller.selectProduct(product.id),
            );
          },
        );
      },
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.controller, required this.compactLandscape});

  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final summary = controller.checkoutSummary;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final denseRows = compactLandscape && height < 720;
        final ultraDenseRows = compactLandscape && height < 620;
        final padding = EdgeInsets.all(
          width >= 520
              ? (denseRows ? 6 : 10)
              : width >= 420
              ? 8
              : 7,
        );
        final radius = width >= 520
            ? (denseRows ? 22.0 : 26.0)
            : width >= 420
            ? 24.0
            : 22.0;
        final sectionGap = denseRows
            ? 2.0
            : height >= 620
            ? 8.0
            : 6.0;
        final dividerGap = denseRows
            ? 3.0
            : height >= 620
            ? 10.0
            : 8.0;
        return Card(
          color: const Color(0xFFFCF8F2),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: Color(0x1A9A7A60)),
          ),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                _PanelHeading(
                  title: 'Cart',
                  subtitle: compactLandscape
                      ? 'Compact landscape view.'
                      : 'Checkout total stays visible while items change.',
                  trailing: TextButton(
                    onPressed: controller.cart.isEmpty
                        ? null
                        : controller.clearCart,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                SizedBox(height: sectionGap),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (controller.cart.isEmpty)
                        _EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No items yet',
                          subtitle: compactLandscape
                              ? 'Add items to build a ticket.'
                              : 'Add coffee, drinks, or snacks to start a ticket.',
                        )
                      else
                        ...List<Widget>.generate(controller.cart.length, (
                          index,
                        ) {
                          final item = controller.cart[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == controller.cart.length - 1
                                  ? 0
                                  : dividerGap,
                            ),
                            child: _CartItemTile(
                              item: item,
                              compactLandscape: true,
                              dense: denseRows,
                              ultraDense: ultraDenseRows,
                              onCustomize: () async {
                                final result = await _showProductCustomizer(
                                  context,
                                  controller: controller,
                                  product: item.product,
                                  initialItem: item,
                                );
                                if (result == null || !context.mounted) {
                                  return;
                                }
                                controller.updateCartItemModifiers(
                                  item.lineId ?? item.product.id,
                                  result.selectedModifiers,
                                );
                                controller.setCartItemQuantity(
                                  item.lineId ?? item.product.id,
                                  result.quantity,
                                );
                              },
                              onIncrement: () => controller.setCartItemQuantity(
                                item.lineId ?? item.product.id,
                                item.quantity + 1,
                              ),
                              onDecrement: () => controller.setCartItemQuantity(
                                item.lineId ?? item.product.id,
                                item.quantity - 1,
                              ),
                              onRemove: () => controller.removeCartItem(
                                item.lineId ?? item.product.id,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _SummaryCard(
                  summary: summary,
                  controller: controller,
                  compactLandscape: compactLandscape,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileCashierBody extends StatelessWidget {
  const _MobileCashierBody({required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 140),
          children: [
            _CatalogPanel(
              controller: controller,
              compactLandscape: false,
              expandGrid: false,
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _BottomCartBar(controller: controller),
        ),
      ],
    );
  }
}

class _BottomCartBar extends StatelessWidget {
  const _BottomCartBar({required this.controller});

  final CoffeePosController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.checkoutSummary;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              blurRadius: 22,
              color: Color(0x22000000),
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${controller.cart.length} items',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _money(summary.total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: controller.cart.isEmpty
                  ? null
                  : () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => DraggableScrollableSheet(
                          initialChildSize: 0.82,
                          minChildSize: 0.55,
                          maxChildSize: 0.95,
                          builder: (context, scrollController) {
                            return _MobileCartSheet(
                              controller: controller,
                              scrollController: scrollController,
                            );
                          },
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Open cart'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCartSheet extends StatelessWidget {
  const _MobileCartSheet({
    required this.controller,
    required this.scrollController,
  });

  final CoffeePosController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.brown.shade200,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: controller.cart.length,
                itemBuilder: (context, index) {
                  final item = controller.cart[index];
                  return _CartItemTile(
                    item: item,
                    compactLandscape: false,
                    dense: false,
                    ultraDense: false,
                    onCustomize: () async {
                      final result = await _showProductCustomizer(
                        context,
                        controller: controller,
                        product: item.product,
                        initialItem: item,
                      );
                      if (result == null || !context.mounted) {
                        return;
                      }
                      controller.updateCartItemModifiers(
                        item.lineId ?? item.product.id,
                        result.selectedModifiers,
                      );
                      controller.setCartItemQuantity(
                        item.lineId ?? item.product.id,
                        result.quantity,
                      );
                    },
                    onIncrement: () => controller.setCartItemQuantity(
                      item.lineId ?? item.product.id,
                      item.quantity + 1,
                    ),
                    onDecrement: () => controller.setCartItemQuantity(
                      item.lineId ?? item.product.id,
                      item.quantity - 1,
                    ),
                    onRemove: () => controller.removeCartItem(
                      item.lineId ?? item.product.id,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _SummaryCard(
              summary: controller.checkoutSummary,
              controller: controller,
              compactLandscape: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.active,
    required this.compactLandscape,
    required this.onTap,
    required this.onDetails,
  });

  final Product product;
  final bool active;
  final bool compactLandscape;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(compactLandscape ? 10 : 16),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF6EE) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: active ? const Color(0xFFD08A5D) : const Color(0x1E9A7A60),
            width: active ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              color: Color(0x12000000),
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: compactLandscape
            ? _CompactProductCard(product: product, onDetails: onDetails)
            : _RichProductCard(product: product, onDetails: onDetails),
      ),
    );
  }
}

class _RichProductCard extends StatelessWidget {
  const _RichProductCard({required this.product, required this.onDetails});

  final Product product;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final imageHeight = compact ? 56.0 : 104.0;
        final titleStyle = compact
            ? Theme.of(context).textTheme.titleSmall
            : Theme.of(context).textTheme.titleMedium;
        final priceStyle = Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: imageHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.brown.shade100, Colors.orange.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_cafe_outlined,
                    size: 36,
                    color: Color(0xFF7A4E2D),
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              product.name,
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                product.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.brown.shade700),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _money(product.price),
                    style: priceStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onDetails,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    product.badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CompactProductCard extends StatelessWidget {
  const _CompactProductCard({required this.product, required this.onDetails});

  final Product product;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.brown.shade100, Colors.orange.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                color: Color(0x10000000),
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_cafe_outlined,
            size: 24,
            color: Color(0xFF7A4E2D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _money(product.price),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.brown.shade800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: onDetails,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            product.badge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.compactLandscape,
    required this.dense,
    required this.ultraDense,
    required this.onCustomize,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final bool compactLandscape;
  final bool dense;
  final bool ultraDense;
  final VoidCallback onCustomize;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final labelStyle = dense
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.titleMedium;
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.brown.shade700,
      fontSize: ultraDense
          ? 10
          : dense
          ? 11
          : null,
    );
    final priceStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: ultraDense
          ? 11
          : dense
          ? 12
          : null,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackedActions = constraints.maxWidth < 430;

        final header = Row(
          children: [
            Expanded(
              child: Text(
                item.product.name,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: onCustomize,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.tune, size: ultraDense ? 14 : 15),
              label: Text(
                ultraDense ? 'Edit' : 'Add-ons',
                style: TextStyle(
                  fontSize: ultraDense
                      ? 9.5
                      : dense
                      ? 10.5
                      : 11,
                ),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: ultraDense
                    ? 22
                    : dense
                    ? 24
                    : 28,
                height: ultraDense
                    ? 22
                    : dense
                    ? 24
                    : 28,
              ),
              icon: Icon(
                Icons.close,
                size: ultraDense
                    ? 14
                    : dense
                    ? 15
                    : 16,
              ),
            ),
          ],
        );

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            SizedBox(
              height: ultraDense
                  ? 0
                  : dense
                  ? 1
                  : 3,
            ),
            Text(
              item.selectedModifiers.isEmpty
                  ? 'Default setup'
                  : item.selectedModifiers
                        .map((modifier) => modifier.label)
                        .join(' • '),
              maxLines: ultraDense
                  ? 1
                  : dense
                  ? 1
                  : compactLandscape
                  ? 2
                  : 3,
              overflow: TextOverflow.ellipsis,
              style: metaStyle,
            ),
            SizedBox(
              height: ultraDense
                  ? 1
                  : dense
                  ? 3
                  : 5,
            ),
            Text(_money(item.lineTotal), style: priceStyle),
          ],
        );

        final quantityControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: dense
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: ultraDense
                    ? 24
                    : dense
                    ? 26
                    : 30,
                height: ultraDense
                    ? 24
                    : dense
                    ? 26
                    : 30,
              ),
              onPressed: onDecrement,
              icon: Icon(
                Icons.remove_circle_outline,
                size: ultraDense
                    ? 16
                    : dense
                    ? 17
                    : 19,
              ),
            ),
            Text(
              '${item.quantity}',
              style: dense
                  ? Theme.of(context).textTheme.titleSmall
                  : Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              visualDensity: dense
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: ultraDense
                    ? 24
                    : dense
                    ? 26
                    : 30,
                height: ultraDense
                    ? 24
                    : dense
                    ? 26
                    : 30,
              ),
              onPressed: onIncrement,
              icon: Icon(
                Icons.add_circle_outline,
                size: ultraDense
                    ? 16
                    : dense
                    ? 17
                    : 19,
              ),
            ),
          ],
        );

        if (stackedActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [body, const SizedBox(height: 8), quantityControls],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: body),
            SizedBox(
              width: ultraDense
                  ? 4
                  : dense
                  ? 6
                  : 10,
            ),
            quantityControls,
          ],
        );
      },
    );
  }
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
  final groups = product.modifierGroupIds
      .map(controller.modifierGroupById)
      .whereType<ModifierGroup>()
      .toList(growable: false);
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
    if (group.minSelected > 0 && group.options.isNotEmpty) {
      initialSelection[group.id] = <String>{group.options.first.id};
    } else {
      initialSelection[group.id] = <String>{};
    }
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
                modifiers.add(
                  SelectedModifier(
                    groupId: group.id,
                    optionId: option.id,
                    label: option.name,
                    priceDelta: option.priceDelta,
                  ),
                );
              }
            }
            return modifiers;
          }

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
                      _money(product.price),
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
                        final isSingleChoice = group.maxSelected <= 1;
                        final helperText = group.maxSelected <= 0
                            ? 'Choose freely'
                            : group.maxSelected == 1
                            ? 'Select 1'
                            : 'Up to ${group.maxSelected}';
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
                                    ),
                                  ),
                                  Text(
                                    helperText,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                                            '${option.name}${option.priceDelta > 0 ? ' +${_money(option.priceDelta)}' : ''}',
                                          ),
                                          selected: isSelected,
                                          onSelected: (_) {
                                            setState(() {
                                              selected[group.id] = <String>{
                                                option.id,
                                              };
                                            });
                                          },
                                        );
                                      }
                                      return FilterChip(
                                        label: Text(
                                          '${option.name}${option.priceDelta > 0 ? ' +${_money(option.priceDelta)}' : ''}',
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
                onPressed: () {
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

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({
    required this.summary,
    required this.controller,
    required this.compactLandscape,
  });

  final CheckoutSummary summary;
  final CoffeePosController controller;
  final bool compactLandscape;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  late final TextEditingController _cashController;
  bool _showBreakdown = false;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(
      text: widget.controller.cashReceived == 0
          ? ''
          : widget.controller.cashReceived.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final controller = widget.controller;
    final size = MediaQuery.sizeOf(context);
    final denseLandscape = widget.compactLandscape && size.height < 720;
    final ultraDenseLandscape = widget.compactLandscape && size.height < 620;
    final scale = _tabletTextScale(context, max: denseLandscape ? 0.82 : 0.88);
    if (denseLandscape) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(ultraDenseLandscape ? 3 : 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F1E4),
          borderRadius: BorderRadius.circular(ultraDenseLandscape ? 18 : 20),
          border: Border.all(color: const Color(0x18A57A58)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              color: Color(0x10000000),
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Details',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showBreakdown = !_showBreakdown),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _showBreakdown
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(_showBreakdown ? 'Hide details' : 'Show details'),
                ),
              ],
            ),
            if (_showBreakdown) ...[
              const SizedBox(height: 3),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  _SummaryMiniStat(
                    label: 'Gross',
                    value: _money(summary.grossAmount),
                    width: ultraDenseLandscape ? 88 : 96,
                  ),
                  _SummaryMiniStat(
                    label: 'VATable',
                    value: _money(summary.vatableSales),
                    width: ultraDenseLandscape ? 88 : 96,
                  ),
                  _SummaryMiniStat(
                    label: 'VAT-free',
                    value: _money(summary.vatExemptSales),
                    width: ultraDenseLandscape ? 88 : 96,
                  ),
                  if (summary.vatExemptionAmount > 0)
                    _SummaryMiniStat(
                      label: 'VAT exempt',
                      value: _money(summary.vatExemptionAmount),
                      width: ultraDenseLandscape ? 88 : 96,
                    ),
                  _SummaryMiniStat(
                    label: 'Discount',
                    value: '-${_money(summary.discount)}',
                    width: ultraDenseLandscape ? 88 : 96,
                  ),
                  _SummaryMiniStat(
                    label: 'Tax',
                    value: _money(summary.tax),
                    width: ultraDenseLandscape ? 88 : 96,
                  ),
                  _SummaryMiniStat(
                    label: 'Svc chg',
                    value: _money(summary.serviceCharge),
                    width: ultraDenseLandscape ? 88 : 96,
                  ),
                ],
              ),
            ],
            SizedBox(height: ultraDenseLandscape ? 2 : 3),
            _OrderTypeToggle(
              orderType: controller.orderType,
              onChanged: controller.updateOrderType,
              compact: true,
            ),
            SizedBox(height: ultraDenseLandscape ? 2 : 3),
            _SummaryRow(
              label: 'Total',
              value: _money(summary.total),
              emphasized: true,
              compactLandscape: true,
              compact: true,
            ),
            SizedBox(height: ultraDenseLandscape ? 2 : 3),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                _PaymentChoiceChip(
                  label: 'Card',
                  icon: Icons.credit_card,
                  selected: controller.paymentType == PaymentType.card,
                  onSelected: () {
                    controller.updatePaymentType(PaymentType.card);
                    setState(() {});
                  },
                  compact: true,
                ),
                _PaymentChoiceChip(
                  label: 'eWallet',
                  icon: Icons.qr_code_2,
                  selected: controller.paymentType == PaymentType.eWallet,
                  onSelected: () {
                    controller.updatePaymentType(PaymentType.eWallet);
                    setState(() {});
                  },
                  compact: true,
                ),
                _PaymentChoiceChip(
                  label: 'Cash',
                  icon: Icons.payments_outlined,
                  selected: controller.paymentType == PaymentType.cash,
                  onSelected: () {
                    controller.updatePaymentType(PaymentType.cash);
                    setState(() {});
                  },
                  compact: true,
                ),
              ],
            ),
            if (controller.paymentType == PaymentType.cash) ...[
              SizedBox(height: ultraDenseLandscape ? 2 : 4),
              TextField(
                controller: _cashController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(fontSize: 11 * scale),
                decoration: InputDecoration(
                  labelText: 'Cash received',
                  labelStyle: TextStyle(fontSize: 10 * scale),
                  prefixText: '₱ ',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: ultraDenseLandscape ? 6 : 8,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  controller.updateCashReceived(double.tryParse(value) ?? 0);
                },
              ),
              SizedBox(height: ultraDenseLandscape ? 2 : 3),
              Text(
                controller.cashReceived < summary.total
                    ? 'Collect at least ${_money(summary.total)} to complete cash checkout.'
                    : 'Change due: ${_money(summary.change)}',
                style: TextStyle(
                  fontSize: 9.5 * scale,
                  color: controller.cashReceived < summary.total
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
            ],
            SizedBox(height: ultraDenseLandscape ? 3 : 4),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.canCheckout
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final order = await controller.checkout();
                            if (order != null) {
                              if (controller.autoPrintReceipts) {
                                try {
                                  await controller.printReceipt(order);
                                } catch (_) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Saved ${order.id}, but receipt print failed.',
                                      ),
                                    ),
                                  );
                                }
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Saved ${order.id} as a paid order',
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: Text(
                      'Charge',
                      style: TextStyle(fontSize: 11 * scale),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        denseLandscape
            ? 6
            : widget.compactLandscape
            ? 8
            : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F1E4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x18A57A58)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Color(0x10000000),
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showBreakdown = !_showBreakdown),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _showBreakdown
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                ),
                label: Text(_showBreakdown ? 'Hide details' : 'Show details'),
              ),
            ],
          ),
          if (_showBreakdown) ...[
            const SizedBox(height: 3),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                _SummaryMiniStat(
                  label: 'Gross',
                  value: _money(summary.grossAmount),
                  width: denseLandscape ? 88 : 96,
                ),
                _SummaryMiniStat(
                  label: 'VATable',
                  value: _money(summary.vatableSales),
                  width: denseLandscape ? 88 : 96,
                ),
                _SummaryMiniStat(
                  label: 'VAT-free',
                  value: _money(summary.vatExemptSales),
                  width: denseLandscape ? 88 : 96,
                ),
                if (summary.vatExemptionAmount > 0)
                  _SummaryMiniStat(
                    label: 'VAT exempt',
                    value: _money(summary.vatExemptionAmount),
                    width: denseLandscape ? 88 : 96,
                  ),
                _SummaryMiniStat(
                  label: 'Discount',
                  value: '-${_money(summary.discount)}',
                  width: denseLandscape ? 88 : 96,
                ),
                _SummaryMiniStat(
                  label: 'Tax',
                  value: _money(summary.tax),
                  width: denseLandscape ? 88 : 96,
                ),
                _SummaryMiniStat(
                  label: 'Svc chg',
                  value: _money(summary.serviceCharge),
                  width: denseLandscape ? 88 : 96,
                ),
              ],
            ),
          ],
          SizedBox(
            height: denseLandscape
                ? 3
                : widget.compactLandscape
                ? 5
                : 8,
          ),
          _OrderTypeToggle(
            orderType: controller.orderType,
            onChanged: controller.updateOrderType,
            compact: denseLandscape,
          ),
          SizedBox(
            height: denseLandscape
                ? 3
                : widget.compactLandscape
                ? 5
                : 8,
          ),
          _SummaryRow(
            label: 'Total',
            value: _money(summary.total),
            emphasized: true,
            compactLandscape: widget.compactLandscape,
            compact: denseLandscape,
          ),
          SizedBox(
            height: denseLandscape
                ? 3
                : widget.compactLandscape
                ? 5
                : 8,
          ),
          widget.compactLandscape
              ? Wrap(
                  spacing: denseLandscape ? 3 : 5,
                  runSpacing: denseLandscape ? 3 : 5,
                  children: [
                    _PaymentChoiceChip(
                      label: 'Card',
                      icon: Icons.credit_card,
                      selected: controller.paymentType == PaymentType.card,
                      onSelected: () {
                        controller.updatePaymentType(PaymentType.card);
                        setState(() {});
                      },
                      compact: denseLandscape,
                    ),
                    _PaymentChoiceChip(
                      label: 'eWallet',
                      icon: Icons.qr_code_2,
                      selected: controller.paymentType == PaymentType.eWallet,
                      onSelected: () {
                        controller.updatePaymentType(PaymentType.eWallet);
                        setState(() {});
                      },
                      compact: denseLandscape,
                    ),
                    _PaymentChoiceChip(
                      label: 'Cash',
                      icon: Icons.payments_outlined,
                      selected: controller.paymentType == PaymentType.cash,
                      onSelected: () {
                        controller.updatePaymentType(PaymentType.cash);
                        setState(() {});
                      },
                      compact: denseLandscape,
                    ),
                  ],
                )
              : SegmentedButton<PaymentType>(
                  segments: const [
                    ButtonSegment<PaymentType>(
                      value: PaymentType.card,
                      label: Text('Card'),
                      icon: Icon(Icons.credit_card),
                    ),
                    ButtonSegment<PaymentType>(
                      value: PaymentType.eWallet,
                      label: Text('eWallet'),
                      icon: Icon(Icons.qr_code_2),
                    ),
                    ButtonSegment<PaymentType>(
                      value: PaymentType.cash,
                      label: Text('Cash'),
                      icon: Icon(Icons.payments_outlined),
                    ),
                  ],
                  selected: {controller.paymentType},
                  onSelectionChanged: (selection) {
                    controller.updatePaymentType(selection.first);
                    setState(() {});
                  },
                ),
          if (controller.paymentType == PaymentType.cash) ...[
            SizedBox(height: denseLandscape ? 3 : 8),
            TextField(
              controller: _cashController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(fontSize: 12 * scale),
              decoration: InputDecoration(
                labelText: 'Cash received',
                labelStyle: TextStyle(fontSize: 11 * scale),
                prefixText: '₱ ',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: denseLandscape ? 8 : 10,
                  vertical: denseLandscape ? 7 : 10,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                controller.updateCashReceived(double.tryParse(value) ?? 0);
              },
            ),
            SizedBox(height: denseLandscape ? 2 : 4),
            Text(
              controller.cashReceived < summary.total
                  ? 'Collect at least ${_money(summary.total)} to complete cash checkout.'
                  : 'Change due: ${_money(summary.change)}',
              style: TextStyle(
                fontSize: 10 * scale,
                color: controller.cashReceived < summary.total
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
          ],
          SizedBox(
            height: denseLandscape
                ? 3
                : widget.compactLandscape
                ? 5
                : 10,
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.canCheckout
                      ? () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final order = await controller.checkout();
                          if (order != null) {
                            if (controller.autoPrintReceipts) {
                              try {
                                await controller.printReceipt(order);
                              } catch (_) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Saved ${order.id}, but receipt print failed.',
                                    ),
                                  ),
                                );
                              }
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Saved ${order.id} as a paid order',
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.lock_open),
                  label: Text('Charge', style: TextStyle(fontSize: 12 * scale)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentChoiceChip extends StatelessWidget {
  const _PaymentChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: compact ? 14 : 16),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 4,
      ),
    );
  }
}

class _OrderTypeToggle extends StatelessWidget {
  const _OrderTypeToggle({
    required this.orderType,
    required this.onChanged,
    this.compact = false,
  });

  final String orderType;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selectedColor = const Color(0xFFF25C54);
    final unselectedColor = const Color(0xFFF7E8DC);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 4 : 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EBDD),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: const Color(0x1F9A7A60)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OrderTypeSegment(
              label: 'Dine-in',
              icon: Icons.table_restaurant_outlined,
              selected: orderType == 'Dine-in',
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              compact: compact,
              onTap: () => onChanged('Dine-in'),
            ),
          ),
          SizedBox(width: compact ? 4 : 6),
          Expanded(
            child: _OrderTypeSegment(
              label: 'Take-out',
              icon: Icons.takeout_dining_outlined,
              selected: orderType == 'Take-out',
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              compact: compact,
              onTap: () => onChanged('Take-out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeSegment extends StatelessWidget {
  const _OrderTypeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : unselectedColor,
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE85E52)
                  : const Color(0x22B48E6D),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: compact ? 15 : 16,
                color: selected ? Colors.white : const Color(0xFF6E5847),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11 : 12,
                    color: selected ? Colors.white : const Color(0xFF6E5847),
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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.compactLandscape = false,
  });

  final String label;
  final String value;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compactLandscape ? 12 : 14,
        vertical: compactLandscape ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A6B4423)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          SizedBox(height: compactLandscape ? 2 : 4),
          Text(
            value,
            style: compactLandscape
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 420;
        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [textBlock, const SizedBox(height: 10), trailing],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: textBlock),
            trailing,
          ],
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.compactLandscape,
    this.compact = false,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool compactLandscape;
  final bool compact;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scale = _tabletTextScale(context, max: compact ? 0.86 : 0.92);
    final textStyle = emphasized
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize:
                (Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) *
                scale,
            fontWeight: FontWeight.w800,
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize:
                (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) *
                scale,
          );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 5),
      child: compactLandscape
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: compact ? 8 : 12),
                Expanded(
                  child: Text(
                    value,
                    style: textStyle,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: textStyle,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryMiniStat extends StatelessWidget {
  const _SummaryMiniStat({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1C9A7A60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.brown.shade700,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.brown.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _tabletTextScale(
  BuildContext context, {
  double min = 0.82,
  double max = 1.0,
}) {
  final shortestSide = MediaQuery.sizeOf(context).shortestSide;
  final raw = shortestSide / 900.0;
  return raw.clamp(min, max).toDouble();
}

int _cartQuantityFor(List<CartItem> cart, String productId) {
  for (final item in cart) {
    if (item.product.id == productId) {
      return item.quantity;
    }
  }
  return 0;
}

Color _productAccent(String categoryId) {
  switch (categoryId) {
    case 'coffee':
      return const Color(0xFFF05B52);
    case 'drinks':
      return const Color(0xFF4FB7C5);
    case 'snacks':
      return const Color(0xFFF2A84D);
    case 'dessert':
      return const Color(0xFFF28D8B);
    default:
      return const Color(0xFFF06A53);
  }
}

/// Uses bundled Material icons instead of device-dependent emoji from imports.
/// Custom or unknown categories still receive a visible generic icon.
IconData _categoryIconData(Category category) {
  switch (category.icon.trim()) {
    case '☕':
      return Icons.coffee_outlined;
    case '🥤':
    case '🧊':
      return Icons.local_drink_outlined;
    case '🍵':
      return Icons.emoji_food_beverage_outlined;
    case '🥐':
    case '🍞':
    case '🍿':
    case '🥟':
    case '🍗':
    case '🍟':
    case '🍢':
    case '🧀':
      return Icons.fastfood_outlined;
    case '🍽️':
    case '🍳':
      return Icons.restaurant_outlined;
    case '🍱':
    case '👯':
    case '🎮':
    case '🎲':
      return Icons.groups_outlined;
    case '🍰':
      return Icons.cake_outlined;
    case '➕':
      return Icons.add_circle_outline;
    default:
      return Icons.local_offer_outlined;
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.brown.shade300),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

String _money(num value) => '₱${value.toStringAsFixed(2)}';
