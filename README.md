# Pantry

A household groceries and inventory tracker for Android, built with Flutter. Scan barcodes to add items, track expiry dates and storage locations, deduct stock as you use things up, and keep the whole household in sync through a shared Google Sheet.

## Screenshots

| Home | Add item | Locations | Settings |
|---|---|---|---|
| ![Home screen](screenshots/screen_home.png) | ![Add item sheet](screenshots/screen_add.png) | ![Locations tab](screenshots/screen_locations.png) | ![Settings page](screenshots/screen_more.png) |

## Features

- **Custom branded UI** — bottom navigation (Home / Locations / Shopping) with a floating add button, hero stat cards, and a color-coded category system, themed around the app's own logo
- **Barcode scanning** — scan to add items, with a flashlight toggle for low light, automatic name lookup (Open Food Facts), and a local barcode→name memory that works offline and covers products the online database doesn't have
- **Categories** — Produce, Dairy, Meat & Fish, Rice & Grains, Noodles & Pasta, Canned & Jarred Goods, Sauces & Condiments, Spices & Seasoning, Baking Supplies, Pantry, Frozen, Bakery, Drinks, Snacks, Toiletries, Cleaning Supplies, Personal Care, Household, Other — each with its own color and icon
- **Units** — 23 options covering pcs, weight, volume, and common packaging (g, kg, ml, L, oz, lb, gallon, dozen, pack, box, bottle, can, jar, bag, carton, roll, tube, sachet, tablet, set, pair, bunch)
- **Full item editing** — tap any item to edit every field (name, qty, unit, category, status, price, location, expiry, photo), not just add it once and be stuck
- **Expiry tracking** — a dedicated "Expiring soon" strip on the Home screen surfaces anything close to its expiry date, plus a shopping list for whatever's running low, out, or about to expire
- **Storage locations** — tag items with freeform locations (e.g. "Kitchen Fridge", "Garage Freezer") and browse inventory by location
- **Photos** — attach a photo to any item (stored locally on-device)
- **Consume / deduct flow** — scan or tap an item to mark it used, without digging through a form
- **Purchase history** — every addition is logged, and past entries can be edited or deleted if something was recorded wrong
- **Safer deletes** — swiping an item to delete requires confirmation, and a "Recently deleted" screen lets you restore (or permanently remove) anything soft-deleted
- **Multi-currency** — MYR by default, switchable to USD, SGD, EUR, GBP, JPY, CNY, IDR, THB, AUD
- **Multi-language UI** — English, Chinese (中文), and Malay (Bahasa Melayu)
- **Google Sheets sync** — connect a Google account and link a spreadsheet to back up and share your inventory across devices. Sync merges changes per item (newest edit wins, nothing is silently overwritten) so multiple household members can use the app against the same spreadsheet without clobbering each other's edits
- **Works without Google Play Services** — sign-in uses a device-code OAuth flow (open a link, type a code) rather than the native Google Sign-In SDK, so it works on Huawei/HarmonyOS phones and other devices without GMS

## Tech stack

- [Flutter](https://flutter.dev) (single-file app, `lib/main.dart`) targeting Android
- [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) for barcode scanning
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) for local storage
- Plain REST calls to the [Google Sheets API v4](https://developers.google.com/sheets/api) and Google's [OAuth 2.0 device authorization](https://developers.google.com/identity/protocols/oauth2/limited-input-device) endpoint — no Google Play Services dependency

## Building

```bash
flutter pub get
flutter build apk --release
```

The output APK is at `build/app/outputs/flutter-apk/app-release.apk`. Sideload it with:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Setting up Google Sheets sync

Sync is optional — the app works fully offline without it. To enable it for your own build:

1. Create a project in [Google Cloud Console](https://console.cloud.google.com)
2. Enable the **Google Sheets API** and **Google Drive API**
3. Configure the OAuth consent screen (External, Testing mode is fine) and add your Google account as a test user
4. Create an OAuth client of type **"TVs and Limited Input devices"** — this returns a Client ID and Client Secret
5. Set `DeviceFlowAuth.clientId` and `DeviceFlowAuth.clientSecret` in `lib/main.dart` to your own values

(These credentials aren't confidential for this client type — see [Google's docs](https://developers.google.com/identity/protocols/oauth2/limited-input-device) — but if you'd rather keep your own out of a public fork, move them into a separate gitignored file instead.)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a dated history of what's changed.

## License

Personal project, no license specified.
