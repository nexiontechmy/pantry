import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const PantryApp());

const List<String> kCats = [
  'Produce', 'Dairy', 'Meat & Fish',
  'Rice & Grains', 'Noodles & Pasta', 'Canned & Jarred Goods',
  'Sauces & Condiments', 'Spices & Seasoning', 'Baking Supplies',
  'Pantry', 'Frozen', 'Bakery', 'Drinks', 'Snacks',
  'Toiletries', 'Cleaning Supplies', 'Personal Care',
  'Household', 'Other'
];
const List<String> kUnits = [
  'pcs', 'g', 'kg', 'ml', 'L', 'oz', 'lb', 'gallon', 'dozen',
  'pack', 'box', 'bottle', 'can', 'jar', 'bag', 'carton',
  'roll', 'tube', 'sachet', 'tablet', 'set', 'pair', 'bunch',
];
const List<String> kDefaultLocations = [
  'Kitchen Fridge', 'Kitchen Freezer', 'Kitchen Pantry',
  'Bathroom Cabinet', 'Laundry Room', 'Garage Storage',
];
const List<String> kPresets = [
  'Milk', 'Eggs', 'Bread', 'Butter', 'Cheese', 'Yogurt',
  'Coffee', 'Tea', 'Water', 'Juice',
  'Rice', 'Noodles', 'Instant noodles', 'Pasta', 'Flour', 'Sugar', 'Salt',
  'Cooking oil', 'Soy sauce', 'Oyster sauce', 'Black pepper', 'Cereal',
  'Canned tuna', 'Canned beans',
  'Bananas', 'Apples', 'Tomatoes', 'Onions', 'Potatoes', 'Lettuce',
  'Chicken', 'Beef', 'Fish',
  'Chips', 'Cookies',
  'Toilet paper', 'Dish soap', 'Detergent', 'Toothpaste', 'Shampoo',
];
const Map<String, String> kCatGuess = {
  'Milk': 'Dairy', 'Eggs': 'Dairy', 'Butter': 'Dairy', 'Cheese': 'Dairy', 'Yogurt': 'Dairy',
  'Bread': 'Bakery',
  'Coffee': 'Drinks', 'Tea': 'Drinks', 'Water': 'Drinks', 'Juice': 'Drinks',
  'Rice': 'Rice & Grains',
  'Noodles': 'Noodles & Pasta', 'Instant noodles': 'Noodles & Pasta', 'Pasta': 'Noodles & Pasta',
  'Flour': 'Baking Supplies', 'Sugar': 'Baking Supplies',
  'Salt': 'Spices & Seasoning', 'Black pepper': 'Spices & Seasoning',
  'Cooking oil': 'Sauces & Condiments', 'Soy sauce': 'Sauces & Condiments', 'Oyster sauce': 'Sauces & Condiments',
  'Canned tuna': 'Canned & Jarred Goods', 'Canned beans': 'Canned & Jarred Goods',
  'Cereal': 'Pantry',
  'Bananas': 'Produce', 'Apples': 'Produce', 'Tomatoes': 'Produce',
  'Onions': 'Produce', 'Potatoes': 'Produce', 'Lettuce': 'Produce',
  'Chicken': 'Meat & Fish', 'Beef': 'Meat & Fish', 'Fish': 'Meat & Fish',
  'Chips': 'Snacks', 'Cookies': 'Snacks',
  'Toilet paper': 'Toiletries', 'Dish soap': 'Cleaning Supplies', 'Detergent': 'Cleaning Supplies',
  'Toothpaste': 'Personal Care', 'Shampoo': 'Personal Care',
};
const int kSoonDays = 4;
const Map<String, String> kStatusLabel = {'ok': 'In stock', 'low': 'Low', 'out': 'Out'};
const Map<String, String> kCurrencySymbols = {
  'MYR': 'RM', 'USD': r'$', 'SGD': r'S$', 'EUR': '€', 'GBP': '£',
  'JPY': '¥', 'CNY': '¥', 'IDR': 'Rp', 'THB': '฿', 'AUD': r'A$',
};

const Color kGreen = Color(0xFF22C55E);
const Color kWarn = Color(0xFFF59E0B);
const Color kDanger = Color(0xFFEF4444);
const Color kPurple = Color(0xFFA855F7);

// Brand palette (from the app logo) — used for primary/interactive accents.
// kGreen above stays reserved for the "in stock" status signal.
const Color kBrand = Color(0xFFF0803D);
const Color kBrandDeep = Color(0xFF1F4B36);
const Color kCream = Color(0xFFFAF3E8);

// ---------------------------------------------------------------------------
// Lightweight translation layer (English / Chinese / Malay).
String gLang = 'en';
const List<String> kLangs = ['en', 'zh', 'ms'];
const Map<String, String> kLangNames = {'en': 'English', 'zh': '中文', 'ms': 'Bahasa Melayu'};

String tr(String key) => kTr[key]?[gLang] ?? kTr[key]?['en'] ?? key;

const Map<String, Map<String, String>> kCatTr = {
  'Produce': {'zh': '生鲜蔬果', 'ms': 'Sayur & Buah'},
  'Dairy': {'zh': '乳制品', 'ms': 'Tenusu'},
  'Meat & Fish': {'zh': '肉类与海鲜', 'ms': 'Daging & Ikan'},
  'Rice & Grains': {'zh': '大米谷物', 'ms': 'Beras & Bijirin'},
  'Noodles & Pasta': {'zh': '面条意面', 'ms': 'Mi & Pasta'},
  'Canned & Jarred Goods': {'zh': '罐头与瓶装食品', 'ms': 'Makanan Tin & Balang'},
  'Sauces & Condiments': {'zh': '酱料调味品', 'ms': 'Sos & Perencah'},
  'Spices & Seasoning': {'zh': '香料调味', 'ms': 'Rempah & Perasa'},
  'Baking Supplies': {'zh': '烘焙材料', 'ms': 'Bekalan Bakeri'},
  'Pantry': {'zh': '干货食材', 'ms': 'Bekalan Dapur'},
  'Frozen': {'zh': '冷冻食品', 'ms': 'Makanan Beku'},
  'Bakery': {'zh': '烘焙食品', 'ms': 'Bakeri'},
  'Drinks': {'zh': '饮料', 'ms': 'Minuman'},
  'Snacks': {'zh': '零食', 'ms': 'Snek'},
  'Toiletries': {'zh': '洗漱用品', 'ms': 'Alat Mandian'},
  'Cleaning Supplies': {'zh': '清洁用品', 'ms': 'Bekalan Pembersihan'},
  'Personal Care': {'zh': '个人护理', 'ms': 'Penjagaan Diri'},
  'Household': {'zh': '家居用品', 'ms': 'Barangan Rumah'},
  'Other': {'zh': '其他', 'ms': 'Lain-lain'},
};
String catLabel(String cat) => kCatTr[cat]?[gLang] ?? cat;

const Map<String, Color> kCatColors = {
  'Produce': Color(0xFF639922),
  'Dairy': Color(0xFF378ADD),
  'Meat & Fish': Color(0xFFD85A30),
  'Rice & Grains': Color(0xFFC9A227),
  'Noodles & Pasta': Color(0xFFE0793F),
  'Canned & Jarred Goods': Color(0xFF6B7280),
  'Sauces & Condiments': Color(0xFFB5442E),
  'Spices & Seasoning': Color(0xFF8B5E3C),
  'Baking Supplies': Color(0xFFDB7093),
  'Pantry': Color(0xFFBA7517),
  'Frozen': Color(0xFF185FA5),
  'Bakery': Color(0xFF993C1D),
  'Drinks': Color(0xFF0F6E56),
  'Snacks': Color(0xFF993556),
  'Toiletries': Color(0xFF534AB7),
  'Cleaning Supplies': Color(0xFF3C3489),
  'Personal Care': Color(0xFFD4537E),
  'Household': Color(0xFF5F5E5A),
  'Other': Color(0xFF888780),
};
const Map<String, IconData> kCatIcons = {
  'Produce': Icons.eco,
  'Dairy': Icons.egg,
  'Meat & Fish': Icons.set_meal,
  'Rice & Grains': Icons.rice_bowl,
  'Noodles & Pasta': Icons.ramen_dining,
  'Canned & Jarred Goods': Icons.inventory_2,
  'Sauces & Condiments': Icons.local_bar,
  'Spices & Seasoning': Icons.grain,
  'Baking Supplies': Icons.cake,
  'Pantry': Icons.kitchen,
  'Frozen': Icons.ac_unit,
  'Bakery': Icons.bakery_dining,
  'Drinks': Icons.local_cafe,
  'Snacks': Icons.cookie,
  'Toiletries': Icons.soap,
  'Cleaning Supplies': Icons.cleaning_services,
  'Personal Care': Icons.spa,
  'Household': Icons.home,
  'Other': Icons.category,
};
Color catColor(String cat) => kCatColors[cat] ?? kCatColors['Other']!;
IconData catIcon(String cat) => kCatIcons[cat] ?? Icons.category;

const Map<String, Map<String, String>> kTr = {
  'tipConsume': {'en': 'Use / consume item', 'zh': '取用 / 消耗物品', 'ms': 'Guna / Habiskan barang'},
  'tipTheme': {'en': 'Toggle theme', 'zh': '切换主题', 'ms': 'Tukar tema'},
  'tipData': {'en': 'Data / backup', 'zh': '数据 / 备份', 'ms': 'Data / sandaran'},
  'statItems': {'en': 'Items', 'zh': '物品', 'ms': 'Barang'},
  'statLow': {'en': 'Low', 'zh': '库存低', 'ms': 'Stok Rendah'},
  'statOut': {'en': 'Out', 'zh': '缺货', 'ms': 'Habis'},
  'statusInStock': {'en': 'In stock', 'zh': '有库存', 'ms': 'Ada Stok'},
  'statExpiring': {'en': 'Expiring', 'zh': '即将过期', 'ms': 'Hampir Luput'},
  'tabInventory': {'en': 'Inventory', 'zh': '库存', 'ms': 'Inventori'},
  'tabLocation': {'en': 'By Location', 'zh': '按位置', 'ms': 'Mengikut Lokasi'},
  'tabShopping': {'en': 'Shopping', 'zh': '购物清单', 'ms': 'Senarai Beli-belah'},
  'hintSearch': {'en': 'Search…', 'zh': '搜索…', 'ms': 'Cari…'},
  'sortCategory': {'en': 'Category', 'zh': '分类', 'ms': 'Kategori'},
  'sortName': {'en': 'Name', 'zh': '名称', 'ms': 'Nama'},
  'sortExpiry': {'en': 'Expiry', 'zh': '有效期', 'ms': 'Tarikh Luput'},
  'sortStatus': {'en': 'Status', 'zh': '状态', 'ms': 'Status'},
  'lblItem': {'en': 'Item', 'zh': '物品', 'ms': 'Barang'},
  'hintItemExample': {'en': 'e.g. Milk', 'zh': '例如：牛奶', 'ms': 'cth. Susu'},
  'lblQty': {'en': 'Qty', 'zh': '数量', 'ms': 'Kuantiti'},
  'lblCategory': {'en': 'Category', 'zh': '分类', 'ms': 'Kategori'},
  'lblStatus': {'en': 'Status', 'zh': '状态', 'ms': 'Status'},
  'statusOkFull': {'en': '✅ In stock', 'zh': '✅ 有库存', 'ms': '✅ Ada Stok'},
  'statusLowFull': {'en': '⚠️ Running low', 'zh': '⚠️ 库存低', 'ms': '⚠️ Stok Rendah'},
  'statusOutFull': {'en': '❌ Out', 'zh': '❌ 缺货', 'ms': '❌ Habis Stok'},
  'lblPrice': {'en': 'Price', 'zh': '价格', 'ms': 'Harga'},
  'lblLocationOptional': {'en': 'Location (optional)', 'zh': '位置（可选）', 'ms': 'Lokasi (pilihan)'},
  'addNewLocation': {'en': '+ Add new location…', 'zh': '+ 添加新位置…', 'ms': '+ Tambah lokasi baharu…'},
  'lblExpiryOptional': {'en': 'Expiry (optional)', 'zh': '有效期（可选）', 'ms': 'Tarikh luput (pilihan)'},
  'expPrefix': {'en': 'Exp', 'zh': '有效期', 'ms': 'Luput'},
  'btnAddItem': {'en': 'Add item', 'zh': '添加物品', 'ms': 'Tambah barang'},
  'quickAddCaption': {'en': 'Quick add (tap to add as "Out")', 'zh': '快速添加（点击以“缺货”状态添加）', 'ms': 'Tambah pantas (ketik untuk tambah sebagai "Habis")'},
  'chipAll': {'en': 'All', 'zh': '全部', 'ms': 'Semua'},
  'chipUnassigned': {'en': 'Unassigned', 'zh': '未分配', 'ms': 'Tiada Lokasi'},
  'btnAddFirstLocation': {'en': 'Add your first location', 'zh': '添加第一个位置', 'ms': 'Tambah lokasi pertama anda'},
  'emptyLocation': {'en': 'No items in this location yet.', 'zh': '该位置暂无物品。', 'ms': 'Tiada barang di lokasi ini lagi.'},
  'emptyNoItems': {'en': 'No items yet — add your first above, or tap a quick-add chip.', 'zh': '暂无物品 —— 在上方添加第一个，或点击快速添加标签。', 'ms': 'Belum ada barang — tambah yang pertama di atas, atau ketik cip tambah pantas.'},
  'emptyNoMatch': {'en': 'No items match your search.', 'zh': '没有符合搜索条件的物品。', 'ms': 'Tiada barang sepadan dengan carian anda.'},
  'itemsToBuy': {'en': 'item(s) to buy', 'zh': '项待购买', 'ms': 'barang untuk dibeli'},
  'needPrefix': {'en': 'need', 'zh': '需要', 'ms': 'perlu'},
  'emptyShopping': {'en': "Nothing to buy — you're fully stocked! 🎉", 'zh': '无需购买 —— 库存充足！🎉', 'ms': 'Tiada apa untuk dibeli — stok anda mencukupi! 🎉'},
  'noBarcodeMatch': {'en': 'No item in your pantry matches that barcode yet.', 'zh': '您的库存中没有与该条码匹配的物品。', 'ms': 'Tiada barang dalam stok anda sepadan dengan kod bar itu.'},
  'currentlyInStock': {'en': 'Currently', 'zh': '当前库存：', 'ms': 'Kini'},
  'inStockSuffix': {'en': 'in stock', 'zh': '', 'ms': 'dalam stok'},
  'btnUsed1': {'en': 'Used 1', 'zh': '使用 1 个', 'ms': 'Guna 1'},
  'btnUsedAll': {'en': 'Used it all / mark out', 'zh': '已用完 / 标记缺货', 'ms': 'Habis digunakan / tanda habis'},
  'emptyConsume': {'en': 'Nothing in stock to use up', 'zh': '没有库存可以使用', 'ms': 'Tiada stok untuk digunakan'},
  'titlePurchaseHistory': {'en': 'Purchase history', 'zh': '购买记录', 'ms': 'Sejarah pembelian'},
  'emptyPurchaseHistory': {'en': 'No purchases recorded yet', 'zh': '暂无购买记录', 'ms': 'Tiada pembelian direkodkan lagi'},
  'titleEditPurchase': {'en': 'Edit purchase', 'zh': '编辑购买记录', 'ms': 'Edit pembelian'},
  'lblItemName': {'en': 'Item name', 'zh': '物品名称', 'ms': 'Nama barang'},
  'purchasedPrefix': {'en': 'Purchased', 'zh': '购买日期', 'ms': 'Dibeli'},
  'btnSaveChanges': {'en': 'Save changes', 'zh': '保存更改', 'ms': 'Simpan perubahan'},
  'menuCopyBackup': {'en': 'Copy backup to clipboard', 'zh': '复制备份到剪贴板', 'ms': 'Salin sandaran ke papan keratan'},
  'menuImportBackup': {'en': 'Import backup (paste)', 'zh': '导入备份（粘贴）', 'ms': 'Import sandaran (tampal)'},
  'menuRestock': {'en': 'Restock bought items', 'zh': '重新补货已购物品', 'ms': 'Isi semula barang dibeli'},
  'menuManageLocations': {'en': 'Manage locations', 'zh': '管理位置', 'ms': 'Urus lokasi'},
  'menuCurrency': {'en': 'Currency', 'zh': '货币', 'ms': 'Mata wang'},
  'menuLanguage': {'en': 'Language', 'zh': '语言', 'ms': 'Bahasa'},
  'menuDeleteAll': {'en': 'Delete all items', 'zh': '删除所有物品', 'ms': 'Padam semua barang'},
  'dlgCameraTitle': {'en': 'Camera permission needed', 'zh': '需要相机权限', 'ms': 'Kebenaran kamera diperlukan'},
  'dlgCameraBodyDenied': {'en': 'Camera access is turned off for Pantry. Open Settings to enable it, then tap scan again.', 'zh': 'Pantry 的相机权限已关闭。请前往设置开启，然后再次点击扫描。', 'ms': 'Akses kamera untuk Pantry dimatikan. Buka Tetapan untuk mengaktifkannya, kemudian ketik imbas semula.'},
  'dlgCameraBodyDefault': {'en': 'Pantry needs the camera to scan barcodes. Please allow it and try again.', 'zh': 'Pantry 需要使用相机来扫描条码。请允许权限后重试。', 'ms': 'Pantry memerlukan kamera untuk mengimbas kod bar. Sila benarkan dan cuba lagi.'},
  'btnNotNow': {'en': 'Not now', 'zh': '暂不', 'ms': 'Bukan sekarang'},
  'btnOpenSettings': {'en': 'Open Settings', 'zh': '打开设置', 'ms': 'Buka Tetapan'},
  'dlgNewLocation': {'en': 'New location', 'zh': '新位置', 'ms': 'Lokasi baharu'},
  'hintLocationExample': {'en': 'e.g. Garage Freezer', 'zh': '例如：车库冰柜', 'ms': 'cth. Peti Sejuk Beku Garaj'},
  'btnCancel': {'en': 'Cancel', 'zh': '取消', 'ms': 'Batal'},
  'btnAdd': {'en': 'Add', 'zh': '添加', 'ms': 'Tambah'},
  'btnAddLocation': {'en': 'Add location', 'zh': '添加位置', 'ms': 'Tambah lokasi'},
  'dlgDeleteAllTitle': {'en': 'Delete all items?', 'zh': '删除所有物品？', 'ms': 'Padam semua barang?'},
  'dlgDeleteAllBody': {'en': 'This cannot be undone.', 'zh': '此操作无法撤销。', 'ms': 'Tindakan ini tidak boleh dibatalkan.'},
  'btnDelete': {'en': 'Delete', 'zh': '删除', 'ms': 'Padam'},
  'dlgImportTitle': {'en': 'Import backup', 'zh': '导入备份', 'ms': 'Import sandaran'},
  'hintPasteJson': {'en': 'Paste backup JSON here', 'zh': '在此粘贴备份 JSON', 'ms': 'Tampal JSON sandaran di sini'},
  'btnImport': {'en': 'Import', 'zh': '导入', 'ms': 'Import'},
  'titleScan': {'en': 'Scan barcode', 'zh': '扫描条码', 'ms': 'Imbas kod bar'},
  'btnTypeManually': {'en': 'Type it manually', 'zh': '手动输入', 'ms': 'Taip secara manual'},
  'hintPointCamera': {'en': 'Point the camera at a barcode', 'zh': '将相机对准条码', 'ms': 'Arahkan kamera ke kod bar'},
  'titleCameraUnavailable': {'en': 'Camera unavailable', 'zh': '相机不可用', 'ms': 'Kamera tidak tersedia'},
  'bodyCameraUnavailable': {'en': 'Allow Camera permission for Pantry in Settings, or just type the item name instead.', 'zh': '请在设置中允许 Pantry 的相机权限，或直接手动输入物品名称。', 'ms': 'Benarkan kebenaran Kamera untuk Pantry dalam Tetapan, atau taip sahaja nama barang.'},
  'snackRecognized': {'en': 'Recognized', 'zh': '已识别', 'ms': 'Dikenal pasti'},
  'snackLookingUp': {'en': 'New barcode — looking it up…', 'zh': '新条码 —— 正在查询…', 'ms': 'Kod bar baharu — sedang mencari…'},
  'snackNotFoundOnline': {'en': "Not found online — type the item name, we'll remember this barcode next time.", 'zh': '未在线上找到 —— 请输入物品名称，我们会记住这个条码以便下次使用。', 'ms': 'Tidak dijumpai dalam talian — taip nama barang, kami akan ingat kod bar ini pada masa akan datang.'},
  'snackBackupCopied': {'en': 'Backup copied to clipboard — paste it somewhere safe.', 'zh': '备份已复制到剪贴板 —— 请粘贴到安全的地方保存。', 'ms': 'Sandaran disalin ke papan keratan — tampal di tempat yang selamat.'},
  'snackImported': {'en': 'Imported', 'zh': '已导入', 'ms': 'Diimport'},
  'snackInvalidBackup': {'en': "That doesn't look like valid backup JSON", 'zh': '这似乎不是有效的备份 JSON', 'ms': 'Itu bukan JSON sandaran yang sah'},
  'menuSheets': {'en': 'Google Sheets sync', 'zh': '同步到 Google 表格', 'ms': 'Segerak Google Sheets'},
  'titleSheets': {'en': 'Google Sheets sync', 'zh': 'Google 表格同步', 'ms': 'Penyegerakan Google Sheets'},
  'sheetsNotSignedIn': {'en': 'Not connected', 'zh': '尚未连接', 'ms': 'Belum disambungkan'},
  'sheetsSignedInAs': {'en': 'Signed in as', 'zh': '已登录：', 'ms': 'Log masuk sebagai'},
  'btnSignIn': {'en': 'Connect Google account', 'zh': '连接 Google 账号', 'ms': 'Sambung akaun Google'},
  'btnSignOut': {'en': 'Disconnect', 'zh': '断开连接', 'ms': 'Putuskan sambungan'},
  'sheetsNoSpreadsheet': {'en': 'No spreadsheet linked yet.', 'zh': '尚未关联表格。', 'ms': 'Belum ada hamparan dipautkan.'},
  'btnCreateSheet': {'en': 'Create new spreadsheet', 'zh': '创建新表格', 'ms': 'Cipta hamparan baharu'},
  'btnUseExisting': {'en': 'Use existing spreadsheet', 'zh': '使用现有表格', 'ms': 'Guna hamparan sedia ada'},
  'hintSheetUrl': {'en': 'Paste spreadsheet URL or ID', 'zh': '粘贴表格网址或 ID', 'ms': 'Tampal URL atau ID hamparan'},
  'sheetsLinked': {'en': 'Linked spreadsheet', 'zh': '已关联表格', 'ms': 'Hamparan dipautkan'},
  'btnCopyLink': {'en': 'Copy link', 'zh': '复制链接', 'ms': 'Salin pautan'},
  'linkCopied': {'en': 'Link copied to clipboard', 'zh': '链接已复制到剪贴板', 'ms': 'Pautan disalin ke papan keratan'},
  'btnPushNow': {'en': 'Push to Sheets', 'zh': '推送到表格', 'ms': 'Tolak ke Sheets'},
  'btnPullNow': {'en': 'Pull from Sheets', 'zh': '从表格拉取', 'ms': 'Tarik dari Sheets'},
  'btnSyncNow': {'en': 'Sync now', 'zh': '立即同步', 'ms': 'Segerak sekarang'},
  'sheetsLastSync': {'en': 'Last synced', 'zh': '上次同步', 'ms': 'Segerak terakhir'},
  'sheetsNever': {'en': 'never', 'zh': '从未', 'ms': 'tiada'},
  'dlgPullTitle': {'en': 'Pull from Sheets?', 'zh': '从表格拉取？', 'ms': 'Tarik dari Sheets?'},
  'dlgPullBody': {'en': 'This replaces your current inventory with what\'s in the spreadsheet. Any local changes not yet pushed will be lost.', 'zh': '这将用表格中的数据替换当前库存。尚未推送的本地更改将丢失。', 'ms': 'Ini akan menggantikan inventori semasa anda dengan kandungan hamparan. Sebarang perubahan tempatan yang belum ditolak akan hilang.'},
  'sheetsPushOk': {'en': 'Pushed to Google Sheets', 'zh': '已推送到 Google 表格', 'ms': 'Berjaya ditolak ke Google Sheets'},
  'sheetsPullOk': {'en': 'Pulled from Google Sheets', 'zh': '已从 Google 表格拉取', 'ms': 'Berjaya ditarik dari Google Sheets'},
  'sheetsError': {'en': 'Sync error', 'zh': '同步出错', 'ms': 'Ralat penyegerakan'},
  'sheetsAutoSyncNote': {'en': 'While connected, changes you make here sync to Sheets automatically (merged with anyone else\'s changes, nothing is overwritten). The app also syncs each time it opens.', 'zh': '连接后，您在此处所做的更改会自动与表格同步（与他人的更改合并，不会覆盖任何内容）。每次打开应用时也会自动同步。', 'ms': 'Semasa disambungkan, perubahan yang anda buat di sini disegerakkan secara automatik ke Sheets (digabungkan dengan perubahan orang lain, tiada apa yang ditulis ganti). Aplikasi juga menyegerak setiap kali dibuka.'},
  'deviceFlowTitle': {'en': 'Connect your Google account', 'zh': '连接您的 Google 账号', 'ms': 'Sambungkan akaun Google anda'},
  'deviceFlowInstructions': {'en': 'On any device with a browser, open the link below and enter this code:', 'zh': '在任意设备的浏览器中打开以下链接，并输入此代码：', 'ms': 'Pada mana-mana peranti dengan pelayar, buka pautan di bawah dan masukkan kod ini:'},
  'deviceFlowWaiting': {'en': 'Waiting for you to authorize…', 'zh': '正在等待您授权…', 'ms': 'Menunggu kebenaran anda…'},
  'btnCancelConnect': {'en': 'Cancel', 'zh': '取消', 'ms': 'Batal'},
  'btnCopyCode': {'en': 'Copy code', 'zh': '复制代码', 'ms': 'Salin kod'},
  'codeCopied': {'en': 'Code copied to clipboard', 'zh': '代码已复制到剪贴板', 'ms': 'Kod disalin ke papan keratan'},
  'sheetsConnectedOk': {'en': 'Connected to Google', 'zh': '已连接到 Google', 'ms': 'Berjaya disambungkan ke Google'},
  'lblUnit': {'en': 'Unit', 'zh': '单位', 'ms': 'Unit'},
  'btnTakePhoto': {'en': 'Take photo', 'zh': '拍照', 'ms': 'Ambil gambar'},
  'btnAddPhoto': {'en': 'Add photo', 'zh': '添加照片', 'ms': 'Tambah gambar'},
  'btnViewPhoto': {'en': 'View photo', 'zh': '查看照片', 'ms': 'Lihat gambar'},
  'btnRetakePhoto': {'en': 'Retake photo', 'zh': '重新拍照', 'ms': 'Ambil semula gambar'},
  'btnRemovePhoto': {'en': 'Remove photo', 'zh': '移除照片', 'ms': 'Alih keluar gambar'},
  'titleEditQty': {'en': 'Edit quantity', 'zh': '编辑数量', 'ms': 'Edit kuantiti'},
  'btnSave': {'en': 'Save', 'zh': '保存', 'ms': 'Simpan'},
  'photoNote': {'en': 'Photos stay on this device only — they do not sync to Google Sheets.', 'zh': '照片仅保存在本设备 —— 不会同步到 Google 表格。', 'ms': 'Gambar kekal di peranti ini sahaja — tidak disegerakkan ke Google Sheets.'},
  'errorGeneric': {'en': 'Something went wrong', 'zh': '出现错误', 'ms': 'Sesuatu tidak kena'},
  'navHome': {'en': 'Home', 'zh': '首页', 'ms': 'Utama'},
  'navLocations': {'en': 'Locations', 'zh': '位置', 'ms': 'Lokasi'},
  'navShopping': {'en': 'Shopping', 'zh': '购物', 'ms': 'Beli-belah'},
  'navMore': {'en': 'More', 'zh': '更多', 'ms': 'Lagi'},
  'statNeedAttention': {'en': 'need attention', 'zh': '需要留意', 'ms': 'perlu perhatian'},
  'titleEditItem': {'en': 'Edit item', 'zh': '编辑物品', 'ms': 'Edit barang'},
  'btnDeleteItem': {'en': 'Delete item', 'zh': '删除物品', 'ms': 'Padam barang'},
  'titleExpiringSoon': {'en': 'Expiring soon', 'zh': '即将过期', 'ms': 'Akan luput'},
  'dlgDeleteItemTitle': {'en': 'Delete this item?', 'zh': '删除此物品？', 'ms': 'Padam barang ini?'},
  'dlgDeleteItemBody': {'en': 'You can restore it later from "Recently deleted" if you change your mind.', 'zh': '如果改变主意，您之后可以从"最近删除"中恢复它。', 'ms': 'Anda boleh memulihkannya kemudian daripada "Baru dipadam" jika berubah fikiran.'},
  'menuRecentlyDeleted': {'en': 'Recently deleted', 'zh': '最近删除', 'ms': 'Baru dipadam'},
  'emptyRecentlyDeleted': {'en': 'Nothing in recently deleted', 'zh': '最近删除中没有物品', 'ms': 'Tiada apa dalam baru dipadam'},
  'btnRestore': {'en': 'Restore', 'zh': '恢复', 'ms': 'Pulihkan'},
  'btnDeleteForever': {'en': 'Delete forever', 'zh': '永久删除', 'ms': 'Padam selamanya'},
  'snackRestored': {'en': 'Restored', 'zh': '已恢复', 'ms': 'Dipulihkan'},
  'tipFlash': {'en': 'Flash', 'zh': '闪光灯', 'ms': 'Lampu kilat'},
};

class PantryItem {
  String id, name, cat, status; // status: ok | low | out
  int qty;
  double price;
  DateTime? exp;
  bool bought;
  String location;
  String? barcode;
  DateTime updatedAt;
  bool deleted;
  String unit;
  String? photoPath;

  PantryItem({
    required this.id,
    required this.name,
    required this.cat,
    this.status = 'ok',
    this.qty = 1,
    this.price = 0,
    this.exp,
    this.bought = false,
    this.location = '',
    this.barcode,
    DateTime? updatedAt,
    this.deleted = false,
    this.unit = '',
    this.photoPath,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Key used to match the "same" item across devices when merging syncs.
  String get mergeKey => (barcode != null && barcode!.isNotEmpty)
      ? 'b:$barcode'
      : 'n:${name.trim().toLowerCase()}';

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'cat': cat, 'status': status, 'qty': qty,
        'price': price, 'exp': exp?.toIso8601String(), 'bought': bought,
        'location': location, 'barcode': barcode,
        'updatedAt': updatedAt.toIso8601String(), 'deleted': deleted,
        'unit': unit, 'photoPath': photoPath,
      };

  factory PantryItem.fromJson(Map<String, dynamic> j) => PantryItem(
        id: j['id']?.toString() ?? UniqueKey().toString(),
        name: (j['name'] ?? '').toString(),
        cat: (j['cat'] ?? 'Other').toString(),
        status: (j['status'] ?? 'ok').toString(),
        qty: (j['qty'] is num) ? (j['qty'] as num).toInt() : 1,
        price: (j['price'] is num) ? (j['price'] as num).toDouble() : 0,
        exp: (j['exp'] != null) ? DateTime.tryParse(j['exp'].toString()) : null,
        bought: j['bought'] == true,
        location: (j['location'] ?? '').toString(),
        barcode: j['barcode']?.toString(),
        updatedAt: (j['updatedAt'] != null) ? DateTime.tryParse(j['updatedAt'].toString()) : null,
        deleted: j['deleted'] == true,
        unit: (j['unit'] ?? '').toString(),
        photoPath: j['photoPath']?.toString(),
      );

  int? get daysLeft {
    if (exp == null) return null;
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final e0 = DateTime(exp!.year, exp!.month, exp!.day);
    return e0.difference(d0).inDays;
  }

  bool get expiringSoon {
    final n = daysLeft;
    return n != null && n <= kSoonDays;
  }
}

class PurchaseRecord {
  final String id, name, cat;
  final int qty;
  final double price;
  final DateTime date;
  final DateTime? exp;
  final String unit;

  PurchaseRecord({
    required this.id,
    required this.name,
    required this.cat,
    required this.qty,
    required this.price,
    required this.date,
    this.exp,
    this.unit = '',
  });

  PurchaseRecord copyWith({String? name, String? cat, int? qty, double? price, DateTime? date, DateTime? exp, bool clearExp = false, String? unit}) =>
      PurchaseRecord(
        id: id,
        name: name ?? this.name,
        cat: cat ?? this.cat,
        qty: qty ?? this.qty,
        price: price ?? this.price,
        date: date ?? this.date,
        exp: clearExp ? null : (exp ?? this.exp),
        unit: unit ?? this.unit,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'cat': cat, 'qty': qty,
        'price': price, 'date': date.toIso8601String(), 'exp': exp?.toIso8601String(),
        'unit': unit,
      };

  factory PurchaseRecord.fromJson(Map<String, dynamic> j) => PurchaseRecord(
        id: j['id']?.toString() ?? UniqueKey().toString(),
        name: (j['name'] ?? '').toString(),
        cat: (j['cat'] ?? 'Other').toString(),
        qty: (j['qty'] is num) ? (j['qty'] as num).toInt() : 1,
        price: (j['price'] is num) ? (j['price'] as num).toDouble() : 0,
        exp: (j['exp'] != null) ? DateTime.tryParse(j['exp'].toString()) : null,
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
        unit: (j['unit'] ?? '').toString(),
      );
}

// ---------------------------------------------------------------------------
// Google Sheets sync (manual push/pull over the Sheets v4 REST API).
String? extractSpreadsheetId(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(s);
  if (m != null) return m.group(1);
  if (RegExp(r'^[a-zA-Z0-9-_]+$').hasMatch(s)) return s;
  return null;
}

// Device-code OAuth flow (RFC 8628) — no Google Play Services required, works
// on any device with a browser (this device or another). Client ID/secret for
// a "TVs and Limited Input devices" OAuth client are not confidential for this
// flow (Google's own docs: not treated as a secret in this grant type).
class DeviceFlowAuth {
  static const String clientId = '921740079653-93r0tajqa45e1qd365fnl6s6pj2m6kep.apps.googleusercontent.com';
  static const String clientSecret = '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';
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  String? accessToken;
  String? refreshToken;
  DateTime? expiry;
  String? email;

  bool get isSignedIn => refreshToken != null;

  Future<void> loadPersisted() async {
    final p = await SharedPreferences.getInstance();
    accessToken = p.getString('pantry.gauth.access');
    refreshToken = p.getString('pantry.gauth.refresh');
    final exp = p.getString('pantry.gauth.expiry');
    expiry = exp != null ? DateTime.tryParse(exp) : null;
    email = p.getString('pantry.gauth.email');
  }

  Future<void> _persistTokens() async {
    final p = await SharedPreferences.getInstance();
    if (accessToken != null) await p.setString('pantry.gauth.access', accessToken!);
    if (refreshToken != null) await p.setString('pantry.gauth.refresh', refreshToken!);
    if (expiry != null) await p.setString('pantry.gauth.expiry', expiry!.toIso8601String());
    if (email != null) await p.setString('pantry.gauth.email', email!);
  }

  Future<void> signOut() async {
    accessToken = null;
    refreshToken = null;
    expiry = null;
    email = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('pantry.gauth.access');
    await p.remove('pantry.gauth.refresh');
    await p.remove('pantry.gauth.expiry');
    await p.remove('pantry.gauth.email');
  }

  Future<Map<String, dynamic>> requestDeviceCode() async {
    final res = await http.post(
      Uri.parse('https://oauth2.googleapis.com/device/code'),
      body: {'client_id': clientId, 'scope': scopes.join(' ')},
    );
    if (res.statusCode != 200) throw Exception('${res.statusCode}: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Returns true once authorized, false while still pending; throws on hard failure.
  Future<bool> tryExchangeDeviceCode(String deviceCode) async {
    final res = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'device_code': deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      },
    );
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      accessToken = j['access_token'] as String;
      refreshToken = (j['refresh_token'] as String?) ?? refreshToken;
      expiry = DateTime.now().add(Duration(seconds: (j['expires_in'] as num).toInt()));
      await _fetchEmail();
      await _persistTokens();
      return true;
    }
    final err = j['error'] as String?;
    if (err == 'authorization_pending' || err == 'slow_down') return false;
    throw Exception(err ?? 'device_flow_failed');
  }

  Future<void> _fetchEmail() async {
    try {
      final res = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        email = (jsonDecode(res.body) as Map)['email'] as String?;
      }
    } catch (_) {}
  }

  Future<void> _refreshAccessToken() async {
    if (refreshToken == null) throw Exception('Not signed in');
    final res = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': refreshToken!,
        'grant_type': 'refresh_token',
      },
    );
    if (res.statusCode != 200) throw Exception('${res.statusCode}: ${res.body}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    accessToken = j['access_token'] as String;
    expiry = DateTime.now().add(Duration(seconds: (j['expires_in'] as num).toInt()));
    await _persistTokens();
  }

  Future<Map<String, String>> authHeaders() async {
    if (refreshToken == null) throw Exception('Not signed in');
    if (accessToken == null || expiry == null || DateTime.now().isAfter(expiry!.subtract(const Duration(minutes: 1)))) {
      await _refreshAccessToken();
    }
    return {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'};
  }
}

class SheetsService {
  final DeviceFlowAuth auth = DeviceFlowAuth();

  Future<void> loadPersisted() => auth.loadPersisted();
  bool get isSignedIn => auth.isSignedIn;
  String? get email => auth.email;
  Future<void> signOut() => auth.signOut();

  Future<Map<String, String>> _headers() => auth.authHeaders();

  Future<String> createSpreadsheet(String title) async {
    final res = await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
      headers: await _headers(),
      body: jsonEncode({
        'properties': {'title': title},
        'sheets': [
          {'properties': {'title': 'Inventory'}},
        ],
      }),
    );
    if (res.statusCode != 200) throw Exception('${res.statusCode}: ${res.body}');
    return (jsonDecode(res.body) as Map)['spreadsheetId'] as String;
  }

  Future<void> pushInventory(String spreadsheetId, List<PantryItem> items) async {
    final headers = await _headers();
    final rows = <List<dynamic>>[
      ['Name', 'Category', 'Qty', 'Status', 'Price', 'Expiry', 'Location', 'Barcode', 'UpdatedAt', 'Deleted', 'Unit'],
      ...items.map((it) => [
            it.name, it.cat, it.qty, it.status, it.price,
            it.exp?.toIso8601String().substring(0, 10) ?? '',
            it.location, it.barcode ?? '',
            it.updatedAt.toIso8601String(),
            it.deleted ? 'Y' : '',
            it.unit,
          ]),
    ];
    await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Inventory!A1:K10000:clear'),
      headers: headers,
    );
    final res = await http.put(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Inventory!A1?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': rows}),
    );
    if (res.statusCode != 200) throw Exception('${res.statusCode}: ${res.body}');
  }

  Future<List<PantryItem>> pullInventory(String spreadsheetId, String Function() genId) async {
    final headers = await _headers();
    final res = await http.get(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Inventory!A2:K10000'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('${res.statusCode}: ${res.body}');
    final values = ((jsonDecode(res.body) as Map)['values'] as List?) ?? [];
    return values
        .where((r) => r is List && r.isNotEmpty && r[0].toString().trim().isNotEmpty)
        .map<PantryItem>((r) {
      final row = List<String>.generate(11, (i) => i < (r as List).length ? r[i].toString() : '');
      return PantryItem(
        id: genId(),
        name: row[0],
        cat: kCats.contains(row[1]) ? row[1] : 'Other',
        qty: int.tryParse(row[2]) ?? 1,
        status: ['ok', 'low', 'out'].contains(row[3]) ? row[3] : 'ok',
        price: double.tryParse(row[4]) ?? 0,
        exp: row[5].isEmpty ? null : DateTime.tryParse(row[5]),
        location: row[6],
        barcode: row[7].isEmpty ? null : row[7],
        updatedAt: row[8].isEmpty ? null : DateTime.tryParse(row[8]),
        deleted: row[9].trim().toUpperCase() == 'Y',
        unit: row[10],
      );
    }).toList();
  }

  /// Merges local + remote by mergeKey, newest `updatedAt` wins per item; items
  /// only present on one side are kept (a union, not an overwrite). Pushes the
  /// merged result back so the sheet reflects it, and returns the merged list
  /// for the caller to store locally.
  static List<PantryItem> mergeItems(List<PantryItem> local, List<PantryItem> remote) {
    final byKey = <String, PantryItem>{};
    for (final it in local) {
      byKey[it.mergeKey] = it;
    }
    for (final r in remote) {
      final existing = byKey[r.mergeKey];
      if (existing == null || r.updatedAt.isAfter(existing.updatedAt)) {
        byKey[r.mergeKey] = r;
      }
    }
    return byKey.values.toList();
  }

  Future<List<PantryItem>> syncMerge(String spreadsheetId, List<PantryItem> local, String Function() genId) async {
    final remote = await pullInventory(spreadsheetId, genId);
    final merged = mergeItems(local, remote);
    await pushInventory(spreadsheetId, merged);
    return merged;
  }
}

// ---------------------------------------------------------------------------
class PantryApp extends StatefulWidget {
  const PantryApp({super.key});
  @override
  State<PantryApp> createState() => _PantryAppState();
}

class _PantryAppState extends State<PantryApp> {
  ThemeMode _mode = ThemeMode.dark;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _mode = p.getString('pantry.theme') == 'light' ? ThemeMode.light : ThemeMode.dark;
      _loaded = true;
    });
  }

  Future<void> _toggleTheme() async {
    setState(() => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
    final p = await SharedPreferences.getInstance();
    p.setString('pantry.theme', _mode == ThemeMode.light ? 'light' : 'dark');
  }

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: kBrand, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0F172A) : kCream,
      cardColor: b == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBrandDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: b == Brightness.dark ? const Color(0xFF172033) : const Color(0xFFF1F4F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pantry',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      // Clamp the system font-size setting so an extreme accessibility text
      // scale on some phones can't blow up the compact card layouts below.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.2)),
          child: child!,
        );
      },
      home: _loaded
          ? HomePage(isDark: _mode == ThemeMode.dark, onToggleTheme: _toggleTheme)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

// ---------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  const HomePage({super.key, required this.isDark, required this.onToggleTheme});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<PantryItem> _items = [];
  List<String> _history = [];
  List<String> _locations = List.of(kDefaultLocations);
  List<PurchaseRecord> _purchases = [];
  Map<String, String> _barcodeMap = {};
  String _currency = 'MYR';
  final SheetsService _sheets = SheetsService();
  String? _spreadsheetId;
  DateTime? _lastSync;
  Timer? _syncDebounce;
  int _navIndex = 0;

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _addCat = kCats.first;
  String _addStatus = 'ok';
  DateTime? _addExp;
  String _addLoc = '';
  String? _addBarcode;
  String _addUnit = kUnits.first;
  String? _addPhotoPath;
  String _filterCat = '';
  String _filterLoc = '';
  String _sortBy = 'cat';

  String get _sym => kCurrencySymbols[_currency] ?? _currency;
  String _fmt(double v) => '$_sym${v.toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      _sheets.loadPersisted().then((_) {
        if (!mounted) return;
        setState(() {});
        if (_sheets.isSignedIn && _spreadsheetId != null) _runSync();
      });
    });
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('pantry.items');
    final h = p.getString('pantry.history');
    final loc = p.getString('pantry.locations');
    final pur = p.getString('pantry.purchases');
    final bc = p.getString('pantry.barcodeMap');
    final cur = p.getString('pantry.currency');
    final lang = p.getString('pantry.lang');
    final sheetId = p.getString('pantry.sheetId');
    final lastSync = p.getString('pantry.lastSync');
    setState(() {
      if (raw != null) {
        try {
          _items = (jsonDecode(raw) as List).map((e) => PantryItem.fromJson(e)).toList();
        } catch (_) {}
      }
      if (h != null) {
        try {
          _history = (jsonDecode(h) as List).map((e) => e.toString()).toList();
        } catch (_) {}
      }
      if (loc != null) {
        try {
          final list = (jsonDecode(loc) as List).map((e) => e.toString()).toList();
          if (list.isNotEmpty) _locations = list;
        } catch (_) {}
      }
      if (pur != null) {
        try {
          _purchases = (jsonDecode(pur) as List).map((e) => PurchaseRecord.fromJson(e)).toList();
        } catch (_) {}
      }
      if (bc != null) {
        try {
          _barcodeMap = Map<String, String>.from(jsonDecode(bc) as Map);
        } catch (_) {}
      }
      if (cur != null && cur.isNotEmpty) _currency = cur;
      if (lang != null && kLangs.contains(lang)) gLang = lang;
      if (sheetId != null && sheetId.isNotEmpty) _spreadsheetId = sheetId;
      if (lastSync != null) _lastSync = DateTime.tryParse(lastSync);
    });
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    p.setString('pantry.items', jsonEncode(_items.map((e) => e.toJson()).toList()));
    p.setString('pantry.history', jsonEncode(_history.take(40).toList()));
    p.setString('pantry.locations', jsonEncode(_locations));
    p.setString('pantry.purchases', jsonEncode(_purchases.take(500).map((e) => e.toJson()).toList()));
    p.setString('pantry.barcodeMap', jsonEncode(_barcodeMap));
    p.setString('pantry.currency', _currency);
    p.setString('pantry.lang', gLang);
    if (_spreadsheetId != null) p.setString('pantry.sheetId', _spreadsheetId!);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (!_sheets.isSignedIn || _spreadsheetId == null) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), _runSync);
  }

  Future<void> _applyMergedItems(List<PantryItem> merged) async {
    if (mounted) setState(() => _items = merged);
    final p = await SharedPreferences.getInstance();
    await p.setString('pantry.items', jsonEncode(_items.map((e) => e.toJson()).toList()));
    await _setLastSync();
  }

  Future<void> _runSync() async {
    if (!_sheets.isSignedIn || _spreadsheetId == null) return;
    try {
      final merged = await _sheets.syncMerge(_spreadsheetId!, _items, _uid);
      await _applyMergedItems(merged);
    } catch (_) {}
  }

  Future<void> _setLastSync() async {
    final now = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setString('pantry.lastSync', now.toIso8601String());
    if (mounted) setState(() => _lastSync = now);
  }

  Future<void> _pickLanguage() async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(tr('menuLanguage')),
        children: kLangs.map((l) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, l),
              child: Row(children: [
                Text(kLangNames[l]!),
                if (l == gLang) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 18, color: kBrand)),
              ]),
            )).toList(),
      ),
    );
    if (v != null) { setState(() => gLang = v); _persist(); }
  }

  Future<void> _pickCurrency() async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Currency'),
        children: kCurrencySymbols.keys.map((c) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Row(children: [
                SizedBox(width: 48, child: Text(kCurrencySymbols[c]!, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(c),
                if (c == _currency) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 18, color: kBrand)),
              ]),
            )).toList(),
      ),
    );
    if (v != null) { setState(() => _currency = v); _persist(); }
  }

  void _logPurchase(PantryItem it) {
    _purchases.insert(0, PurchaseRecord(
      id: _uid(), name: it.name, cat: it.cat, qty: it.qty, price: it.price, date: DateTime.now(), exp: it.exp, unit: it.unit,
    ));
  }

  void _editPurchase(PurchaseRecord oldRecord, PurchaseRecord newRecord) {
    final idx = _purchases.indexWhere((r) => r.id == oldRecord.id);
    if (idx == -1) return;
    setState(() => _purchases[idx] = newRecord);
    _persist();
  }

  String _uid() => '${DateTime.now().microsecondsSinceEpoch}';

  // ---- mutations ----
  void _add() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      final it = PantryItem(
        id: _uid(), name: name,
        qty: int.tryParse(_qtyCtrl.text) ?? 1,
        cat: _addCat, status: _addStatus, exp: _addExp,
        price: double.tryParse(_priceCtrl.text) ?? 0,
        location: _addLoc, barcode: _addBarcode,
        unit: _addUnit, photoPath: _addPhotoPath,
      );
      _items.insert(0, it);
      _logPurchase(it);
      if (it.barcode != null && it.barcode!.isNotEmpty) _barcodeMap[it.barcode!] = name;
      if (!_history.contains(name)) _history.insert(0, name);
      _nameCtrl.clear();
      _qtyCtrl.text = '1';
      _priceCtrl.clear();
      _addExp = null;
      _addStatus = 'ok';
      _addBarcode = null;
      _addPhotoPath = null;
    });
    _persist();
    FocusScope.of(context).unfocus();
  }

  void _quickAdd(String name) {
    setState(() {
      final it = PantryItem(
        id: _uid(), name: name, qty: 1,
        cat: kCatGuess[name] ?? _addCat, status: 'out', location: _addLoc,
      );
      _items.insert(0, it);
      _logPurchase(it);
      if (!_history.contains(name)) _history.insert(0, name);
    });
    _persist();
  }

  List<PantryItem> get _visibleItems => _items.where((i) => !i.deleted).toList();

  void _changeQty(PantryItem it, int d) {
    setState(() {
      it.qty = (it.qty + d).clamp(0, 9999);
      if (it.qty == 0 && it.status == 'ok') it.status = 'out';
      it.touch();
    });
    _persist();
  }

  void _setStatus(PantryItem it, String s) { setState(() { it.status = s; it.touch(); }); _persist(); }
  void _delete(PantryItem it) { setState(() { it.deleted = true; it.touch(); }); _persist(); }
  void _toggleBought(PantryItem it) { setState(() { it.bought = !it.bought; it.touch(); }); _persist(); }

  void _restockBought() {
    setState(() {
      for (final i in _visibleItems.where((e) => e.bought)) {
        i.bought = false; i.status = 'ok';
        if (i.qty == 0) i.qty = 1;
        i.touch();
      }
    });
    _persist();
  }

  // ---- photo ----
  Future<String?> _capturePhoto() async {
    try {
      final shot = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 80);
      if (shot == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/photos');
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      final destPath = '${photosDir.path}/${_uid()}.jpg';
      await File(shot.path).copy(destPath);
      return destPath;
    } catch (e) {
      if (mounted) _snack('${tr('errorGeneric')}: $e');
      return null;
    }
  }

  void _viewPhoto(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(child: Image.file(File(path))),
      ),
    );
  }

  Future<void> _editItemPhoto(PantryItem it) async {
    final hasPhoto = it.photoPath != null && File(it.photoPath!).existsSync();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (hasPhoto)
            ListTile(leading: const Icon(Icons.image_outlined), title: Text(tr('btnViewPhoto')),
                onTap: () => Navigator.pop(context, 'view')),
          ListTile(leading: const Icon(Icons.camera_alt_outlined),
              title: Text(hasPhoto ? tr('btnRetakePhoto') : tr('btnAddPhoto')),
              onTap: () => Navigator.pop(context, 'take')),
          if (hasPhoto)
            ListTile(leading: const Icon(Icons.delete_outline, color: kDanger), title: Text(tr('btnRemovePhoto')),
                onTap: () => Navigator.pop(context, 'remove')),
        ]),
      ),
    );
    if (action == 'view' && hasPhoto) {
      _viewPhoto(it.photoPath!);
    } else if (action == 'take') {
      final path = await _capturePhoto();
      if (path != null) {
        setState(() { it.photoPath = path; it.touch(); });
        _persist();
      }
    } else if (action == 'remove') {
      setState(() { it.photoPath = null; it.touch(); });
      _persist();
    }
  }

  Future<void> _editQtyDialog(PantryItem it) async {
    final ctrl = TextEditingController(text: '${it.qty}');
    String unit = kUnits.contains(it.unit) ? it.unit : kUnits.first;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => AlertDialog(
          title: Text(tr('titleEditQty')),
          content: Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(labelText: tr('lblQty')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: InputDecoration(labelText: tr('lblUnit')),
                items: kUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setSheet(() => unit = v ?? unit),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('btnCancel'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('btnSave'))),
          ],
        ),
      ),
    );
    if (saved != true) return;
    setState(() {
      it.qty = int.tryParse(ctrl.text) ?? it.qty;
      it.unit = unit;
      if (it.qty == 0 && it.status == 'ok') it.status = 'out';
      it.touch();
    });
    _persist();
  }

  // ---- barcode ----
  Future<void> _scan() async {
    // Ask for camera permission up front so the scanner never opens to a crash.
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted) {
      if (!mounted) return;
      final goSettings = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('dlgCameraTitle')),
          content: Text(status.isPermanentlyDenied
              ? tr('dlgCameraBodyDenied')
              : tr('dlgCameraBodyDefault')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('btnNotNow'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('btnOpenSettings'))),
          ],
        ),
      );
      if (goSettings == true) await openAppSettings();
      return;
    }
    if (!mounted) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (code == null || !mounted) return;
    _addBarcode = code;

    // We've seen this barcode before — fill instantly, no network needed.
    final known = _barcodeMap[code];
    if (known != null) {
      _nameCtrl.text = known;
      setState(() {});
      _snack('${tr('snackRecognized')}: $known');
      return;
    }

    _nameCtrl.clear();
    setState(() {});
    _snack(tr('snackLookingUp'));
    try {
      final r = await http.get(Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$code.json?fields=product_name,generic_name'));
      final j = jsonDecode(r.body);
      if (j['status'] == 1 && j['product'] != null) {
        final p = j['product'];
        final nm = ((p['product_name'] ?? p['generic_name'] ?? '') as String).trim();
        if (nm.isNotEmpty && mounted) { _nameCtrl.text = nm; setState(() {}); return; }
      }
    } catch (_) {}
    if (mounted) _snack(tr('snackNotFoundOnline'));
  }

  // ---- consume / deduct ----
  Future<void> _openConsume() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConsumePage(
        items: _visibleItems,
        onScan: _scanForConsume,
        onDeduct: (it, useAll) {
          setState(() {
            it.qty = useAll ? 0 : (it.qty - 1).clamp(0, 9999);
            if (it.qty == 0) it.status = 'out';
            it.touch();
          });
          _persist();
        },
      ),
    ));
  }

  Future<String?> _scanForConsume(BuildContext ctx) async {
    var status = await Permission.camera.status;
    if (!status.isGranted) status = await Permission.camera.request();
    if (!status.isGranted) return null;
    if (!ctx.mounted) return null;
    return Navigator.of(ctx).push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));
  }

  // ---- backup (clipboard-based, no native plugins) ----
  Future<void> _export() async {
    final data = jsonEncode({
      'items': _items.map((e) => e.toJson()).toList(),
      'history': _history,
      'exported': DateTime.now().toIso8601String(),
    });
    await Clipboard.setData(ClipboardData(text: data));
    if (mounted) {
      _snack('${tr('snackBackupCopied')} (${_visibleItems.length})');
    }
  }

  Future<void> _import() async {
    final ctrl = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trim().startsWith('{')) {
      ctrl.text = clip.text!;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('dlgImportTitle')),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: InputDecoration(hintText: tr('hintPasteJson')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('btnCancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('btnImport'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final j = jsonDecode(ctrl.text.trim());
      final list = (j is List ? j : j['items']) as List;
      setState(() {
        _items = list.map((e) => PantryItem.fromJson(e)).toList();
        if (j is Map && j['history'] is List) {
          _history = (j['history'] as List).map((e) => e.toString()).toList();
        }
      });
      _persist();
      if (mounted) _snack('${tr('snackImported')} (${_visibleItems.length})');
    } catch (_) {
      if (mounted) _snack(tr('snackInvalidBackup'));
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _dataMenu() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(tr('tipData'))),
        body: ListView(children: [
          ListTile(leading: const Icon(Icons.copy_all), title: Text(tr('menuCopyBackup')),
              onTap: _export),
          ListTile(leading: const Icon(Icons.content_paste), title: Text(tr('menuImportBackup')),
              onTap: _import),
          ListTile(leading: const Icon(Icons.refresh), title: Text(tr('menuRestock')),
              onTap: _restockBought),
          ListTile(leading: const Icon(Icons.place_outlined), title: Text(tr('menuManageLocations')),
              onTap: _manageLocations),
          ListTile(leading: const Icon(Icons.payments_outlined), title: Text(tr('menuCurrency')),
              subtitle: Text('$_currency ($_sym)'),
              onTap: _pickCurrency),
          ListTile(leading: const Icon(Icons.language), title: Text(tr('menuLanguage')),
              subtitle: Text(kLangNames[gLang]!),
              onTap: _pickLanguage),
          ListTile(leading: const Icon(Icons.receipt_long_outlined), title: Text(tr('titlePurchaseHistory')),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PurchaseHistoryPage(
                      purchases: _purchases,
                      currencySymbol: _sym,
                      onDelete: (r) { setState(() => _purchases.remove(r)); _persist(); },
                      onEdit: _editPurchase,
                    )));
              }),
          ListTile(leading: const Icon(Icons.cloud_sync_outlined), title: Text(tr('menuSheets')),
              subtitle: Text(_sheets.email ?? tr('sheetsNotSignedIn'),
                  overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SheetsSyncPage(
                      sheets: _sheets,
                      spreadsheetId: _spreadsheetId,
                      lastSync: _lastSync,
                      items: _items,
                      genId: _uid,
                      onLinked: (id) { setState(() => _spreadsheetId = id); _persist(); },
                      onMerged: _applyMergedItems,
                      onSignedOut: () { setState(() {}); },
                    )));
              }),
          ListTile(leading: const Icon(Icons.restore_from_trash_outlined), title: Text(tr('menuRecentlyDeleted')),
              onTap: _openRecentlyDeleted),
          ListTile(leading: const Icon(Icons.delete_outline, color: kDanger),
              title: Text(tr('menuDeleteAll')),
              onTap: _confirmClear),
        ]),
      ),
    ));
  }

  void _restoreItem(PantryItem it) {
    setState(() { it.deleted = false; it.touch(); });
    _persist();
    _snack(tr('snackRestored'));
  }

  void _deleteForever(PantryItem it) {
    setState(() => _items.remove(it));
    _persist();
  }

  void _openRecentlyDeleted() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StatefulBuilder(
        builder: (context, setPage) {
          final deleted = _items.where((i) => i.deleted).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return Scaffold(
            appBar: AppBar(title: Text(tr('menuRecentlyDeleted'))),
            body: deleted.isEmpty
                ? Center(child: Text(tr('emptyRecentlyDeleted'), style: TextStyle(color: Theme.of(context).hintColor)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: deleted.length,
                    itemBuilder: (_, i) {
                      final it = deleted[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(catLabel(it.cat)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: tr('btnDeleteForever'),
                              icon: const Icon(Icons.delete_forever_outlined, color: kDanger),
                              onPressed: () { _deleteForever(it); setPage(() {}); },
                            ),
                            FilledButton.icon(
                              onPressed: () { _restoreItem(it); setPage(() {}); },
                              icon: const Icon(Icons.restore, size: 18),
                              label: Text(tr('btnRestore')),
                              style: FilledButton.styleFrom(backgroundColor: kBrand, foregroundColor: Colors.white),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    ));
  }

  Future<String?> _addLocationDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('dlgNewLocation')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: tr('hintLocationExample')),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('btnCancel'))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text(tr('btnAdd'))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return null;
    if (!_locations.contains(name)) {
      setState(() => _locations.add(name));
      _persist();
    }
    return name;
  }

  void _manageLocations() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('menuManageLocations'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              ..._locations.map((l) => ListTile(
                    dense: true,
                    title: Text(l),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        setState(() => _locations.remove(l));
                        setSheet(() {});
                        _persist();
                      },
                    ),
                  )),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final added = await _addLocationDialog();
                  if (added != null) setSheet(() {});
                },
                icon: const Icon(Icons.add),
                label: Text(tr('btnAddLocation')),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('dlgDeleteAllTitle')),
        content: Text(tr('dlgDeleteAllBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('btnCancel'))),
          TextButton(
            onPressed: () {
              setState(() {
                for (final it in _items) { it.deleted = true; it.touch(); }
              });
              _persist();
              Navigator.pop(context);
            },
            child: Text(tr('btnDelete'), style: const TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
  }

  // ---- derived ----
  Color _statusColor(String s) => s == 'out' ? kDanger : (s == 'low' ? kWarn : kGreen);
  String _statusText(String s) => s == 'out' ? tr('statOut') : (s == 'low' ? tr('statLow') : tr('statusInStock'));

  Widget _statusBadge(PantryItem it) {
    final col = _statusColor(it.status);
    return PopupMenuButton<String>(
      onSelected: (v) => _setStatus(it, v),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'ok', child: _statusMenuRow('ok')),
        PopupMenuItem(value: 'low', child: _statusMenuRow('low')),
        PopupMenuItem(value: 'out', child: _statusMenuRow('out')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: col.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Icon(Icons.expand_more, size: 14, color: col),
        ]),
      ),
    );
  }

  Widget _statusMenuRow(String s) => Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor(s), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(_statusText(s)),
      ]);

  List<PantryItem> get _shoppingList =>
      _visibleItems.where((i) => i.status != 'ok' || i.expiringSoon).toList()
        ..sort((a, b) {
          final c = (a.bought ? 1 : 0) - (b.bought ? 1 : 0);
          return c != 0 ? c : a.cat.compareTo(b.cat);
        });

  List<PantryItem> get _expiringSoonList =>
      _visibleItems.where((i) => i.expiringSoon).toList()
        ..sort((a, b) => (a.daysLeft ?? 1 << 30).compareTo(b.daysLeft ?? 1 << 30));

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    final needAttention = _shoppingList.length;
    final pages = [_inventoryTab(), _locationTab(), _shoppingTab()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u{1F9FA} Pantry', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: tr('tipConsume'),
            onPressed: _openConsume,
            icon: const Icon(Icons.remove_shopping_cart_outlined),
          ),
          IconButton(
            tooltip: tr('tipTheme'),
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kBrandDeep, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${visible.length}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(tr('statItems'), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .85))),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$needAttention',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                            color: needAttention > 0 ? kDanger : null)),
                    const SizedBox(height: 2),
                    Text(tr('statNeedAttention'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(child: pages[_navIndex]),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _bottomBar() {
    Widget navItem(IconData icon, String label, int idx) {
      final selected = _navIndex == idx;
      final color = selected ? kBrandDeep : Theme.of(context).hintColor;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _navIndex = idx),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ]),
        ),
      );
    }

    return Material(
      color: Theme.of(context).cardColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            navItem(Icons.home_outlined, tr('navHome'), 0),
            navItem(Icons.place_outlined, tr('navLocations'), 1),
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: _openAddSheet,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: kBrand,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: kBrand.withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
            navItem(Icons.shopping_cart_outlined, tr('navShopping'), 2),
            Expanded(
              child: InkWell(
                onTap: _dataMenu,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.more_horiz, size: 22, color: Theme.of(context).hintColor),
                  const SizedBox(height: 2),
                  Text(tr('navMore'), style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ---- Inventory tab ----
  Widget _expiringSoonBanner() {
    final list = _expiringSoonList;
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.access_time_filled, size: 15, color: kPurple),
          const SizedBox(width: 6),
          Text('${tr('titleExpiringSoon')} (${list.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPurple)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final it = list[i];
              return InkWell(
                onTap: () => _openEditSheet(it),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 132,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPurple.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kPurple.withValues(alpha: .3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    _expChip(it),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _inventoryTab() {
    final q = _searchCtrl.text.trim().toLowerCase();
    var shown = _visibleItems.where((i) =>
        (q.isEmpty || i.name.toLowerCase().contains(q)) &&
        (_filterCat.isEmpty || i.cat == _filterCat)).toList();

    final children = <Widget>[_expiringSoonBanner(), _toolbar(), _catChips(), const SizedBox(height: 8)];

    if (shown.isEmpty) {
      children.add(_empty(_visibleItems.isEmpty
          ? tr('emptyNoItems')
          : tr('emptyNoMatch')));
    } else if (_sortBy == 'cat') {
      final groups = <String, List<PantryItem>>{};
      for (final i in shown) { groups.putIfAbsent(i.cat, () => []).add(i); }
      for (final cat in groups.keys.toList()..sort()) {
        children.add(_catHeader(cat, groups[cat]!.length));
        children.addAll(groups[cat]!.map(_itemTile));
      }
    } else {
      int cmp(PantryItem a, PantryItem b) {
        switch (_sortBy) {
          case 'name': return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case 'status':
            int r(String s) => s == 'out' ? 0 : (s == 'low' ? 1 : 2);
            return r(a.status).compareTo(r(b.status));
          case 'exp':
            return (a.daysLeft ?? 1 << 30).compareTo(b.daysLeft ?? 1 << 30);
        }
        return 0;
      }
      shown.sort(cmp);
      children.addAll(shown.map(_itemTile));
    }

    return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: children);
  }

  Future<void> _openEditSheet(PantryItem it) async {
    final nameCtrl = TextEditingController(text: it.name);
    final qtyCtrl = TextEditingController(text: '${it.qty}');
    final priceCtrl = TextEditingController(text: it.price == 0 ? '' : it.price.toString());
    String cat = it.cat;
    String unit = kUnits.contains(it.unit) ? it.unit : kUnits.first;
    String status = it.status;
    String loc = it.location;
    DateTime? exp = it.exp;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setSheet) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tr('titleEditItem'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, autofocus: true, decoration: InputDecoration(labelText: tr('lblItem'))),
                const SizedBox(height: 10),
                Row(children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('lblQty')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: InputDecoration(labelText: tr('lblUnit')),
                      items: kUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setSheet(() => unit = v ?? unit),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: cat,
                      decoration: InputDecoration(labelText: tr('lblCategory')),
                      items: kCats.map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(catIcon(c), size: 16, color: catColor(c)),
                            const SizedBox(width: 8),
                            Text(catLabel(c)),
                          ]))).toList(),
                      onChanged: (v) => setSheet(() => cat = v ?? cat),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: InputDecoration(labelText: tr('lblStatus')),
                      items: [
                        DropdownMenuItem(value: 'ok', child: Text(tr('statusOkFull'))),
                        DropdownMenuItem(value: 'low', child: Text(tr('statusLowFull'))),
                        DropdownMenuItem(value: 'out', child: Text(tr('statusOutFull'))),
                      ],
                      onChanged: (v) => setSheet(() => status = v ?? status),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: tr('lblPrice'), prefixText: '$_sym ', prefixStyle: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: loc.isEmpty ? null : loc,
                  decoration: InputDecoration(labelText: tr('lblLocationOptional')),
                  items: [
                    ..._locations.map((l) => DropdownMenuItem(value: l, child: Text(l))),
                    DropdownMenuItem(value: '__new__', child: Text(tr('addNewLocation'))),
                  ],
                  onChanged: (v) async {
                    if (v == '__new__') {
                      final added = await _addLocationDialog();
                      if (added != null) setSheet(() => loc = added);
                    } else {
                      setSheet(() => loc = v ?? '');
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: exp ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 6),
                        );
                        if (d != null) setSheet(() => exp = d);
                      },
                      icon: const Icon(Icons.event),
                      label: Text(exp == null
                          ? tr('lblExpiryOptional')
                          : '${tr('expPrefix')} ${exp!.toIso8601String().substring(0, 10)}'),
                    ),
                  ),
                  if (exp != null)
                    IconButton(onPressed: () => setSheet(() => exp = null), icon: const Icon(Icons.clear)),
                ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _editItemPhoto(it),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(it.photoPath == null ? tr('btnAddPhoto') : tr('btnRetakePhoto')),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _delete(it);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18, color: kDanger),
                  label: Text(tr('btnDeleteItem'), style: const TextStyle(color: kDanger)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('btnCancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        setState(() {
                          it.name = nameCtrl.text.trim();
                          it.qty = int.tryParse(qtyCtrl.text) ?? it.qty;
                          it.unit = unit;
                          it.cat = cat;
                          it.status = status;
                          it.price = double.tryParse(priceCtrl.text) ?? 0;
                          it.location = loc;
                          it.exp = exp;
                          it.touch();
                        });
                        _persist();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check),
                      label: Text(tr('btnSaveChanges')),
                      style: FilledButton.styleFrom(backgroundColor: kBrand, foregroundColor: Colors.white),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setSheet) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: SingleChildScrollView(child: _addSheetContent(setSheet)),
          ),
        ),
      ),
    );
  }

  Widget _addSheetContent(StateSetter setSheet) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('btnAddItem'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(labelText: tr('lblItem'), hintText: tr('hintItemExample')),
            onSubmitted: (_) {
              if (_nameCtrl.text.trim().isEmpty) return;
              _add();
              Navigator.of(context).pop();
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _scan,
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: tr('titleScan'),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        SizedBox(
          width: 70,
          child: TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('lblQty')),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: DropdownButtonFormField<String>(
            initialValue: _addUnit,
            decoration: InputDecoration(labelText: tr('lblUnit')),
            items: kUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: (v) => setSheet(() => _addUnit = v ?? _addUnit),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _addCat,
            decoration: InputDecoration(labelText: tr('lblCategory')),
            items: kCats.map((c) => DropdownMenuItem(
                value: c,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(catIcon(c), size: 16, color: catColor(c)),
                  const SizedBox(width: 8),
                  Text(catLabel(c)),
                ]))).toList(),
            onChanged: (v) => setSheet(() => _addCat = v ?? _addCat),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _addStatus,
            decoration: InputDecoration(labelText: tr('lblStatus')),
            items: [
              DropdownMenuItem(value: 'ok', child: Text(tr('statusOkFull'))),
              DropdownMenuItem(value: 'low', child: Text(tr('statusLowFull'))),
              DropdownMenuItem(value: 'out', child: Text(tr('statusOutFull'))),
            ],
            onChanged: (v) => setSheet(() => _addStatus = v ?? _addStatus),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr('lblPrice'), prefixText: '$_sym ', prefixStyle: const TextStyle(fontSize: 13)),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _addLoc.isEmpty ? null : _addLoc,
            decoration: InputDecoration(labelText: tr('lblLocationOptional')),
            items: [
              ..._locations.map((l) => DropdownMenuItem(value: l, child: Text(l))),
              DropdownMenuItem(value: '__new__', child: Text(tr('addNewLocation'))),
            ],
            onChanged: (v) async {
              if (v == '__new__') {
                final added = await _addLocationDialog();
                if (added != null) setSheet(() => _addLoc = added);
              } else {
                setSheet(() => _addLoc = v ?? '');
              }
            },
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        if (_addPhotoPath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(_addPhotoPath!), width: 44, height: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final path = await _capturePhoto();
              if (path != null) setSheet(() => _addPhotoPath = path);
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_addPhotoPath == null ? tr('btnAddPhoto') : tr('btnRetakePhoto')),
          ),
        ),
        if (_addPhotoPath != null)
          IconButton(onPressed: () => setSheet(() => _addPhotoPath = null), icon: const Icon(Icons.clear)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _addExp ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 6),
              );
              if (d != null) setSheet(() => _addExp = d);
            },
            icon: const Icon(Icons.event),
            label: Text(_addExp == null
                ? tr('lblExpiryOptional')
                : '${tr('expPrefix')} ${_addExp!.toIso8601String().substring(0, 10)}'),
          ),
        ),
        if (_addExp != null)
          IconButton(onPressed: () => setSheet(() => _addExp = null), icon: const Icon(Icons.clear)),
      ]),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: () {
          if (_nameCtrl.text.trim().isEmpty) return;
          _add();
          Navigator.of(context).pop();
        },
        icon: const Icon(Icons.add),
        label: Text(tr('btnAddItem')),
        style: FilledButton.styleFrom(backgroundColor: kBrand, foregroundColor: Colors.white),
      ),
      const SizedBox(height: 12),
      _presets(),
    ]);
  }

  Widget _presets() {
    final seen = <String>{};
    final list = [..._history, ...kPresets]
        .where((n) => seen.add(n.toLowerCase()))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('quickAddCaption'),
          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
      const SizedBox(height: 6),
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ActionChip(
              label: Text('+ ${list[i]}'),
              onPressed: () {
                _quickAdd(list[i]);
                Navigator.of(context).pop();
              }),
        ),
      ),
    ]);
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: tr('hintSearch'), prefixIcon: const Icon(Icons.search)),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _sortBy,
          underline: const SizedBox(),
          items: [
            DropdownMenuItem(value: 'cat', child: Text(tr('sortCategory'))),
            DropdownMenuItem(value: 'name', child: Text(tr('sortName'))),
            DropdownMenuItem(value: 'exp', child: Text(tr('sortExpiry'))),
            DropdownMenuItem(value: 'status', child: Text(tr('sortStatus'))),
          ],
          onChanged: (v) => setState(() => _sortBy = v ?? 'cat'),
        ),
      ]),
    );
  }

  Widget _catChips() {
    final cats = ['All', ...kCats];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = cats[i];
          final label = c == 'All' ? tr('chipAll') : catLabel(c);
          final selected = (c == 'All' && _filterCat.isEmpty) || c == _filterCat;
          final count = c == 'All' ? _visibleItems.length : _visibleItems.where((it) => it.cat == c).length;
          final tint = c == 'All' ? kBrand : catColor(c);
          return ChoiceChip(
            label: Text(count > 0 ? '$label ($count)' : label,
                style: selected ? TextStyle(color: tint, fontWeight: FontWeight.w700) : null),
            selected: selected,
            selectedColor: tint.withValues(alpha: .15),
            showCheckmark: false,
            side: selected ? BorderSide(color: tint.withValues(alpha: .4)) : null,
            onSelected: (_) => setState(() => _filterCat = c == 'All' ? '' : c),
          );
        },
      ),
    );
  }

  // ---- Location tab ----
  Widget _locationTab() {
    final visible = _visibleItems;
    final unassigned = visible.any((i) => i.location.isEmpty);
    final locs = ['All', ..._locations, if (unassigned) 'Unassigned'];
    final shown = visible.where((i) {
      if (_filterLoc.isEmpty) return true;
      if (_filterLoc == 'Unassigned') return i.location.isEmpty;
      return i.location == _filterLoc;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: locs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final l = locs[i];
              final label = l == 'All' ? tr('chipAll') : (l == 'Unassigned' ? tr('chipUnassigned') : l);
              final selected = (l == 'All' && _filterLoc.isEmpty) || l == _filterLoc;
              final count = l == 'All'
                  ? visible.length
                  : (l == 'Unassigned'
                      ? visible.where((it) => it.location.isEmpty).length
                      : visible.where((it) => it.location == l).length);
              return ChoiceChip(
                label: Text(count > 0 ? '$label ($count)' : label),
                selected: selected,
                onSelected: (_) => setState(() => _filterLoc = l == 'All' ? '' : l),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_locations.isEmpty)
          TextButton.icon(
            onPressed: _manageLocations,
            icon: const Icon(Icons.add),
            label: Text(tr('btnAddFirstLocation')),
          )
        else if (shown.isEmpty)
          _empty(tr('emptyLocation'))
        else
          ...shown.map(_itemTile),
      ],
    );
  }

  Widget _catHeader(String cat, int n) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(catIcon(cat), size: 14, color: catColor(cat)),
            const SizedBox(width: 6),
            Text(catLabel(cat).toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    letterSpacing: .6, color: catColor(cat))),
          ]),
          Text('$n', style: TextStyle(color: Theme.of(context).hintColor)),
        ]),
      );

  Widget _expChip(PantryItem it) {
    final n = it.daysLeft;
    if (n == null) return const SizedBox();
    String t; Color c;
    if (n < 0) { t = 'expired ${-n}d'; c = kDanger; }
    else if (n == 0) { t = 'today'; c = kDanger; }
    else if (n <= kSoonDays) { t = '${n}d left'; c = kPurple; }
    else { t = '${tr('expPrefix')} ${it.exp!.toIso8601String().substring(5, 10)}'; c = Theme.of(context).hintColor; }
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(6)),
      child: Text(t, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }

  Widget _itemTile(PantryItem it) {
    return Dismissible(
      key: ValueKey(it.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.55},
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('dlgDeleteItemTitle')),
          content: Text(tr('dlgDeleteItemBody')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('btnCancel'))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('btnDelete'), style: const TextStyle(color: kDanger))),
          ],
        ),
      ).then((v) => v ?? false),
      onDismissed: (_) => _delete(it),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          onTap: () => _openEditSheet(it),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _photoThumb(it),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor(it.cat).withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(catLabel(it.cat), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: catColor(it.cat))),
                      ),
                      if (it.location.isNotEmpty)
                        Text(it.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                      _expChip(it),
                      if (it.price > 0)
                        Text(_fmt(it.price * it.qty), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 8),
                _statusBadge(it),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _qtyStepper(it),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: Theme.of(context).hintColor),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _photoThumb(PantryItem it) {
    final hasPhoto = it.photoPath != null && File(it.photoPath!).existsSync();
    return InkWell(
      onTap: () => _editItemPhoto(it),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: hasPhoto
            ? Image.file(File(it.photoPath!), width: 40, height: 40, fit: BoxFit.cover)
            : Container(
                width: 40, height: 40,
                color: catColor(it.cat).withValues(alpha: .15),
                child: Icon(catIcon(it.cat), size: 18, color: catColor(it.cat)),
              ),
      ),
    );
  }

  Widget _qtyStepper(PantryItem it) => Row(mainAxisSize: MainAxisSize.min, children: [
        _miniBtn(Icons.remove, () => _changeQty(it, -1)),
        InkWell(
          onTap: () => _editQtyDialog(it),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: it.unit.isEmpty ? 26 : 42, maxWidth: 64),
            child: Text(it.unit.isEmpty ? '${it.qty}' : '${it.qty}${it.unit}',
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        _miniBtn(Icons.add, () => _changeQty(it, 1)),
      ]);

  Widget _miniBtn(IconData ic, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(ic, size: 16),
        ),
      );

  // ---- Shopping tab ----
  Widget _shoppingTab() {
    final list = _shoppingList;
    if (list.isEmpty) return _empty(tr('emptyShopping'));
    final est = list.fold<double>(0, (s, i) => s + i.price * (i.qty == 0 ? 1 : i.qty));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${list.length} ${tr('itemsToBuy')}'),
              Text(est > 0 ? '~${_fmt(est)}' : '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        ...list.map(_shopTile),
      ],
    );
  }

  Widget _shopTile(PantryItem it) {
    final col = it.bought ? kGreen : _statusColor(it.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: col, width: 4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CheckboxListTile(
          value: it.bought,
          onChanged: (_) => _toggleBought(it),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(it.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: it.bought ? TextDecoration.lineThrough : null,
                color: it.bought ? Theme.of(context).hintColor : null,
              )),
          subtitle: Row(children: [
            Flexible(
              child: Text('${catLabel(it.cat)} · ${tr('needPrefix')}: ${_statusText(it.status)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ),
            _expChip(it),
          ]),
          secondary: it.price > 0
              ? Text(_fmt(it.price * (it.qty == 0 ? 1 : it.qty)),
                  style: const TextStyle(fontWeight: FontWeight.w700))
              : null,
        ),
      ),
    );
  }

  Widget _empty(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('\u{1F4E6}', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text(msg, textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
class ConsumePage extends StatefulWidget {
  final List<PantryItem> items;
  final Future<String?> Function(BuildContext) onScan;
  final void Function(PantryItem item, bool useAll) onDeduct;

  const ConsumePage({
    super.key,
    required this.items,
    required this.onScan,
    required this.onDeduct,
  });

  @override
  State<ConsumePage> createState() => _ConsumePageState();
}

class _ConsumePageState extends State<ConsumePage> {
  final _searchCtrl = TextEditingController();
  String? _flashId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await widget.onScan(context);
    if (code == null || !mounted) return;
    final match = widget.items.where((i) => i.barcode == code).toList();
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('noBarcodeMatch'))),
      );
      return;
    }
    final it = match.first;
    setState(() => _flashId = it.id);
    _confirmDeduct(it);
  }

  Future<void> _confirmDeduct(PantryItem it) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${tr('currentlyInStock')} ${it.qty} ${tr('inStockSuffix')}')),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: Text(tr('btnUsed1')),
            enabled: it.qty > 0,
            onTap: () => Navigator.pop(context, 'one'),
          ),
          ListTile(
            leading: const Icon(Icons.remove_shopping_cart),
            title: Text(tr('btnUsedAll')),
            onTap: () => Navigator.pop(context, 'all'),
          ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    widget.onDeduct(it, action == 'all');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final shown = widget.items
        .where((i) => i.qty > 0 && (q.isEmpty || i.name.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: Text(tr('tipConsume'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: tr('hintSearch'), prefixIcon: const Icon(Icons.search)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: tr('titleScan'),
            ),
          ]),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(tr('emptyConsume'),
                      style: TextStyle(color: Theme.of(context).hintColor)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final it = shown[i];
                    return Card(
                      color: _flashId == it.id ? kGreen.withValues(alpha: .15) : null,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${catLabel(it.cat)}${it.location.isEmpty ? '' : ' · ${it.location}'} · ${tr('lblQty').toLowerCase()} ${it.qty}${it.unit.isEmpty ? '' : ' ${it.unit}'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _confirmDeduct(it),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
class PurchaseHistoryPage extends StatefulWidget {
  final List<PurchaseRecord> purchases;
  final String currencySymbol;
  final void Function(PurchaseRecord) onDelete;
  final void Function(PurchaseRecord oldRecord, PurchaseRecord newRecord) onEdit;
  const PurchaseHistoryPage({
    super.key,
    required this.purchases,
    required this.currencySymbol,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  static String _ds(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _editDialog(PurchaseRecord r) async {
    final nameCtrl = TextEditingController(text: r.name);
    final qtyCtrl = TextEditingController(text: '${r.qty}');
    final priceCtrl = TextEditingController(text: r.price == 0 ? '' : r.price.toString());
    String cat = kCats.contains(r.cat) ? r.cat : kCats.first;
    String unit = kUnits.contains(r.unit) ? r.unit : kUnits.first;
    DateTime date = r.date;
    DateTime? exp = r.exp;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('titleEditPurchase'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: tr('lblItemName'))),
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('lblQty')),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: InputDecoration(labelText: tr('lblUnit')),
                    items: kUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setSheet(() => unit = v ?? unit),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: InputDecoration(labelText: tr('lblCategory')),
                    items: kCats.map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(catIcon(c), size: 16, color: catColor(c)),
                      const SizedBox(width: 8),
                      Text(catLabel(c)),
                    ]))).toList(),
                    onChanged: (v) => setSheet(() => cat = v ?? cat),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: tr('lblPrice'), prefixText: '${widget.currencySymbol} '),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context, initialDate: date,
                        firstDate: DateTime(date.year - 3), lastDate: DateTime(date.year + 1),
                      );
                      if (d != null) setSheet(() => date = d);
                    },
                    icon: const Icon(Icons.event),
                    label: Text('${tr('purchasedPrefix')} ${_ds(date)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context, initialDate: exp ?? now,
                        firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 6),
                      );
                      if (d != null) setSheet(() => exp = d);
                    },
                    icon: const Icon(Icons.event_busy),
                    label: Text(exp == null ? tr('lblExpiryOptional') : '${tr('expPrefix')} ${_ds(exp!)}'),
                  ),
                ),
                if (exp != null)
                  IconButton(onPressed: () => setSheet(() => exp = null), icon: const Icon(Icons.clear)),
              ]),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('btnSaveChanges')),
              ),
            ]),
          ),
        ),
      ),
    );

    if (saved != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onEdit(r, r.copyWith(
      name: name,
      cat: cat,
      unit: unit,
      qty: int.tryParse(qtyCtrl.text) ?? r.qty,
      price: double.tryParse(priceCtrl.text) ?? 0,
      date: date,
      exp: exp,
      clearExp: exp == null,
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final purchases = widget.purchases;
    return Scaffold(
      appBar: AppBar(title: Text(tr('titlePurchaseHistory'))),
      body: purchases.isEmpty
          ? Center(
              child: Text(tr('emptyPurchaseHistory'),
                  style: TextStyle(color: Theme.of(context).hintColor)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: purchases.length,
              itemBuilder: (_, i) {
                final r = purchases[i];
                final expPart = r.exp != null ? ' · ${tr('expPrefix')} ${_ds(r.exp!)}' : '';
                return Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    widget.onDelete(r);
                    setState(() {});
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _editDialog(r),
                      title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${catLabel(r.cat)} · ${tr('lblQty').toLowerCase()} ${r.qty}${r.unit.isEmpty ? '' : ' ${r.unit}'} · ${_ds(r.date)}$expPart'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (r.price > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text('${widget.currencySymbol}${(r.price * r.qty).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _editDialog(r),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
class SheetsSyncPage extends StatefulWidget {
  final SheetsService sheets;
  final String? spreadsheetId;
  final DateTime? lastSync;
  final List<PantryItem> items;
  final String Function() genId;
  final void Function(String id) onLinked;
  final Future<void> Function(List<PantryItem> merged) onMerged;
  final VoidCallback onSignedOut;

  const SheetsSyncPage({
    super.key,
    required this.sheets,
    required this.spreadsheetId,
    required this.lastSync,
    required this.items,
    required this.genId,
    required this.onLinked,
    required this.onMerged,
    required this.onSignedOut,
  });

  @override
  State<SheetsSyncPage> createState() => _SheetsSyncPageState();
}

class _SheetsSyncPageState extends State<SheetsSyncPage> {
  bool _busy = false;
  String? _spreadsheetId;
  DateTime? _lastSync;
  Map<String, dynamic>? _deviceCode;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _spreadsheetId = widget.spreadsheetId;
    _lastSync = widget.lastSync;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _startConnect() async {
    setState(() => _busy = true);
    try {
      final data = await widget.sheets.auth.requestDeviceCode();
      setState(() { _deviceCode = data; _busy = false; });
      final interval = ((data['interval'] as num?)?.toInt() ?? 5).clamp(3, 30);
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(Duration(seconds: interval), (t) async {
        try {
          final ok = await widget.sheets.auth.tryExchangeDeviceCode(data['device_code'] as String);
          if (ok) {
            t.cancel();
            if (mounted) setState(() => _deviceCode = null);
            _snack(tr('sheetsConnectedOk'));
          }
        } catch (e) {
          t.cancel();
          if (mounted) setState(() => _deviceCode = null);
          _snack('${tr('sheetsError')}: $e');
        }
      });
    } catch (e) {
      setState(() => _busy = false);
      _snack('${tr('sheetsError')}: $e');
    }
  }

  void _cancelConnect() {
    _pollTimer?.cancel();
    setState(() => _deviceCode = null);
  }

  Future<void> _copyCode() async {
    final code = _deviceCode?['user_code']?.toString() ?? '';
    await Clipboard.setData(ClipboardData(text: code));
    _snack(tr('codeCopied'));
  }

  Future<void> _signOut() async {
    await widget.sheets.signOut();
    widget.onSignedOut();
    setState(() {});
  }

  Future<void> _createSheet() async {
    setState(() => _busy = true);
    try {
      final id = await widget.sheets.createSpreadsheet('Pantry Inventory');
      widget.onLinked(id);
      setState(() => _spreadsheetId = id);
      await _sync();
    } catch (e) {
      _snack('${tr('sheetsError')}: $e');
    }
    setState(() => _busy = false);
  }

  Future<void> _useExisting() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('btnUseExisting')),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: tr('hintSheetUrl'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('btnCancel'))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text(tr('btnAdd'))),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    final id = extractSpreadsheetId(url);
    if (id == null) {
      _snack(tr('sheetsError'));
      return;
    }
    widget.onLinked(id);
    setState(() => _spreadsheetId = id);
  }

  Future<void> _sync() async {
    if (_spreadsheetId == null) return;
    setState(() => _busy = true);
    try {
      final merged = await widget.sheets.syncMerge(_spreadsheetId!, widget.items, widget.genId);
      await widget.onMerged(merged);
      setState(() => _lastSync = DateTime.now());
      _snack(tr('sheetsPushOk'));
    } catch (e) {
      _snack('${tr('sheetsError')}: $e');
    }
    setState(() => _busy = false);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: 'https://docs.google.com/spreadsheets/d/$_spreadsheetId'));
    _snack(tr('linkCopied'));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.sheets.isSignedIn;
    final email = widget.sheets.email;
    return Scaffold(
      appBar: AppBar(title: Text(tr('titleSheets'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(!signedIn ? tr('sheetsNotSignedIn') : '${tr('sheetsSignedInAs')} ${email ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (_deviceCode != null) ...[
                  Text(tr('deviceFlowInstructions'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  const SizedBox(height: 8),
                  SelectableText(
                    (_deviceCode!['verification_url'] ?? _deviceCode!['verification_uri'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: kBrand.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text((_deviceCode!['user_code'] ?? '').toString(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(onPressed: _copyCode, icon: const Icon(Icons.copy), label: Text(tr('btnCopyCode'))),
                    TextButton(onPressed: _cancelConnect, child: Text(tr('btnCancelConnect'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(tr('deviceFlowWaiting'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ]),
                ] else if (!signedIn)
                  FilledButton.icon(
                    onPressed: _busy ? null : _startConnect,
                    icon: const Icon(Icons.login),
                    label: Text(tr('btnSignIn')),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: Text(tr('btnSignOut')),
                  ),
              ]),
            ),
          ),
          if (signedIn) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_spreadsheetId == null ? tr('sheetsNoSpreadsheet') : tr('sheetsLinked'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (_spreadsheetId == null)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _createSheet,
                        icon: const Icon(Icons.add),
                        label: Text(tr('btnCreateSheet')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _useExisting,
                        icon: const Icon(Icons.link),
                        label: Text(tr('btnUseExisting')),
                      ),
                    ])
                  else ...[
                    SelectableText('https://docs.google.com/spreadsheets/d/$_spreadsheetId',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(onPressed: _copyLink, icon: const Icon(Icons.copy), label: Text(tr('btnCopyLink'))),
                      FilledButton.icon(
                        onPressed: _busy ? null : _sync,
                        icon: const Icon(Icons.sync),
                        label: Text(tr('btnSyncNow')),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text('${tr('sheetsLastSync')}: ${_lastSync == null ? tr('sheetsNever') : _lastSync.toString().substring(0, 16)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text(tr('sheetsAutoSyncNote'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 6),
            Text(tr('photoNote'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // No `formats` restriction — detect any barcode symbology ML Kit supports,
  // since limiting to a handful of formats can silently miss whatever a
  // given product actually uses (nothing appears, no error).
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _done = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done || !mounted) return;
    final codes = capture.barcodes;
    if (codes.isNotEmpty && codes.first.rawValue != null) {
      _done = true;
      Navigator.of(context).pop(codes.first.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('titleScan')),
        actions: [
          IconButton(
            tooltip: tr('tipFlash'),
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            tooltip: tr('btnTypeManually'),
            icon: const Icon(Icons.keyboard),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _ScanError(
            message: error.toString(),
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 240, height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: kBrand, width: 3),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: Text(tr('hintPointCamera'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ]),
    );
  }
}

class _ScanError extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _ScanError({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.no_photography, color: Colors.white70, size: 56),
        const SizedBox(height: 16),
        Text(tr('titleCameraUnavailable'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          tr('bodyCameraUnavailable'),
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.keyboard),
          label: Text(tr('btnTypeManually')),
        ),
        const SizedBox(height: 24),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 11)),
      ]),
    );
  }
}
