import 'package:flutter/material.dart';

import '../domain/coffee_pos_models.dart';

/// Maps imported emoji to bundled Material icons so category icons render on
/// devices and fonts that do not support every emoji glyph.
IconData categoryIconData(Category category) {
  switch (category.icon.trim().replaceAll('\uFE0F', '')) {
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
    case '🍽':
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
