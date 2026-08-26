# Changelog

Dates below match the actual commit history (`git log`), oldest first.

## 2026-08-17 — Initial build and sync

- First working version: barcode scanning, categories, expiry tracking, freeform storage locations, a consume/deduct flow, purchase history, multi-currency, and a English/Chinese/Malay UI
- Google Sheets sync, built twice in the same day:
  - First pass used native Google Sign-In
  - Reworked to a device-code OAuth flow after finding it needs to work on phones without Google Play Services (e.g. Huawei/HarmonyOS)
  - Sync merges changes per item (newest edit wins) with soft-delete tombstones, instead of one device's push overwriting another's, so multiple people can share one spreadsheet safely
  - Auto-syncs on app open, not just after each edit
- Added units (pcs, g, kg, ml, L, etc.) and photo capture per item
- Wrote the initial README

## 2026-08-24 — Visual redesign

- Rebranded the UI around the app's own logo: warm orange accents, deep green app bar, cream background
- Replaced the top tab bar with bottom navigation (Home / Locations / Shopping), a floating add button that opens the add form as a bottom sheet, and hero stat cards
- Color-coded categories with their own icons across item cards, chips, and section headers
- Flatter, rounded item cards; status shown as a tappable colored badge instead of a dropdown
- Generated a real app icon from the logo (replacing the default Flutter icon)
- Updated the README with real app screenshots

## 2026-08-26 — Editing, safety, and scanner fixes

- Added a full "Edit item" sheet — tap any item to edit name, qty, unit, category, status, price, location, expiry, and photo (previously only addable once, not editable)
- Expanded the unit list from 9 to 23 options, and categories from 13 to 19 (added Rice & Grains, Noodles & Pasta, Canned & Jarred Goods, Sauces & Condiments, Spices & Seasoning, Baking Supplies), with matching quick-add presets and auto-category guesses
- Added an "Expiring soon" strip to the Home screen
- Redesigned the item card into a calmer vertical layout (was cramming photo/qty/name/badges/status/delete into one row)
- Made swipe-to-delete require confirmation, and added a "Recently deleted" screen to restore or permanently remove soft-deleted items — after an accidental swipe-delete with no way to recover
- Clamped system text scaling so an extreme accessibility font-size setting can't break the compact card layouts (this is what caused a category badge to render as "Toiletrie"/"s" split across two lines on one device)
- Fixed barcode scanning: removed an overly narrow barcode-format allowlist that could silently fail to detect valid barcodes, and added a flashlight toggle for low light
- Updated the README to match
