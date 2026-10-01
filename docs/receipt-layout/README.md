# Compact combined receipt comparison

The before/after artifacts use the same saved order: one Espresso with a ₱69 base price and a ₱20 Extra Shot surcharge; total ₱89, VAT off, order #32, Take-out. They were generated in memory without a printer.

| Measurement | Before | After |
| --- | ---: | ---: |
| ESC/POS lines, including separators and tear gap | 20 | 16 |
| PDF page height | 81.10 mm | 62.70 mm |
| PDF pages | 1 | 1 |
| Printer submissions per Charge | 1 | 1 |

The PDF is about 23% shorter. Its height is measured from content, with no fixed paper length or extra bottom spacer. Hardware still receives its configured minimal cutter/tear-bar feed.

Open [before.pdf](before.pdf) and [after.pdf](after.pdf), or compare [before.png](before.png) and [after.png](after.png). HTML and plain-text versions are also included.

## Financial trace

- `CartItem.singleItemPrice` adds the selected modifier deltas to the product base price. `lineTotal` multiplies that inclusive unit price by quantity.
- `CoffeePosController.checkout` saves the inclusive unit price, line total, and the priced modifier snapshots into `CartLineInput`.
- `InMemoryCoffeePosRepository.createOrder` treats that unit price as already inclusive. Its temporary labels carry zero extra delta to avoid charging modifiers twice.
- `OrderRecord.fromCalculatedTotals` preserves the line totals and full modifier snapshots; JSON round-trips retain them.
- `ReceiptData.fromOrderRecord` uses those saved values. The shared receipt layout displays the saved line amount minus the separately displayed modifier amounts as the base-price row. The transaction total is never changed by the renderer.

Tests verify ₱69 + ₱20 = ₱89 for one drink and ₱138 + ₱40 = ₱178 for two, through cart, checkout, saved-order serialization, and one captured print submission. This resolves the misleading presentation of an inclusive line amount alongside a separate add-on charge without rewriting historical transaction totals.

## Layout

All formats share `ReceiptLayout`: two internal separators and a two-line manual tear gap for the simple combined order, one configured customer footer near the store header, aligned modifier name/amount rows, one compact kitchen header, and no kitchen footer. Payment Method stays on one row; cash payments include useful Cash/Change rows. VAT Incl. is shown only when VAT is enabled and nonzero. Raw ESC/POS auto-cut replaces the manual gap with cutter-safe feed and a physical cut in the same submission; PDF/browser output always retains the tear gap. Empty optional fields and default zero-price customer modifiers produce no row. Kitchen modifiers remain preparation-complete.

Run the printing tests normally to verify the archived comparison. To regenerate only the after artifacts:

```sh
flutter test --dart-define=WRITE_RECEIPT_PREVIEW=true test/compact_receipt_test.dart
```
