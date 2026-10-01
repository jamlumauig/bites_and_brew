# POS Feature Inventory

Discovery date: 2026-10-01. Scope: the current working tree, including existing uncommitted and untracked application files. This is a source-backed discovery document, not a production certification or a statement about what is currently deployed.

Roles used: [Product Manager](../agents/product-manager.md), [Senior Flutter Developer](../agents/senior-flutter-developer.md), and independent [QA Engineer](../agents/qa-engineer.md). Application functionality, dependencies, schemas, APIs, and native integrations were not changed during discovery.

Evidence references use repository-relative paths and line numbers from this snapshot. Short source names below resolve to these files:

| Reference | Source |
| --- | --- |
| Controller | [lib/src/state/coffee_pos_controller.dart](../lib/src/state/coffee_pos_controller.dart) |
| Models | [lib/src/domain/coffee_pos_models.dart](../lib/src/domain/coffee_pos_models.dart) |
| Calculator | [lib/src/domain/checkout_calculator.dart](../lib/src/domain/checkout_calculator.dart) |
| Repository | [lib/src/data/coffee_pos_repository.dart](../lib/src/data/coffee_pos_repository.dart) |
| Cashier | [lib/src/ui/widgets/cashier_dashboard.dart](../lib/src/ui/widgets/cashier_dashboard.dart) |
| Shell | [lib/src/ui/widgets/coffee_pos_shell.dart](../lib/src/ui/widgets/coffee_pos_shell.dart) |
| Admin | [lib/src/ui/widgets/admin_dashboard.dart](../lib/src/ui/widgets/admin_dashboard.dart) |
| Printing | [lib/src/utils/printing/](../lib/src/utils/printing/) |

## 1. POS Overview

The application is branded **Haven & Co.**, a Flutter food-and-drink POS with cashier and admin experiences. It has a working local sale-recording flow, configurable menu/modifiers, preparation tickets, receipt generation, system/network printing routes, catalog management, manual inventory records, and sales summaries. It also contains prototype fixtures and incomplete operational workflows.

Cashiers can access Cashier, In Progress, and Orders. Admins additionally access Customers, Admin, Reports, and Settings. The Customers page is an internal admin screen; no customer-facing kiosk, customer display, or customer ordering app was found.

A sale is recorded as `OrderStatus.paid` by an in-memory repository before printing. Selecting Card or E-Wallet records a tender label; it does not contact a payment processor. Local/shared snapshot persistence follows record creation and tolerates failures. A printed receipt therefore proves neither payment authorization nor durable backend storage.

### Discovery acceptance criteria

The PM required coverage of all requested feature categories and project layers; real UI actions distinguished from model-only code and fixtures; source evidence for material claims; all printing entry points and three critical flows traced; risks and manual checks separated; no secrets in the report; and no application changes. QA reviews this document against those criteria, not against newly invented feature requirements.

### Status meanings

| Status | Meaning in this report |
| --- | --- |
| IMPLEMENTED | An actual connected source path exists; hardware/deployed behavior is not implied. |
| PARTIALLY IMPLEMENTED | Some layers exist, but a material layer or workflow is absent. |
| PRESENT BUT POSSIBLY BROKEN | A concrete code inconsistency or unsafe execution path was found; reproduction evidence/limitations are stated. |
| NOT IMPLEMENTED | No implementation found in the inspected first-party application paths. |
| UNUSED/DEAD CODE | Present in the repository, with no active application caller or an explicit no-op. |
| NEEDS MANUAL VERIFICATION | Requires devices, a browser/OS, live configuration, or multi-client behavior not exercised here. |

## 2. Application Architecture

```text
main.dart → Firebase initialization → CoffeePosApp / Firebase auth gate
  → user-keyed CoffeePosSession
    → CoffeePosController (ChangeNotifier)
      → CoffeePosScope (InheritedNotifier) → responsive UI / dialogs
      → InMemoryCoffeePosRepository → Calculator / immutable order snapshots
      → SharedPreferences JSON snapshots
      → Firebase Realtime Database personal state + shared catalog/orders
      → Cloud Functions for auth role management
      → receipt_printer facade → validated, queued print service → adapters
```

`lib/main.dart:7` initializes Firebase, captures initialization errors, and runs the app. Web uses generated options; native initialization relies on native configuration. `lib/src/app.dart:75` gates startup on Firebase availability and `authStateChanges()`. `_CoffeePosSession` creates `InMemoryCoffeePosRepository` at line 129. `coffee_pos_home.dart:14` starts controller initialization and displays loading state.

State is centralized in Controller, exposed through `InheritedNotifier` and `AnimatedBuilder`; there is no Provider package, Riverpod, BLoC, or named-route navigation system. Domain classes serialize to/from JSON. No active HTTP/Dio REST client or separate payment service was found. Firebase SDKs provide network calls directly.

The active database is **Realtime Database**, despite stale controller comments mentioning Firestore. Firestore rules/configuration and generated Data Connect clients/schema exist but are not imported into the running POS flow. Data Connect's sample mutations insert unrelated sample products and fixed order data; their presence does not implement POS stock/order APIs.

Coverage includes all first-party `lib/`, `test/`, `functions/`, `dataconnect/`, generated Dart/JS connector interfaces, Android/iOS native entry points/manifests/build settings, web/public entry points, assets, package/dependency manifests, Firebase/deployment configuration, and repository instructions. Third-party dependency internals and generated build caches are not treated as application features. Platform/dependency details are recorded in section 15.

## 3. Screen / Navigation Map

```text
Launch
├── Firebase unavailable → explanatory error screen
├── Firebase/auth loading
└── Authentication gate
    ├── Sign in: email/password
    │   ├── Create account
    │   └── Password reset email
    └── Signed-in session → controller loading → CoffeePosShell
        ├── Cashier [all users, default]
        │   ├── Category filter / product grid / quick search
        │   ├── Product customizer → quantity / modifier choices → add
        │   └── Cart panel or mobile sheet → tender choice → Charge
        │       └── Paid order saved in memory → optional print → snackbar
        ├── In Progress [all users]
        │   ├── View ticket details
        │   ├── Continue [held tickets only] → replaces current cart
        │   └── Complete confirmation → remove preparation ticket
        ├── Orders [all users]
        │   ├── Search / status and Today filters
        │   └── Paid order → Print receipt
        ├── Customers [admin] → select/clear an existing profile
        ├── Admin [admin]
        │   ├── Overview / Products / Inventory / Orders
        │   └── CRUD dialogs; JSON and XLSX import/export
        ├── Reports [admin] → week/month summaries
        ├── Settings [admin] → configuration dialogs / data reset actions
        └── Logout → flush personal persistence queue → Firebase sign-out
```

Evidence: Shell:17,139,239,412; Admin:22; Cashier:2161,2617,2922. Navigation is local enum state with a responsive sidebar/drawer and `AnimatedSwitcher`. There is no separate checkout page, payment-confirmation page, or saved-receipt preview screen. Width/orientation changes select desktop, compact-landscape, and mobile layouts.

## 4. Complete Feature Inventory

The feature matrix is the exhaustive investigated-capability checklist; sections 6–26 explain behavior, state transitions, calculations, and limitations. Features omitted from typical POS expectations are explicitly marked absent rather than inferred from labels, enums, dependencies, or sample data.

Additional features beyond basic POS: Firebase self-registration/password reset; user role administration; menu badges/category icons; JSON backup/restore; XLSX product and inventory import/export; responsive layouts; preparation ticket completion; compact PDF receipt layout; printer discovery heuristics; and developer print diagnostics.

Shift operations are **NOT IMPLEMENTED**: a `ShiftSummary` model and active-shift count exist, but no start/end shift, opening/closing cash, count, reconciliation, or shift report action exists. Controller uses the fixed draft shift ID `shift-001`; the paid `OrderRecord` does not preserve this draft field (Models:560,794,1011; Controller:66,1630; Admin:234).

## 5. Feature Matrix

| FEATURE | STATUS | UI LOCATION | MAIN CODE | NOTES |
| --- | --- | --- | --- | --- |
| Email/password login | IMPLEMENTED | Sign-in | firebase_sign_in_screen.dart:26 | Firebase Auth; validation and busy controls. |
| Self-registration | IMPLEMENTED | Create account | firebase_sign_in_screen.dart:37 | Creates Firebase email/password user. |
| Password reset / visibility | IMPLEMENTED | Sign-in | firebase_sign_in_screen.dart:68,190 | Email reset and obscured-field toggle. |
| Logout / auth session gate | IMPLEMENTED | Sidebar/drawer | Shell:133; app.dart:75 | Flushes personal queue, signs out, replaces session by UID. |
| Cashier/admin roles | IMPLEMENTED | Navigation / User Access | Shell:154,2162; functions/index.js:37 | Claims admin/user map to admin/cashier. |
| Manager role / PIN / shift lock | NOT IMPLEMENTED | — | Models:1; auth screen | No corresponding role or flow. |
| Role management permissions | IMPLEMENTED | Settings → User Access | functions/index.js:29,56,68 | Admin-required list/set calls; deployment unverified. |
| Catalog category filter | IMPLEMENTED | Cashier | Controller:145,185 | Only categories containing products shown. |
| Product grid / search / add | IMPLEMENTED | Cashier | Cashier:537,581,709 | Name/category/description search; customizer before add. |
| Food and drink catalog | IMPLEMENTED | Cashier / Admin | Models:95,261 | Same Product model; sample menu supplied. |
| Product photos / uploads | NOT IMPLEMENTED | — | Models:261; Cashier artwork | Generic icon artwork, no product image field. |
| Availability / out-of-stock gating | NOT IMPLEMENTED | — | Controller:873; Models:261 | Inventory does not disable product sales. |
| Favorites | NOT IMPLEMENTED | — | Cashier; Models:261 | No favorite state/control. |
| Drink size / milk / extras | IMPLEMENTED | Product customizer | Models:105; Cashier:2161 | 16/22 oz, milk types, shot/syrup/cream defaults. |
| Hot/iced / sugar / ice level | NOT IMPLEMENTED | — | Models:105; customizer | “Iced” product names are not selectable temperature. |
| Food size / generic modifiers | IMPLEMENTED | Product customizer | Controller:587,622 | Snack Small/Large; attach existing groups. |
| Item notes / free-text customization | NOT IMPLEMENTED | — | Models:454,514,626 | No line note input/model. |
| Modifier group editor | NOT IMPLEMENTED | — | Admin:1935 | Product form attaches existing groups; JSON can carry groups. |
| Arbitrary imported modifier constraints | PARTIALLY IMPLEMENTED | Customizer | Cashier:2180,2268,2365 | Default groups work; no final general min-selection validation. |
| Add/remove/change cart quantity | IMPLEMENTED | Cart panel/sheet | Controller:873,917,939 | Zero quantity removes line. |
| Edit modifiers / clear cart | IMPLEMENTED | Cart | Controller:945,958 | Edit does not coalesce newly identical lines. |
| Price/subtotal/tax/total/change | IMPLEMENTED | Cart | Calculator:17; Models:467 | See exact formulas below. |
| Dine-in / Take-out | IMPLEMENTED | Cashier | Controller:1049 | Other inputs normalize to Dine-in. |
| Delivery / tables | NOT IMPLEMENTED | — | Models:560,794 | No table/driver/delivery workflow. |
| Customer selection | PARTIALLY IMPLEMENTED | Customers [admin] | Shell:909; Controller:1640 | Name copied to preparation ticket only. |
| Cash received and change | IMPLEMENTED | Cashier | Controller:203; Cashier:2574 | Sufficient tender required. |
| Card / E-Wallet tender recording | IMPLEMENTED | Cashier | Models:9; Controller:1043 | Labels saved; no authorization. |
| Payment gateway / terminal / QR payment | NOT IMPLEMENTED | — | Repository:22 | QR icon is decorative; no processor call. |
| Split / partial / other payment methods | NOT IMPLEMENTED | — | Models:9 | Exactly three tender enum values. |
| Paid sale creation | IMPLEMENTED | Charge | Controller:1598; Repository:22 | Local creation then best-effort snapshot saves. |
| Unique durable order numbering | PRESENT BUT POSSIBLY BROKEN | Charge / history | Repository:62; Models:859 | ORD-N counter restarts per repository session. |
| Double-checkout protection | NOT IMPLEMENTED | Charge | Cashier:2617,2922; Controller:1598 | No in-flight guard or idempotency key. |
| Preparation queue / ticket view / complete | IMPLEMENTED | In Progress | Shell:748,3090,3307; Controller:1004 | Completion removes ticket; does not charge. |
| Hold / resume workflow | PARTIALLY IMPLEMENTED | In Progress, held tickets | Controller:976 | Continue exists; no normal Hold creation UI. |
| Voids / refunds / cancellations | PARTIALLY IMPLEMENTED | History filters | Models:3; Shell:846 | Status/filter support only; no mutation or reversal. |
| Fixed order discount | PARTIALLY IMPLEMENTED | Summary only | Controller:1019; Calculator:169 | Calculation/setter exist; no cashier input caller. |
| Percentage / senior / PWD discount | PARTIALLY IMPLEMENTED | — | Models:393; Calculator:44 | Domain-only; not wired to checkout controls/draft. |
| Item discount / promos / approval rules | NOT IMPLEMENTED | — | Calculator; Cashier | No operational UI or permission workflow. |
| VAT-inclusive calculation/configuration | IMPLEMENTED | Tax Settings / summary | Calculator:17; Shell:1519 | Default 12%, integer-percent extraction. |
| Tax-exclusive checkout / per-item tax | NOT IMPLEMENTED | — | Calculator; Models:261 | Receipt validator compatibility is not checkout support. |
| Service charge | IMPLEMENTED | Tax Settings | Calculator:28; Controller:1031 | Applied to gross before discounts. |
| Product CRUD | IMPLEMENTED | Admin → Products | Admin:552,1818; Controller:724 | Name/category/price/description/badge/group IDs. |
| Category creation/edit/deletion controls | UNUSED/DEAD CODE | — | Controller:668,696,713 | No UI caller; import/default category creation is active. |
| Inventory CRUD / manual restock | IMPLEMENTED | Admin → Inventory | Admin:673,2019; Controller:815 | Independent on-hand/threshold/status/severity records. |
| Low-stock display | PARTIALLY IMPLEMENTED | Admin | Admin:240,791 | Uses manual severity; not automatic threshold alerts. |
| Product/ingredient stock linkage / deduction | NOT IMPLEMENTED | — | Controller:1598; Models:969 | No recipe, stock ledger, or sale deduction. |
| Inventory movement/restock history | NOT IMPLEMENTED | — | Models:969 | Editing current quantity only. |
| Receipt generation | IMPLEMENTED | Auto-print / history | receipt_printer.dart; Printing | ESC/POS, PDF, and browser HTML templates. |
| Receipt preview/detail screen | NOT IMPLEMENTED | Paid-order history | Shell:2692 | Cards show summary; queue view is not paid receipt viewer. |
| QR / barcode / receipt logo | NOT IMPLEMENTED | — | ReceiptData and builders | App logo is not printed. |
| Receipt print/reprint | IMPLEMENTED | Charge / Orders | Cashier:2625,2930; Shell:2743 | All feed common service; hardware unverified. |
| 80mm printing | IMPLEMENTED | Printer Settings | printer_config.dart; builders | Configurable roll, assumed geometry; manual validation required. |
| 58mm / 50mm rendering | PARTIALLY IMPLEMENTED | Printer Settings | printer_config.dart; ESC/POS builder | PDF/HTML vary width; raw text remains default 48 columns. |
| Physical paper/DPI/capability detection | NOT IMPLEMENTED | — | printer_resolver.dart | Name/default heuristics are not hardware detection. |
| System printer discovery / selection | IMPLEMENTED | Printer Settings | Shell:1639; printer_resolver.dart | Printing plugin enumeration/picker. |
| Native direct / OS dialog printing | NEEDS MANUAL VERIFICATION | Printer Settings | platform adapters | OS/driver support determines availability/delivery. |
| Network ESC/POS | IMPLEMENTED | Printer Settings | network_printer_io.dart; adapters | TCP host/port, normally 9100; not browser raw printing. |
| Bluetooth / USB native pairing and transport | NOT IMPLEMENTED | — | Native entry points; dependencies | Possible indirect helper/OS-driver use only. |
| Thermal helper app share | PARTIALLY IMPLEMENTED | Printer Settings | android_printer_adapter.dart | Shares PDF; no delivery confirmation. |
| Connection check | PARTIALLY IMPLEMENTED | Printer Settings | Shell:1664 | Printer enumeration match, not selected TCP transport probe. |
| Printer reconnect/session management | NOT IMPLEMENTED | — | network_printer_io.dart | Fresh socket per job; no persistent pairing/reconnect loop. |
| Auto-print preference | IMPLEMENTED | Printer Settings | Controller:57; Cashier:2622 | Can be overwritten by auto-configuration. |
| Per-printer profile / copies / reprint defaults | NOT IMPLEMENTED | — | Controller:375 | Single user-level selected configuration. |
| Test print | NOT IMPLEMENTED | — | All print callsites | No dedicated test receipt/action. |
| Feed / cutter command | IMPLEMENTED | Printer Settings | esc_pos_generator.dart | Raw route only; driver behavior needs verification. |
| Cash drawer pulse | PARTIALLY IMPLEMENTED | Printer Settings | esc_pos_generator.dart | Raw prefix pulse on every receipt if enabled, not cash-only. |
| Standalone Open drawer | NOT IMPLEMENTED | — | Shell; Cashier | No button or separate command flow. |
| Print queue / recent-success deduplication | PARTIALLY IMPLEMENTED | Service | thermal_printer_service.dart:80,90 | Serial queue; 15-second success window; bypass on manual reprint. |
| Print cancellation API | UNUSED/DEAD CODE | — | thermal_printer_service.dart:66 | Empty implementation. |
| Print history diagnostics | PARTIALLY IMPLEMENTED | Logs only | thermal_printer_service.dart:231 | Last 50 jobs in memory; no persistent/UI audit. |
| History search / filters | IMPLEMENTED | Orders | Shell:828 | ID/cashier; All/Today/Completed/Cancelled/Refunded. |
| Arbitrary history date range / paging | NOT IMPLEMENTED | — | Shell:828 | In-memory loaded list. |
| Weekly/monthly sales / averages/items | IMPLEMENTED | Reports | Shell:1024 | Week means trailing seven days, month means month-to-date. |
| Today sales accuracy | PRESENT BUT POSSIBLY BROKEN | Reports / dashboard | Controller:1647 | Accumulator has no date rollover. |
| Top products / category / tender report | IMPLEMENTED | Reports | Shell:1050,1208,1248 | Category gross uses current catalog classifications. |
| Admin sales trend chart | PARTIALLY IMPLEMENTED | Admin → Overview | Admin:456 | Hardcoded demo bars, not real sales. |
| Cashier/discount/tax reports | NOT IMPLEMENTED | — | Reports page | No dedicated aggregate views. |
| Start/end shift / reconciliation | NOT IMPLEMENTED | — | Models:1011; Controller:66 | Counts/model only. |
| Store / receipt header-footer settings | IMPLEMENTED | Settings | Shell:1396,1459 | Saved user-level configuration. |
| Currency / badges / high contrast | PRESENT BUT POSSIBLY BROKEN | Settings | Shell:1584,2051,2303 | Saved but not consumed by money helpers/catalog/theme. |
| Compact receipt layout | IMPLEMENTED | POS Preferences | PDF builder | HTML/raw ignore compact flag; not printer capability detection. |
| Language / dark theme / payment setup | NOT IMPLEMENTED | — | Settings; app.dart | Fixed theme/text, no corresponding controls. |
| JSON snapshot export/import | IMPLEMENTED | Admin | Admin:1029,1051 | Broad state replacement; shared sync limitations below. |
| Product/inventory Excel import/export | IMPLEMENTED | Admin panels | Admin:1144,1172,1222,1247 | XLSX replacement, import confirmation. |
| Sales report export | NOT IMPLEMENTED | — | Admin/Reports | Catalog/inventory export is not sales export. |
| Restore demo / Delete All Data | PRESENT BUT POSSIBLY BROKEN | Settings | Controller:1160,1191 | Personal/local effects do not clear shared orders. |
| Local cart/settings/order persistence | IMPLEMENTED | Automatic | Controller:438,1329 | UID-scoped SharedPreferences JSON. |
| Offline ordering in an existing session | PARTIALLY IMPLEMENTED | Cashier | Repository; Controller:1324 | Local creation works; offline restart/auth and durability unverified. |
| Realtime shared catalog/orders | PARTIALLY IMPLEMENTED | Automatic | Controller:1396,1413,1444 | Whole snapshots; conflict/lost-update risks. |
| Durable outbox / conflict resolution / sync UI | NOT IMPLEMENTED | — | Controller persistence | No application-level event replay or merge. |
| Data Connect POS backend | UNUSED/DEAD CODE | — | dataconnect/; generated clients | Scaffold not called by active app. |
| SQLite / Hive / app secure storage | NOT IMPLEMENTED | — | pubspec.yaml; persistence | Firebase SDK internal auth storage is separate. |
| Customer CRUD / loyalty / spend updates | NOT IMPLEMENTED | — | Models:760; Shell:909 | Profile display/import only. |
| Customer-facing ordering/display | NOT IMPLEMENTED | — | App and shell | No customer route or second-display integration. |

## 6. Drinks & Food Ordering Features

`Product` has ID, name, category ID, price, description, badge, and modifier-group IDs. There is no separate Drink/Food entity, SKU, photo, stock quantity, availability field, or line-note property. Sample categories are Coffee, Shakes, Snacks, Ala Carte, Combos, Desserts; empty categories are hidden from cashier filtering (Models:95,261; Controller:145).

`ModifierGroup` defines options with price deltas and minimum/maximum selections. The customizer renders choice chips for single choices and filter chips for multiple choices, plus quantity. Existing defaults: drink sizes 16 oz (+0), 22 oz (+32); snack Small (+0), Large (+20); Regular Milk (+0), Oat (+26), Almond (+22); extras Extra Shot (+20), Vanilla Syrup (+15), Whipped Cream (+12). These are source sample defaults, not a claim about the live store menu.

Drink/snack grouping uses category IDs and selected category icons; drink-size or snack-size can be forced into applicable products. Legacy `size` groups are replaced by current defaults (Controller:158,595). Other food categories can use attached groups, but no specialized food-preparation workflow exists. Product management selects existing groups rather than editing options.

The normal ADD/search route opens the customizer and preselects only required groups. The separate `resolveDefaultModifiers()` helper selects the first option of **every** group, including optional extras; resume/controller-only additions can therefore add an extra shot by default (Controller:639; Cashier:2161). For arbitrary imported groups, minimums above one are not fully validated at confirmation and maximum zero is treated as single-choice despite the “Choose freely” label (Cashier:2268).

No temperature, sugar, ice-level, allergy, dietary-note, item-note, or free-text modifier control was found. A name such as “Iced Mocha” is ordinary catalog text.

## 7. Cart

Cart lines snapshot the current Product, quantity, selected modifier labels/IDs/deltas, and line ID. Add merges a product only when its ordered modifier signature matches; modifier ordering affects identity. Quantity changes/removal use line ID. Editing modifiers recalculates that line but does not merge it with another now-identical line. Clear resets discount/cash/payment type/order type, while retaining selected customer, VAT, and service rate (Controller:873–970,1592).

The UI provides add, quantity increment/decrement, remove, edit add-ons, and clear, in a side panel or mobile cart sheet. No item notes or editable arbitrary line-price UI exists. Product deletion removes matching cart lines; category deletion does not perform the same cart cleanup. Editing a Product does not replace its existing cart snapshot; product workbook replacement explicitly does (Controller:713,750,778,786).

### Exact totals

Let `roundCents(x)` be `round(x × 100)`; amounts below are in cents where indicated:

1. Unit price = product price + sum of selected modifier deltas. Raw line total = unit price × quantity (Models:467).
2. Gross cents = sum of each line rounded to cents. Arithmetic after this uses `Money` integer cents; the source product/unit calculations still use doubles.
3. Service cents = rounded gross × configured service rate, **before discount**.
4. Normal fixed discount is rounded and clamped between zero and gross. Percentage discount, when a domain caller supplies it, is rounded gross × fractional percentage and similarly clamped.
5. Discounted gross = gross − discount. VAT-exclusive base cents = round(discounted gross cents × 100 / [100 + round(VAT rate × 100)]). VAT = discounted gross − base. Thus fractional percentage VAT rates are effectively rounded to a whole percent for extraction.
6. Amount due = discounted gross + service charge. VAT is included, not added again.
7. Change = max(cash − amount due, 0), clamped to cash. Valid summary requires a nonempty cart and amount due > 0. Cash checkout additionally requires cash >= total.

Evidence: Calculator:17,156,169,185; Money:14; Controller:195,203. Existing calculator test example: two items at 145 + 32 yield gross 354; discount 20; 5% service 17.70; VAT base 298.21 and VAT 35.79; total 351.70; cash 500 gives change 148.30. Zero-total complimentary orders are not supported by `canCheckout`.

## 8. Checkout

The cashier selects Dine-in/Take-out and Cash/Card/E-Wallet, enters sufficient received cash for Cash, and presses **Charge**. No separate payment confirmation or payment gateway step exists. Both responsive Charge handlers await `controller.checkout()`, optionally call `printReceipt(order)`, then show “Saved … as a paid order” (Cashier:2617,2922).

The exact financial completion point is `OrderRecord.fromCalculatedTotals` setting `OrderStatus.paid` inside `InMemoryCoffeePosRepository.createOrder()` (Models:853; Repository:22). Controller then prepends history and a preparing ticket, increments sales, clears the cart, awaits personal snapshot and shared-order save attempts, and returns. Persistence failures are swallowed/returned as false, so the success message is not a durable-commit acknowledgement.

Charge remains enabled while the asynchronous order creation is pending; there is no controller busy flag. The repository delays ~220 ms before creating an order. Concurrent invocations can each copy the same cart and create distinct sale records. No automatic retry of checkout on a printing failure was found.

Preparation **Complete** is a different operation: it removes an in-progress ticket after confirmation, without new payment, sale creation, receipt, or inventory mutation (Controller:1004; Shell:3307).

## 9. Payments

Cash, Card, and E-Wallet are implemented tender labels. Cash collects a numeric amount and shows change; Card and E-Wallet require no authorization evidence. The QR-code icon used for E-Wallet is not a generated payment QR. There is no terminal integration, payment reference, gateway transaction ID, payment polling/webhook, split tender, partial payment, gratuity flow, refund provider call, or cash settlement ledger.

Receipt/payment failure messages relate to printing or input validity, not an external payment decline. It is inaccurate to say the application prevents double charges to a provider: it has no charging integration to exercise. Duplicate locally recorded paid sales remain a risk.

## 10. Orders & Transactions

`OrderDraft` captures cashier display name, order type, tender, tax/service/cash, lines, discount data, a literal prototype note, and fixed shift ID. `OrderRecord` stores financial/line snapshots and timestamp, but omits customer identity, shift linkage, and draft note. Order IDs are `ORD-N`, using a private repository list length + 1; preparation IDs are `Q-N` (Models:560,794,853; Controller:1603,1637; Repository:62).

The private repository list starts empty on each user session/restart and is not rehydrated from persisted recent orders. IDs can collide across sessions/devices, including print deduplication and queue-removal identity. There is no separate transaction table, server-assigned sequence, append-only ledger, server recalculation, or idempotency key.

All newly created paid orders enter a `preparing` queue. `pending`, `held`, and `awaitingPayment` are recognized display/import states but no ordinary UI action creates those transitions. **Continue is shown only for held tickets** (Shell:2507); resume uses current catalog products, default modifiers, and new line IDs, drops missing products, replaces the existing cart, and removes the queue item. It is not restoration of the exact original financial snapshot (Controller:976). A malformed/imported held record representing an already paid sale is not checked against history before a new checkout.

History can display paid/voided/refunded states, but there is no operational void, cancellation, or refund mutation/reversal workflow. Reprint is separate from transaction creation.

## 11. Discounts & Taxes

The calculator supports fixed, percentage, senior citizen, and PWD discount types. The ordinary controller passes only numeric `discountAmount` and does not pass `DiscountApplication` from a cashier control. `updateDiscount()` has no UI caller. Therefore even manual fixed discount entry is incomplete; restored/imported session data or a direct domain caller can supply it. The visible Discount summary does not provide an application workflow.

For domain-level senior/PWD calculations, eligible line IDs select gross; an empty selection means all lines. Eligible VAT-inclusive gross is converted to VAT-exclusive base, VAT exemption is removed, and 20% of that base is discounted. Remaining gross retains ordinary VAT. `holderName`, `idNumber`, and `eligiblePersons` exist in the model, but `eligiblePersons` does not prorate the calculator and no cashier eligibility/ID capture or approval UI exists. These are code behaviors, not a conclusion that statutory compliance is satisfied (Models:393; Calculator:44,185).

Tax Settings edits VAT and service percentages; setters clamp them to 0–1. Defaults are 12% VAT and 0% service. No per-item tax class or inclusive/exclusive setting exists. ReceiptValidator accepts either inclusive or exclusive total equations for compatibility; that does not mean checkout offers tax-exclusive pricing. Receipt templates display stored tax/discount totals; field differences appear in section 14.

## 12. Products

Product creation/edit/deletion is inside Admin → Products, with forms and delete confirmation. Fields are name, category, price, description, optional badge, and attached modifier groups. Existing prices and descriptive text are managed locally and shared through the admin catalog snapshot (Admin:552,1818; Controller:724–812).

Categories have ID/name/icon. Defaults are created when none exist; Excel imports can resolve/create categories. Controller category CRUD methods have no active UI callers. Deleting a category through code also removes its products, but no category-management dialog is exposed.

Product Excel export includes product ID/name, category ID/name/icon, price, description, badge, and modifier-group IDs. Import accepts header aliases, validates required Name/Price columns and positive prices, generates/normalizes unique IDs within the file, resolves categories, confirms replacement, and replaces the catalog. There are no photo uploads, barcode/SKU inputs, per-variant stock records, product availability, or external catalog API calls in the active app.

## 13. Inventory

Admin inventory CRUD stores ID, item name, on-hand quantity, threshold, status label, and severity. The operator selects status/severity; low-stock counts use severity rather than recomputing from quantity versus threshold. Updating on-hand is the only restocking-like operation. XLSX import/export and JSON backup include inventory (Models:969; Admin:673,2019; Controller:815).

Records have no Product ID, ingredient recipe, unit-of-measure accounting, or stock movement ledger. Checkout and ticket completion never deduct stock. Inventory is persisted in personal user snapshots rather than `store/catalog` or shared `store/orders`; different admin users do not receive a dedicated store-wide inventory stream. No sale-time stock enforcement, automated alerts, wastage, purchase orders, or inventory history was found.

## 14. Receipt System

All production printing passes through `lib/src/utils/receipt_printer.dart:21`, mapping saved `OrderRecord` financial/line snapshots to `ReceiptData` and current store/printer settings to `PrinterConfig`. Three templates are active: `esc_pos_generator.dart:17` (raw TCP), `pdf_receipt_builder.dart:15` (native system/direct/helper, also generated as browser fallback), and `web_receipt_html_builder.dart:12` (browser). The scratch PDF test is not a runtime template.

| Receipt field | ESC/POS | PDF | Browser HTML |
| --- | --- | --- | --- |
| Store name, address, contact, custom header | Yes; optional empty fields omitted | Same | Same |
| Receipt/order number | Saved order ID; no distinct receipt sequence | Same | Same |
| Date/time | Saved timestamp, 12-hour AM/PM | Same | Saved timestamp, 24-hour |
| Cashier / order type / tender | Yes | Yes | Yes |
| Item name / quantity / modifier labels | Text columns and wrapped names/modifiers | Quantity prefix and line blocks | Quantity/item/amount table |
| Unit price | Carried in data, not separately printed | Same | Same |
| Line amount / subtotal / total | Yes; numeric amounts | Yes; peso formatting | Yes; peso formatting |
| Aggregate discount | When positive | When positive | When positive plus statutory breakdown where present |
| Senior/PWD breakdown / VAT exemption deduction | No distinct deduction rows | No distinct deduction rows | Conditional rows |
| VAT / taxable / exempt sales | Positive tax and positive breakdown rows | Same | Conditional breakdown; literal VAT (12%) label |
| Service charge | When positive | When positive | When positive |
| Cash received | Cash tender only | Cash tender only | Cash tender only |
| Change | Cash tender, omitted at zero | Same | Cash tender, zero shown |
| Footer | Configured footer and hardcoded thanks | Same | Same |
| Customer / table / item notes | Not implemented | Not implemented | Not implemented |
| Logo / QR / barcode | Not implemented | Not implemented | Not implemented |
| Reprint mark / copy count | Not implemented | Not implemented | Not implemented |

`ReceiptData.sequence` is carried but unused by templates; no independent fiscal receipt number exists. Reprints use historical financial lines but current store header/address/footer. Evidence: raw builder:29,104; PDF:47,87,143,229; HTML:141,204. HTML's fixed VAT (12%) label can misdescribe a configured non-12% rate, and its tax branch can omit positive tax when both taxable/exempt bases are zero. PDF/raw omit the VAT-exemption deduction row even when the stored total reflects it.

The service validates before building **both** raw and PDF buffers, including on routes that use only one. A formatting failure in either blocks submission. HTML is built later within the browser adapter before invoking the iframe. Validation checks required ID/store/items, positive quantities, finite/nonnegative principal amounts, subtotal/total equations within five cents, and cash coverage/change. It accepts inclusive and exclusive total equations. It does not independently reconcile every line's unit-price multiplication or all tax breakdowns, reject error-like strings, or strip printer control characters.

PDF uses NotoSans assets, falling back to Helvetica if font loading fails. Page height is estimated from a fixed base and item lines, clamped 70–500mm, and MultiPage can paginate long content. Header/footer length is not fully represented in height estimation. Raw wrapping covers item names/modifiers but not every metadata/header/footer string. Unicode uses UTF-8 with peso replacement rather than negotiated printer code-page conversion. Receipt completeness, special characters, long receipt pagination, and blank/partial paper behavior need physical verification.

## 15. Thermal Printer System

### Pipeline and all entry points

The complete active entry-point list is: Cashier's two responsive Charge branches (`Cashier:2625,2930`) and paid-order History's Print receipt (`Shell:2743`). All call Controller:1655 → `receipt_printer.dart:21` → `ThermalPrinterServiceImpl.printReceipt`. No test-print, queue-complete print, separate kitchen print, drawer button, or startup receipt call was found.

Service pipeline: serialize job → check recent successful order ID unless explicit reprint → validate ReceiptData → build complete raw and PDF buffers in memory → reject empty output → adapter submission → record result/log. Before adapter invocation, validation or caught formatting failure sends zero print data. After submission, zero paper consumption or physical completion cannot be promised. Errors/logs are not routed as printable fallback receipts. `cancelPrint()` is empty.

| Route | Implementation and actual limits |
| --- | --- |
| Native Network (ESC/POS) | Android/iOS adapters parse host:port (default 9100), open a TCP socket, mark transmission begun before writing, flush/close. Connection timeout 5 seconds; no response/status acknowledgment read. Endpoint splitting is simple and not robust IPv6 validation. |
| Native Direct print | Resolves a system printer and calls `Printing.directPrintPdf` with custom paper; printer driver/plugin support determines actual behavior. Saved-printer mismatch may fall back to another thermal/default/first printer. |
| Native System dialog | `Printing.layoutPdf`; Android OS print services / iOS AirPrint. Submission/cancel result is not sensor-confirmed paper output. |
| Android Thermal printer app | `Printing.sharePdf`; external helper handles hardware. Sharing a PDF is not direct ESC/POS Bluetooth/USB support or delivery acknowledgment. |
| iOS Thermal printer app | Falls through to system dialog; no equivalent custom helper transport. |
| Web, any selected transport | Browser HTML iframe printing, with PDF dialog fallback. Network selection warns/falls back; raw TCP is unsupported. |
| Desktop fallback | Uses Android adapter's generic system/direct paths in Dart; no desktop runner project is present here. Do not infer a tested desktop build. |

Evidence: `platform_adapters/android_printer_adapter.dart`, `ios_printer_adapter.dart`, `web_printer_adapter.dart`, `web_html_printer_web.dart`, `printer_resolver.dart`, and `network_printer_io.dart`. Fresh TCP connections/system resolution provide another attempt on a later job, but no persistent connection lifecycle, pairing, automatic reconnect loop, or blind print retry exists.

### Width, commands, and capabilities

PaperWidth defines 50/58/80mm and nominal 26/32/48 columns, but PrinterConfig defaults `charactersPerLine=48` independently of the selected paper. The facade never derives that value from PaperWidth, so production raw receipts remain 48 columns even at 58/50mm. PDF adapts selected width and style; 50mm has a square label layout unless compact style takes precedence. HTML assumes printable width `(rollWidth - 8).clamp(40,76)` mm. No measured dots-per-line, DPI, physical paper detection, capability profile, code-page negotiation, or per-device margins exist.

Compact style affects **PDF only**; raw and HTML ignore it. Feed settings allow 0–8 in UI, but raw/height calculations clamp 1–4, PDF bottom spacing clamps 1–3, and HTML uses fixed padding. Zero configured feed is therefore not uniformly honored. Cutter is an optional raw `GS V` command; PDF/HTML routes do not carry it.

Cash drawer support is an optional raw `ESC p` pulse **at the start of every receipt** when enabled, including Card/E-Wallet and reprints. UI says “after print,” which differs from command ordering. No standalone Open drawer, automatic cash-only policy, or drawer confirmation exists. These commands are implemented only for raw output; physical support must be checked.

### Error and duplicate boundaries

TCP adapters return unknown if a failure occurs after transmission begins. Native direct/system catches may return failedBeforeSending after an OS submission attempt, so that status is not universally trustworthy. Browser results are submittedToDialog. The service performs no automatic retry and keeps only successful IDs in its short dedupe cache.

The browser HTML helper has an onload timer and a 1200ms fallback: if fallback prints first and onload fires later, the onload path can print again. This is a code-backed race needing browser reproduction. Body text is escaped, but the HTML title interpolates order ID without escaping. Raw text sanitizer primarily substitutes the peso symbol; ESC/GS/control bytes can survive imported text. No direct exception-to-paper fallback was found, but contaminated ordinary fields can reach paper.

### Dependencies, assets, native and build configuration

Declared versions in `pubspec.yaml`: Dart ^3.11.1; app 1.0.0+1; Flutter/Cupertino, `file_selector` ^1.0.3, `excel` ^4.0.6, `path_provider` ^2.1.6, `web` ^1.1.1, `shared_preferences` ^2.5.5, `firebase_core` ^3.12.1, `firebase_auth` ^5.5.1, `firebase_database` ^11.3.10, `cloud_functions` ^5.6.2, `firebase_data_connect` ^0.1.5+4, `printing` ^5.14.3, and `pdf` ^3.12.0; development uses flutter_test/flutter_lints. These are manifest constraints, not a claim that every package is integrated or that these are today's latest versions. Lockfiles exist. There is no direct Bluetooth/USB or ESC/POS plugin; raw commands/TCP are implemented in app code.

Declared assets are `assets/haven_logo.png` and NotoSans regular/bold fonts. Logo is used in UI, not receipts. A legacy `assets/bites_and_brew_logo.png` is undeclared/unreferenced. Android MainActivity is an empty FlutterActivity and iOS AppDelegate registers generated plugins; neither has custom printer platform channels. Android uses Java/Kotlin 17 and Flutter SDK build defaults, and release configuration uses debug signing. Main manifest lacks explicit Bluetooth/USB/network declarations, while debug/profile include Internet; dependency manifest merging must be checked before concluding release network permission is absent. iOS Info.plist lacks explicit local-network/Bluetooth/Bonjour descriptions; on-device LAN/AirPrint permission behavior needs verification. No native Firebase iOS service plist was found in the inspected file tree; native initialization/deployment requires confirmation. The checked-in `DefaultFirebaseOptions` defines web options only; main passes them explicitly only for web. Android has a native Firebase configuration file; its values are intentionally omitted here.

Web includes standard Flutter bootstrap HTML and a standalone-display manifest with application icons and portrait-primary orientation; tab/manifest branding still uses the project name. These files are IMPLEMENTED web launch metadata, not evidence of offline transaction synchronization or a separate customer app. No Windows/macOS/Linux runner directories were found. Android/iOS app icons, launch resources, and the basic iOS runner test are platform scaffolding.

No dependency, platform configuration, signing, deployment, or permission change was made.

## 16. Printer Settings

The admin Printer Settings dialog contains the following controls (`Shell:1639–2049`; Controller:1090):

| Setting / action | Actual behavior |
| --- | --- |
| Printer name | Text field; editing clears saved printer URL. Default name is GEZHI_micro_printer. |
| Saved printer URL / selection | Chosen system printer identity from plugin picker; not a Bluetooth address registry. |
| Transport | Direct print (no prompt), System dialog, Thermal printer app, Network (ESC/POS). Platform behavior varies as above. |
| Network address | Host/IP:port input for raw TCP; default parser port 9100. |
| Paper size | 50×50mm label, 58mm, 80mm; default 80mm. Not physical detection. |
| Auto print receipts | Default true; checked after paid order creation. |
| Auto cut | Default true; effective only in raw template. |
| Open cash drawer after print | Default false; raw implementation actually pulses before printing, regardless of tender. |
| Feed lines | Default 2, UI 0–8; template-specific clamps described above. |
| Auto-detect 80mm | Enumerates system printers using name keywords/default/first and forces 80mm/direct/auto-print on. |
| Check connection | Enumerates printers/matches name or URL; not network socket/physical readiness check. |
| Pick printer | Calls `Printing.pickPrinter`; availability depends on platform. |
| Save / Cancel | Save updates controller and unawaited snapshot; no persistent hardware connection. Auto-detect can already have saved before Cancel. |

Settings are saved as one selected configuration in UID-scoped local/personal cloud state. There is no per-printer map, copy count, reprint defaults, DPI/profile editor, test print, receipt-logo option, or paper AUTO mode.

Startup calls autoConfigure only when the name is legacy/default/empty or transport is System dialog (Controller:254). If a printer is found, it overwrites width to 80mm, transport to direct, and auto-print true; the `force` argument is unused. Loading settings also migrates System dialog to direct and certain legacy width/name values (Controller:400). This can override deliberate saved choices, but does not imply every custom network configuration is always reset.

`isSystemDialogSelected` is captured before the dialog's StatefulBuilder and is not recomputed when transport changes, so conditional controls can stay stale until reopening (Shell:1661). Discovery/resolution is heuristic printer selection, not capability or paper-size detection. Saved-printer misses can silently fall back to another enumerated printer, so switching/reconnect identity needs manual testing.

## 17. Sales History

Orders shows loaded recent orders with order ID, date/time, status, cashier name, payment label, distinct line count, total, and paid-only Print receipt. Search matches order ID or cashier case-insensitively. Filters are All, Today, Completed (`paid`), Cancelled (`voided`), and Refunded. There is no arbitrary date range, paging, sales export, refund/void button, or full saved-receipt viewer (Shell:828,2692).

History's displayed total is reconstructed by `_orderSummary` using fixed 12% VAT, snapshot item unit prices, stored discount application, and inferred service rate (Shell:3365). Actual printing maps the saved order totals. This distinction matters for imported records or domain-level statutory orders with other rates; ordinary inclusive totals are usually unaffected, but history is not simply displaying the persisted total.

## 18. Reports

Reports uses paid recent orders and provides week/month revenue, average order, items sold, top six product names by quantity, category bars, and Cash/Card/E-Wallet amount breakdown. “This week” is the trailing seven calendar days including today, not calendar-week start. “This month” is month-to-date (Shell:1024,1227).

Category totals sum gross line amounts, without allocating order discount/service charge, and resolve categories from the current product catalog; removed products become Other and category edits reclassify old sales. Thus category bars need not reconcile to net receipt totals. Products with the same display name are merged in the top-selling ranking.

“Today's Sales” is a persisted accumulator incremented on checkout with no date rollover/filter, so its label is not backed by a daily aggregation. Admin's separate Sales trend graphic is explicitly hardcoded demo data `[42,68,58,83,90,74,95]` for Mon–Sun (Controller:1647; Admin:456). No cashier sales, dedicated discount/tax report, custom date range, shift report, or sales report export was found.

## 19. User/Roles

Email/password sign-in, account creation, password reset, password visibility, validation, and friendly Firebase error messages exist. Auth state creates/disposes a UID-keyed controller session. No PIN, manager role, inactivity lock, MFA UI, email-verification gate, or staff invite workflow was found.

`bootstrapRole` derives an admin claim from a configured bootstrap identity or existing admin claim; other accounts receive `user`. Controller refreshes the token and maps admin to `Role.admin`, otherwise cashier; lookup failure falls back to cashier. User Access lists up to 1,000 Firebase users and lets an admin set admin/user; no pagination is implemented. Backend requires an admin claim, validates the role, and protects the bootstrap admin from demotion (functions/index.js:29–80).

Shell guards admin sections in addition to hiding their navigation. Catalog RTDB writes require admin; shared orders allow any authenticated user to write the whole node; personal snapshots require matching UID. There are no server-side order amount/status/schema validation rules in the checked-in RTDB rules. Cashier name is a saved editable display string defaulting to Alex, not automatically bound to Firebase user identity. Cashiers cannot access its Settings editor through normal navigation.

Live deployment, role-refresh timing, and identity provider configuration require manual verification. This report does not expose bootstrap identity/configuration values or credentials.

## 20. Application Settings

All Settings are admin-only through the section guard. The page displays 11 cards for admin, although its header count is hardcoded to 9 (Shell:1286).

| Setting/action | Stored behavior and status | Evidence |
| --- | --- | --- |
| Store Information | IMPLEMENTED: name, address, contact; used for receipts; main app branding remains fixed. | Shell:1396; Controller:1064 |
| Receipt Settings | IMPLEMENTED: header and footer text. | Shell:1459; Controller:1076 |
| Tax Settings | IMPLEMENTED: VAT and service-charge percentages; saved as session values. | Shell:1519; Controller:1025 |
| Currency | PRESENT BUT POSSIBLY BROKEN: code and symbol saved, but UI/receipt helpers still format pesos or P. | Shell:1584; money.dart; builders |
| Printer Settings | PARTIALLY IMPLEMENTED: transport/name/URL/paper/feed/cut/drawer/auto-print; section 16. | Shell:1639 |
| POS Preferences | IMPLEMENTED compact PDF receipt style; PRESENT BUT POSSIBLY BROKEN show-badges toggle has no rendering consumer. | Shell:2051; Controller:1142 |
| Account | IMPLEMENTED: cashier display name; role readout only. | Shell:2109 |
| User Access | IMPLEMENTED: admin/user claim changes via callable functions. | Shell:2162 |
| Appearance | PRESENT BUT POSSIBLY BROKEN: high contrast persists but is not connected to app theme. | Shell:2303; app.dart:17 |
| Restore Demo Data | PRESENT BUT POSSIBLY BROKEN as a global restore: loads repository sample and clears personal snapshots; shared catalog/orders are not reset. | Shell:2354; Controller:1160 |
| Delete All Data | PRESENT BUT POSSIBLY BROKEN as a global wipe: preserves catalog, clears personal operational state, saves snapshot; does not clear shared orders. | Shell:2393; Controller:1191 |

Reset operations also leave some printer fields untouched, including URL/feed/cut/drawer, so they are not complete configuration resets. Shared-order listeners/startup reloads can restore supposedly deleted sales. No reset was executed during discovery.

No language, payment-provider, synchronization, copy-count, role-specific discount permission, or dark-theme setting was found. JSON import can replace broader state than the visible settings dialogs.

## 21. Offline/Sync

Existing-session cart/order calculation and in-memory order creation do not require a backend call. SharedPreferences stores the working cart, settings, and operational snapshot locally. Remote reads use short timeouts and fall back to local saved state or the sample bootstrap. This is **partial offline support**, not a durable offline transaction engine.

Initialization prefers the personal remote snapshot over local state, then overlays shared catalog and orders. Saves queue personal snapshots serially, local first and RTDB second; most callers do not await them. Shared order/catalog writes are separate full-node `set()` operations. RTDB SDK behavior may retain pending writes in a running client, but no application-managed durable outbox, pending-sync status, acknowledgment ledger, conflict resolution, replay policy, or connectivity indicator exists. A timeout does not establish that the underlying SDK write was canceled.

Multiple clients can overwrite each other's complete order arrays/sales totals. Personal RTDB listeners can replace the working cart/session while it is being used. Stale shared data can overwrite locally recorded state on startup. Queue completion uses an RTDB transaction to remove a ticket, but a later stale full shared-order save can restore it. These are source-backed risks, not observed live data loss (Controller:214,1311,1345,1396,1413,1444,1459).

Offline cold-start login, token refresh, browser storage eviction, OS process termination, reconnection replay, and simultaneous multi-device checkout need manual verification. Fresh email/password authentication is not an offline login implementation.

## 22. Backend/API

There is no application REST API client. Active calls are Firebase Auth, Firebase callable Functions, and RTDB SDK operations:

| Operation | Caller / remote target | Behavior |
| --- | --- | --- |
| Sign in/register/reset/sign out | FirebaseSignInScreen / FirebaseAuth | Email/password provider; session gate listens to auth changes. |
| Role bootstrap | Controller:268 → `bootstrapRole` | 5-second callable timeout; force-refresh claims; fail closed to cashier. |
| User list / role update | Shell:2186,2209 → `listUsers`, `setUserRole` | Admin-required callable functions. |
| Personal state/settings/session | Controller:85,1528,1544 → `users/<uid>` | Read/write JSON-compatible snapshot; 3-second operations; catalog stripped before remote save. |
| Shared products/categories/modifier groups | Controller:93,1366,1429 → `store/catalog` | Authenticated read/listen, admin full replacement write. |
| Shared recent/preparation orders and sales | Controller:96,1381,1444 → `store/orders` | Authenticated full replacement write/read/listen. No checkout endpoint. |
| Remove completed preparation ticket | Controller:1459 → `store/orders/activeOrders` | RTDB transaction filters matching queue ID; 5-second timeout. |

Errors mostly fall back to local state or are swallowed; there is no application retry/backoff loop for sale creation or printing. Catalog/order listener callbacks have no explicit stream `onError`. Settings have no separate backend endpoint. No server-side payment, inventory deduction, refund, or authoritative checkout function exists.

Checked-in Data Connect schema has Product, Customer, Store, Order, OrderItem and sample create/update/delete/query operations, plus generated Dart and JS clients. They are **UNUSED/DEAD CODE for the active POS**, not proof those backend capabilities are deployed. Firestore rules/configuration are likewise inactive in the app's current persistence path. Database rules describe source configuration only; deployed rule parity was not queried.

Inactive connector operations are `CreateProducts`, `CreateCustomers`, `CreateStores`, `CreateOrders`, `UpdateProduct`, `DeleteProduct`, `GetProduct`, `ListAllProducts`, and `ListCustomerOrders`. Create operations use fixed sample payloads; product reads are public, other operations use authenticated access, and customer-order lookup includes an auth-UID predicate. Generated clients reflect those operations rather than the richer Flutter POS domain. PostgreSQL/Data Connect configuration is present but is not used by Controller or Repository.

Functions package targets Node 24 with `firebase-admin` ^13.6.0 and `firebase-functions` ^7.0.0; functions are v2 callable handlers, with a maximum-instance setting of 10. Root JavaScript dependencies are Firebase ^12.18.0 and the local generated connector. These are checked-in configuration facts, not verified service deployment state.

Deployment scaffolding includes Firebase Functions, Data Connect, Firestore, RTDB, App Hosting config, and a PR Hosting workflow. The PR workflow runs `npm run build`, but root package.json declares no build script; firebase.json also lacks a classic Hosting block. That workflow is PRESENT BUT POSSIBLY BROKEN as checked in; it was not executed or repaired.

## 23. Local Storage

SharedPreferences persists a version-3 JSON snapshot under `bites_brew_reset_snapshot` plus the UID (guest fallback is supported in code/tests). Legacy unscoped/reset-flag keys are migrated. Snapshot includes categories/products/modifier groups, inventory, customers, recent/active orders, shifts, sales accumulator, settings, cart lines, fixed discount, VAT/service rates, cash, selected payment and customer (Controller:438,1274,1329).

No SQLite, Hive, app-managed secure storage, durable print-job database, or separate immutable transaction journal exists. Firebase's own authentication storage is SDK-managed. Print deduplication and last-50-job history are memory-only. Logout waits for the personal persistence queue but not all separate shared writes; best-effort failures are still treated as completed attempts.

JSON export is a full state backup, not just a product list. Import applies broad state and queues a personal snapshot save, but does not explicitly publish shared catalog or shared order replacements; other clients/shared overlays may restore previous data. XLSX imports specifically publish catalog replacements; inventory remains personal.

File exports use browser Blob download or native Downloads/document/temporary-directory fallbacks (`export_writer.dart`, `export_writer_io.dart`, `export_writer_web.dart`). Export success is not remote backup or synchronization. Actual browser binary-download and Android scoped-storage behavior require manual verification.

## 24. Error Handling

| Area | Observed handling | Limitation |
| --- | --- | --- |
| Firebase initialization | Caught and displayed in unavailable screen. | No offline bypass from an uninitialized app. |
| Auth | Friendly Firebase error mapping; busy controls. | Provider/live configuration unverified. |
| Role lookup | Catch → cashier role. | Admin may appear restricted when callable/token refresh fails. |
| Local/remote persistence | Short timeout; catches usually ignored. | A paid/saved success message can outlive failed storage. |
| Startup/import/listeners | JSON parsing; import snackbar; personal listener catches FormatException. | Typed casts/other errors and stream failures are not comprehensively caught; initial malformed snapshot may leave loading unresolved. |
| Checkout | Invalid cart/cash returns null; repository awaited. | No overall checkout catch/busy state in Charge handlers. |
| Print validation/render | Fails before adapter; structured log/result. | Validation does not prove all text is safe or all numeric relationships valid. |
| Print transmission | Status result, UI snackbar, developer logs. | Delivery ambiguity/status classification differs by adapter. |
| Admin import/export | Format/general catches and snackbars. | Imports are not a transactional validate-all-then-commit pipeline. |

No code path was found that deliberately sends a caught API/database/Bluetooth exception or stack trace to a printer, saves the exception itself as an order, or echoes it to a backend. Financial API responses do not drive checkout because no such API is integrated.

However, imported/database/settings strings are trusted as product/receipt content. Structurally valid error text can be shown as product/order data, stored in snapshots, and printed as ordinary content. Raw ESC/POS string sanitization and browser HTML interpolation have specific gaps described in sections 14–15/27. Full error-text exclusion is therefore **not guaranteed**. The financial validator checks subtotal and total equations but not `quantity × unitPrice == lineTotal`, has five-cent tolerances, and does not validate every tax-breakdown field.

## 25. Duplicate Protection

| Operation | Existing protection | Missing/limited protection |
| --- | --- | --- |
| Charge / sale creation | Invalid/empty cart and insufficient cash disable Charge. | No in-flight mutex; repeated taps before await completes can create two records. |
| Payment submission | No provider call. | No actual payment authorization/idempotency to assess. |
| Order identity | Session-local sequence. | No stable globally unique ID or restart-safe counter. |
| Shared save | Personal snapshots serialized. | Shared snapshots are separate, full replacement; no per-sale dedupe or merge. |
| Inventory deduction | No deduction is implemented. | Absence of deduction is not duplicate-deduction protection. |
| Preparation Complete | Dialog busy state; absent ticket returns false; remote transactional removal. | ID collisions/full stale saves can remove or resurrect wrong ticket sets. |
| Automatic prints | Serialized queue; successful receipt ID cached for 15 seconds. | Cache is memory-only, ID-only, and success-only; restart/unknown results not durably guarded. |
| Manual reprint | Per-history-card `_isPrinting` disables repeated taps while awaiting. | `manualReprint:true` bypasses service dedupe; other cards/sessions/remounts have no shared reprint lock. |
| Print retries | No blind automatic retry loop found; unknown result tells user to inspect printer. | Another explicit request after an ambiguous result can transmit again. |

The automatic-print timestamp is captured before rendering/transmission, so a sufficiently long job can consume the entire deduplication window before completion. Print job IDs include only second precision plus sanitized order ID and can repeat for same-order requests within one second. Neither queue serialization nor the 15-second cache provides exactly-once printing (thermal_printer_service.dart:77–95,201,250).

## 26. Critical Flow Traces

### Flow A — Product → Cart → Checkout → Payment label → Saved order → Receipt → Printer

1. **Product/UI:** Cashier grid/search selects a Product, opens `_showProductCustomizer`, returns quantity/modifiers. Controller `addProductToCart` merges or creates a line, notifies listeners, queues snapshot saves (Cashier:2161; Controller:873).
2. **Calculation:** `checkoutSummary` calls Calculator over cart snapshots. Tender/type setters update state and enqueue saves. No network payment authorization occurs (Controller:195,1037–1055).
3. **Charge:** either responsive handler awaits `checkout`. Controller checks `canCheckout` then copies draft lines, prices/modifier labels and financial configuration (Cashier:2617,2922; Controller:1598).
4. **Creation:** Repository recalculates draft totals after its artificial delay, creates `ORD-N` with `paid`, and adds to its private list. No backend order endpoint/database transaction is involved (Repository:22; Models:853).
5. **State:** controller inserts recent order and `Q-N` preparing ticket, increments sales, clears cart without a separate immediate persist. Customer name is copied to queue only; inventory is untouched (Controller:1633).
6. **Writes:** `_saveCurrentStateSnapshot` captures JSON and serializes SharedPreferences + personal RTDB writes. `_saveSharedOrders` replaces shared orders/sales. Failures are swallowed/returned false; checkout still returns the order (Controller:1311,1444,1649).
7. **Receipt:** if auto-print enabled, `controller.printReceipt` passes the saved order and current store/printer settings to receipt facade. Service validates/builds complete output in memory, then invokes an adapter. No order rollback/recreation occurs (Controller:1655; receipt_printer.dart; thermal_printer_service.dart).
8. **Delivery/UI:** raw TCP writes bytes; native printing submits PDF; browser opens print dialog; helper shares PDF. Print failures/unknown/cancel yield snackbar/logs; paid-order snackbar still follows. No physical success can be inferred solely from submission. No receipt is printed when auto-print is off.

Failure boundaries: pre-checkout invalid cart/cash prevents creation; concurrent Charge lacks a guard; persistence failure does not reverse paid state; validation/render failure prevents adapter invocation; post-transmission ambiguity needs manual reconciliation. No call in the print branch repeats checkout or deducts inventory.

### Flow B — Paid Order → History → Reprint → Printer

1. Controller history is loaded from local/personal/shared snapshots; Orders filters it by ID/cashier/date/status (Shell:828).
2. `_HistoryOrderCard` enables Print receipt only for `paid` and when that card is not already printing. It sets `_isPrinting=true` and calls `controller.printReceipt(order, manualReprint:true)` (Shell:2692,2738).
3. Existing snapshot line/financial data becomes ReceiptData. Current store text and printer settings are used, so a reprint is not a frozen copy of old store branding/configuration.
4. Service serializes, bypasses the recent-success dedupe for explicit reprint, validates/renders, submits adapter output, and records a memory-only print diagnostic. **No repository `createOrder`, payment call, inventory update, or sale database write occurs.**
5. UI reports dialog opened/sent/unknown/canceled/failure and releases the card guard in `finally`. There is no printed REPRINT watermark or persistent reprint count. Actual delivery needs manual confirmation.

### Flow C — Printer Settings → Select → Check → Save → Print

1. Admin opens `_editPrinterSettings`; local dialog variables copy controller printer name/URL/transport/paper/feed/cut/drawer/auto-print (Shell:1639).
2. Pick printer uses the `printing` plugin picker; Auto-detect invokes the resolver and controller auto-configuration; manual network target uses host/port text. There is no in-app Bluetooth pairing or USB endpoint selection.
3. Check connection enumerates system printers and matches names/URLs; it does not establish a persistent connection, verify physical paper width, or use the raw TCP availability method for the selected transport (Shell:1664).
4. Save calls `updatePrinterSettings`, normalizes/clamps values, and queues local/personal RTDB snapshot persistence. Auto-detect can already have changed/persisted controller configuration before dialog Save. Cancel is therefore not a universal rollback of auto-detection side effects.
5. Later checkout/reprint builds PrinterConfig. Native resolver chooses configured/system printer or fallback; network route opens a socket per job; browser uses a dialog. Receipt preparation precedes transmission. Settings Save itself does not print or pair/connect hardware.
6. Discovery failure and adapter unsupported/connection errors return UI messages/results. Saved system-dialog/name defaults may trigger later auto-configuration and overwrite paper/transport/auto-print choices. Width is not detected from hardware.

## 27. Known Problems

These are source-backed problems or risks, not new implementation requests. “Expected” below describes the relevant production invariant; reproduction directions are proposed checks unless explicitly covered by an executed test.

| ID / severity / status | Evidence and actual behavior | Reproduction / expected behavior / investigation |
| --- | --- | --- |
| K01 High — PRESENT BUT POSSIBLY BROKEN | Charge and Controller have no busy guard; async Repository delays before creating. Cashier:2617,2922; Controller:1598. | Rapidly tap Charge with nonempty cart; two invocations can copy same cart. Expect one intentional sale. Investigate UI/controller in-flight protection and durable idempotency. |
| K02 High — PRESENT BUT POSSIBLY BROKEN | Repository private counter resets; IDs `ORD-N`/`Q-N` reused. Repository:12,62; Models:859. | Create sale, start new session, create another; same sequence can recur. Expect unique durable identity. Investigate sequence/ID generation and print/queue identity effects. |
| K03 High — PRESENT BUT POSSIBLY BROKEN | Shared `set()` replaces all order arrays/totals; exceptions are ignored for checkout success. Controller:1444,1649. | Two clients save from different snapshots or storage fails. Expect preserved sales with known commit status. Investigate append-only writes, authoritative commit and conflict policy. |
| K04 High — PARTIALLY IMPLEMENTED | Card/E-Wallet immediately become paid with no authorization; inventory not deducted. Repository:22; Controller:1598. | Select noncash and Charge; local paid record results. These are incomplete integrations, not evidence that an external payment failed. |
| K05 Medium — PRESENT BUT POSSIBLY BROKEN | `todaySales` has no date rollover; Admin trend static. Controller:1647; Admin:456. | Compare next-day dashboard to dated history. Expect clearly scoped real sales. Investigate aggregation/fixture labeling. |
| K06 Medium — PRESENT BUT POSSIBLY BROKEN | Currency/high-contrast/badges persist without renderer consumers. Shell settings; app.dart; money helpers. | Change each setting and inspect actual UI. Expect corresponding presentation change. Investigate missing consumers. |
| K07 High — PRESENT BUT POSSIBLY BROKEN | Reset/import do not clear/republish shared orders/catalog consistently. Controller:462,1160,1191. | Reset personal state then reopen with shared orders present. Expect documented reset scope; shared overlay may restore data. Investigate scope and listener ordering before any destructive action. |
| K08 Medium — PRESENT BUT POSSIBLY BROKEN | Held resume rebuilds current/default modifiers/prices and replaces cart. Controller:976. | Import held customized ticket, Continue after menu change. Expect deliberate preservation/repricing policy. Investigate snapshot restoration and paid-state linkage. |
| K09 Medium — PRESENT BUT POSSIBLY BROKEN | Raw ESC/POS stays 48 columns for 58/50mm selection. PrinterConfig default; receipt facade. | Print long receipt on narrow printer. Expect width-aware layout; actual clipping requires hardware test. |
| K10 Medium — PRESENT BUT POSSIBLY BROKEN | Auto-configuration forces 80mm/direct/auto-print; saved dialog mode migrated. Controller:400,1121. | Save narrow/dialog setting then restart under trigger conditions. Expect preserved intentional configuration. Investigate auto-config trigger/force semantics. |
| K11 High — PRESENT BUT POSSIBLY BROKEN | Raw text permits control characters; browser title has unescaped order ID. ESC/POS `_sanitize`; HTML builder. | Supply controlled imported receipt strings in a nonphysical test. Expect content escaping/control filtering. No malicious payload was sent to hardware. |
| K12 Medium — PRESENT BUT POSSIBLY BROKEN | Late browser load callback can follow fallback print invocation; native errors can be classified before-send after submission. Web HTML/native adapters. | Delay iframe loading or induce print-plugin failure; expect one invocation and accurate ambiguity status. Requires browser/OS verification. |
| K13 Medium — PARTIALLY IMPLEMENTED | Drawer pulse applies to all raw receipts including reprints/noncash, at receipt start. ESC/POS generator. | Enable drawer and inspect raw command ordering; expect documented cash-only policy if required. Physical drawer was not exercised. |
| K14 Medium — PRESENT BUT POSSIBLY BROKEN | Checkout/storage/listener handling can silently lose persistence or leave startup loading on malformed data. Controller:214,1329,1345. | Inject malformed test snapshot or storage error; expect visible recoverable failure. Investigate robust validation and persistence acknowledgments. |
| K15 Low — PRESENT BUT POSSIBLY BROKEN | PR workflow invokes missing npm build script and lacks classic Hosting config. package.json; .github/workflows/firebase-hosting-pull-request.yml. | Evaluate workflow in CI; no deployment was attempted. Investigate intended Flutter build/deploy target. |

## 28. Partially Implemented Features

Operational gaps with existing code/UI: tender recording without gateway confirmation; local sale creation without authoritative backend commit/idempotency; offline snapshots without durable replay/conflict policy; inventory CRUD without product/ingredient linkage; customer selection without customer CRUD/paid-order linkage; shift counts without shift operations; held/status models without full lifecycle controls; discount math without cashier application UI; narrow-paper selection without matching raw text width; helper/OS printer support without direct Bluetooth/USB transport; drawer flag without tender/reprint policy; mutable current store settings on reprints; and preferences whose values are saved but not consumed.

The matrix gives each investigated subfeature its own status. Existing calculation/template tests do not make the missing operational UI or hardware integration implemented.

## 29. Dead/Unused Functionality

| Code | Status / actual reachability |
| --- | --- |
| `lib/dataconnect_generated/`, `src/dataconnect-generated/`, Data Connect schema/operations | UNUSED/DEAD CODE in running POS; generated scaffold has no active UI/controller caller. |
| Firestore rules/config | UNUSED/DEAD CODE for current persistence; actual calls use RTDB. |
| `toggleRole()` | UNUSED/DEAD CODE: explicit no-op; roles come from claims (Controller:551). |
| Category `addCategory/updateCategory/deleteCategory` | UNUSED/DEAD CODE from UI perspective; default/import category resolution is used. |
| `OrderRecord.fromDraft` | UNUSED/DEAD CODE: throws UnsupportedError; active path uses calculated totals (Models:847). |
| `cancelPrint()` | UNUSED/DEAD CODE: empty implementation. |
| `isPrinterAvailable()` API / `recentJobs` getter | PARTIALLY IMPLEMENTED service APIs with no UI consumer; dialog check uses its own enumeration. |
| Senior/PWD/percentage discount types | PARTIALLY IMPLEMENTED domain code used by tests/imported records, not regular cashier checkout. |
| `resetAllData()` / controller compatibility helpers | No active screen caller found; Settings uses restoreDemoData/deleteAllData. |
| `test/scratch_pdf_test.dart` | Developer experiment, not runtime template; writes a PDF to an absolute developer-specific path. Excluded from executed test selection. |
| `public/index.html` / basic README | Scaffolding; not evidence of an additional POS UI or production deployment. |

Conditional platform stubs are not classified as dead merely because they are inactive on one platform: they supply explicit unsupported behavior for the corresponding build targets.

## 30. Features Requiring Manual Verification

No production backend writes, live account administration, physical prints, payments, or destructive reset/import operations were performed. Runtime statements are bounded by source inspection and the existing local tests below.

| Area | Manual verification still required |
| --- | --- |
| Authentication/deployment | Android/iOS/web Firebase setup; provider enablement; callable deployment; role refresh; deployed rule parity. |
| Sale integrity | Rapid taps, process death between creation/save, reopened sessions, simultaneous clients, queue completion races and stale overwrites. |
| Offline | Authenticated cold restart, offline creation/reconnect, stale remote overwrite, durable recovery, storage failure/eviction. |
| Printers | Real 58/80mm and unknown printer, no paper-size reporting, saved size, switching/reconnect, long receipts, glyphs, margins and clipping. |
| Transports | OS drivers/direct availability; helper-app receipt handling; indirect Bluetooth/USB; TCP disconnection before/during send; iOS LAN access; browser dialog timing. |
| Zero paper waste | Induce validation/formatting failures and verify zero transmitted bytes/feed/error text on actual hardware; fake-adapter test only proves no adapter call. |
| Duplicates/reprints | Repeated card taps, remount/multi-session reprints, >15-second jobs, unknown delivery, browser fallback/onload timing. |
| Cash drawer/cutter | Actual pulse/cut support, command ordering, noncash/reprint behavior; disabled-by-default drawer flag. |
| Receipt content | Long names, very large quantities/totals, special characters, stored tax/discount variants, nondefault VAT, immutable financial reprint data. |
| File operations | Browser XLSX binary downloads, Android scoped storage, malformed imports, confirmation/cancel behavior and shared-state effects. |
| Responsive UI | Phone/tablet/landscape layout, accessibility, customizer limits, stale transport controls. |

QR/barcode/logo failure paths cannot be tested as implemented receipt features because these receipt features are absent; their absence is documented rather than a fabricated test result.

### Executed validation

`flutter test --no-pub` was run against these eight existing files: `checkout_calculator_test.dart`, `coffee_pos_controller_test.dart`, `money_test.dart`, `receipt_calculation_and_validation_test.dart`, `thermal_printer_service_test.dart`, `web_receipt_html_builder_test.dart`, `pdf_receipt_builder_test.dart`, and `widget_test.dart`.

**Result: 44 tests passed.** Coverage includes arithmetic/VAT examples, snapshot preservation, queue completion, receipt consistency, invalid receipt rejection before the fake adapter, print serialization/deduplication/result handling, printer selection heuristics, HTML layout assertions, and Firebase-unavailable rendering. The widget test name says POS shell but actually asserts the Firebase-unavailable screen. The standalone PDF page-count test prints diagnostics without page-count assertions; passing it does not certify long-receipt pagination. `scratch_pdf_test.dart` was inspected but not run because it writes to a developer-specific external path.

Independent QA inventory review and PM final acceptance are recorded here after document review. These reviews assess discovery accuracy/completeness, not production readiness.

## 31. Potential Missing Features

**Recommendations for future prioritization only — not existing requirements or authorization to implement.**

- Durable unique transaction IDs, authoritative/idempotent sale commits, explicit sync/commit status, and conflict-safe offline recovery.
- In-flight checkout protection, controlled refunds/voids, manager approvals, and a transaction/reprint audit trail.
- Real payment authorization/reference capture, QR payment integration, and split tender if store operations need them.
- Product/ingredient stock linkage, recipe deductions, wastage/restocking history, and automatic stock availability.
- Shift opening/closing cash, cash count/reconciliation, cashier reporting, and drawer-access policy.
- Cashier discount controls/approvals with a reviewed eligibility and tax policy; no compliance claim is made by this inventory.
- Drink temperature/sugar/ice options, preparation notes, food extras/allergen information where needed.
- Complete customer creation/loyalty/order linkage; optional table/delivery/customer-display workflows.
- Per-printer settings, verified narrow-paper layouts, safe ambiguous-delivery recovery, and supported hardware transport choices.
- Real daily aggregates, meaningful trend data, date ranges, sales exports, and settings that visibly affect the UI.

No fixes or new features are part of this discovery task.
