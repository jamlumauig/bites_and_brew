import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cafe_and_brews/src/data/coffee_pos_repository.dart';
import 'package:cafe_and_brews/src/domain/coffee_pos_models.dart';
import 'package:cafe_and_brews/src/state/coffee_pos_controller.dart';
import 'package:cafe_and_brews/src/ui/widgets/cashier_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Explicitly invoked artifact renderer, using only the repository's demo menu.
// flutter test test/products_preview_test.dart --dart-define=RENDER_POS_PREVIEW=true
void main() {
  testWidgets(
    'render the actual desktop and phone ordering views side by side',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final font = FontLoader('PreviewSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      final bold = FontLoader('PreviewBold')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
      await bold.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final controller = CoffeePosController(
        repository: InMemoryCoffeePosRepository(),
      );
      controller.importStateJson(jsonEncode(StoreBootstrap.sample().toJson()));
      for (final product in controller.products.take(2)) {
        controller.addProductToCart(
          product,
          quantity: product == controller.products.first ? 2 : 1,
        );
      }
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(1960, 1120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      Widget frame(String label, Size size) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PreviewBold',
              fontSize: 16,
              color: Color(0xFF75685C),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDED2C3)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: MediaQuery(
                  data: MediaQueryData(size: size),
                  child: Material(
                    color: const Color(0xFFFAF6F0),
                    child: Padding(
                      padding: EdgeInsets.all(size.width > 600 ? 20 : 8),
                      child: CashierDashboard(controller: controller),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'PreviewSans',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE96755),
            ),
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: Material(
              color: const Color(0xFFF0E8DC),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A calmer counter. A faster order.',
                      style: TextStyle(
                        fontFamily: 'PreviewBold',
                        fontSize: 30,
                        color: Color(0xFF332D29),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PRODUCTS / RESPONSIVE ORDERING',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: Color(0xFF83776D),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        frame('DESKTOP / WEB', const Size(1440, 850)),
                        const SizedBox(width: 34),
                        frame('MOBILE / PHONE', const Size(390, 850)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Actual Flutter interface · Existing demo menu shown for layout only · Uploaded menus supply all live categories, products and prices.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF83776D)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/products-redesign/responsive-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
    skip: !const bool.fromEnvironment('RENDER_POS_PREVIEW'),
  );
}
