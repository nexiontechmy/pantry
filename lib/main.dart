import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

void main() => runApp(const PantryApp());

const List<String> kCats = [
  'Produce', 'Dairy', 'Meat & Fish', 'Pantry', 'Frozen',
  'Bakery', 'Drinks', 'Snacks',
  'Toiletries', 'Cleaning Supplies', 'Personal Care',
  'Household', 'Other'
];
const List<String> kDefaultLocations = [
  'Kitchen Fridge', 'Kitchen Freezer', 'Kitchen Pantry',
  'Bathroom Cabinet', 'Laundry Room', 'Garage Storage',
];
const List<String> kPresets = [
  'Milk', 'Eggs', 'Bread', 'Butter', 'Cheese', 'Yogurt',
  'Coffee', 'Tea', 'Water', 'Juice',
  'Rice', 'Pasta', 'Flour', 'Sugar', 'Salt', 'Cooking oil', 'Cereal',
  'Bananas', 'Apples', 'Tomatoes', 'Onions', 'Potatoes', 'Lettuce',
  'Chicken', 'Beef', 'Fish',
  'Chips', 'Cookies',
  'Toilet paper', 'Dish soap', 'Detergent', 'Toothpaste', 'Shampoo',
];
const Map<String, String> kCatGuess = {
  'Milk': 'Dairy', 'Eggs': 'Dairy', 'Butter': 'Dairy', 'Cheese': 'Dairy', 'Yogurt': 'Dairy',
  'Bread': 'Bakery',
  'Coffee': 'Drinks', 'Tea': 'Drinks', 'Water': 'Drinks', 'Juice': 'Drinks',
  'Rice': 'Pantry', 'Pasta': 'Pantry', 'Flour': 'Pantry', 'Sugar': 'Pantry',
  'Salt': 'Pantry', 'Cooking oil': 'Pantry', 'Cereal': 'Pantry',
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
  'sheetsLastSync': {'en': 'Last synced', 'zh': '上次同步', 'ms': 'Segerak terakhir'},
  'sheetsNever': {'en': 'never', 'zh': '从未', 'ms': 'tiada'},
  'dlgPullTitle': {'en': 'Pull from Sheets?', 'zh': '从表格拉取？', 'ms': 'Tarik dari Sheets?'},
  'dlgPullBody': {'en': 'This replaces your current inventory with what\'s in the spreadsheet. Any local changes not yet pushed will be lost.', 'zh': '这将用表格中的数据替换当前库存。尚未推送的本地更改将丢失。', 'ms': 'Ini akan menggantikan inventori semasa anda dengan kandungan hamparan. Sebarang perubahan tempatan yang belum ditolak akan hilang.'},
  'sheetsPushOk': {'en': 'Pushed to Google Sheets', 'zh': '已推送到 Google 表格', 'ms': 'Berjaya ditolak ke Google Sheets'},
  'sheetsPullOk': {'en': 'Pulled from Google Sheets', 'zh': '已从 Google 表格拉取', 'ms': 'Berjaya ditarik dari Google Sheets'},
  'sheetsError': {'en': 'Sync error', 'zh': '同步出错', 'ms': 'Ralat penyegerakan'},
  'sheetsAutoSyncNote': {'en': 'While connected, changes you make here push to Sheets automatically. Use "Pull" to fetch edits made directly in Sheets.', 'zh': '连接后，您在此处所做的更改会自动推送到表格。使用"拉取"以获取直接在表格中所做的编辑。', 'ms': 'Semasa disambungkan, perubahan yang anda buat di sini ditolak secara automatik ke Sheets. Guna "Tarik" untuk mendapatkan suntingan yang dibuat terus dalam Sheets.'},
};

class PantryItem {
  String id, name, cat, status; // status: ok | low | out
  int qty;
  double price;
  DateTime? exp;
  bool bought;
  String location;
  String? barcode;

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
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'cat': cat, 'status': status, 'qty': qty,
        'price': price, 'exp': exp?.toIso8601String(), 'bought': bought,
        'location': location, 'barcode': barcode,
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

  PurchaseRecord({
    required this.id,
    required this.name,
    required this.cat,
    required this.qty,
    required this.price,
    required this.date,
    this.exp,
  });

  PurchaseRecord copyWith({String? name, String? cat, int? qty, double? price, DateTime? date, DateTime? exp, bool clearExp = false}) =>
      PurchaseRecord(
        id: id,
        name: name ?? this.name,
        cat: cat ?? this.cat,
        qty: qty ?? this.qty,
        price: price ?? this.price,
        date: date ?? this.date,
        exp: clearExp ? null : (exp ?? this.exp),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'cat': cat, 'qty': qty,
        'price': price, 'date': date.toIso8601String(), 'exp': exp?.toIso8601String(),
      };

  factory PurchaseRecord.fromJson(Map<String, dynamic> j) => PurchaseRecord(
        id: j['id']?.toString() ?? UniqueKey().toString(),
        name: (j['name'] ?? '').toString(),
        cat: (j['cat'] ?? 'Other').toString(),
        qty: (j['qty'] is num) ? (j['qty'] as num).toInt() : 1,
        price: (j['price'] is num) ? (j['price'] as num).toDouble() : 0,
        exp: (j['exp'] != null) ? DateTime.tryParse(j['exp'].toString()) : null,
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
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

class SheetsService {
  static const _scopes = ['https://www.googleapis.com/auth/spreadsheets'];
  final GoogleSignIn _google = GoogleSignIn(scopes: _scopes);
  GoogleSignInAccount? account;

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      account = await _google.signInSilently();
    } catch (_) {}
    return account;
  }

  Future<GoogleSignInAccount?> signIn() async {
    account = await _google.signIn();
    return account;
  }

  Future<void> signOut() async {
    await _google.signOut();
    account = null;
  }

  Future<Map<String, String>> _headers() async {
    final acc = account;
    if (acc == null) throw Exception('Not signed in');
    final h = await acc.authHeaders;
    return {...h, 'Content-Type': 'application/json'};
  }

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
      ['Name', 'Category', 'Qty', 'Status', 'Price', 'Expiry', 'Location', 'Barcode'],
      ...items.map((it) => [
            it.name, it.cat, it.qty, it.status, it.price,
            it.exp?.toIso8601String().substring(0, 10) ?? '',
            it.location, it.barcode ?? '',
          ]),
    ];
    await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Inventory!A1:H10000:clear'),
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
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Inventory!A2:H10000'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('${res.statusCode}: ${res.body}');
    final values = ((jsonDecode(res.body) as Map)['values'] as List?) ?? [];
    return values
        .where((r) => r is List && r.isNotEmpty && r[0].toString().trim().isNotEmpty)
        .map<PantryItem>((r) {
      final row = List<String>.generate(8, (i) => i < (r as List).length ? r[i].toString() : '');
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
      );
    }).toList();
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
    final scheme = ColorScheme.fromSeed(seedColor: kGreen, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
      cardColor: b == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
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
  late TabController _tab;

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _addCat = kCats.first;
  String _addStatus = 'ok';
  DateTime? _addExp;
  String _addLoc = '';
  String? _addBarcode;
  String _filterCat = '';
  String _filterLoc = '';
  String _sortBy = 'cat';

  String get _sym => kCurrencySymbols[_currency] ?? _currency;
  String _fmt(double v) => '$_sym${v.toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
    _load();
    _sheets.signInSilently().then((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _tab.dispose();
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
    if (_sheets.account == null || _spreadsheetId == null) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), () async {
      try {
        await _sheets.pushInventory(_spreadsheetId!, _items);
        await _setLastSync();
      } catch (_) {}
    });
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
                if (l == gLang) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 18, color: kGreen)),
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
                if (c == _currency) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 18, color: kGreen)),
              ]),
            )).toList(),
      ),
    );
    if (v != null) { setState(() => _currency = v); _persist(); }
  }

  void _logPurchase(PantryItem it) {
    _purchases.insert(0, PurchaseRecord(
      id: _uid(), name: it.name, cat: it.cat, qty: it.qty, price: it.price, date: DateTime.now(), exp: it.exp,
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

  void _changeQty(PantryItem it, int d) {
    setState(() {
      it.qty = (it.qty + d).clamp(0, 9999);
      if (it.qty == 0 && it.status == 'ok') it.status = 'out';
    });
    _persist();
  }

  void _setStatus(PantryItem it, String s) { setState(() => it.status = s); _persist(); }
  void _delete(PantryItem it) { setState(() => _items.remove(it)); _persist(); }
  void _toggleBought(PantryItem it) { setState(() => it.bought = !it.bought); _persist(); }

  void _restockBought() {
    setState(() {
      for (final i in _items.where((e) => e.bought)) {
        i.bought = false; i.status = 'ok';
        if (i.qty == 0) i.qty = 1;
      }
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
        items: _items,
        onScan: _scanForConsume,
        onDeduct: (it, useAll) {
          setState(() {
            it.qty = useAll ? 0 : (it.qty - 1).clamp(0, 9999);
            if (it.qty == 0) it.status = 'out';
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
      _snack('${tr('snackBackupCopied')} (${_items.length})');
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
      if (mounted) _snack('${tr('snackImported')} (${_items.length})');
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
              subtitle: Text(_sheets.account?.email ?? tr('sheetsNotSignedIn'),
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
                      onSynced: _setLastSync,
                      onPulled: (list) { setState(() => _items = list); _persist(); },
                      onSignedOut: () { setState(() {}); },
                    )));
              }),
          ListTile(leading: const Icon(Icons.delete_outline, color: kDanger),
              title: Text(tr('menuDeleteAll')),
              onTap: _confirmClear),
        ]),
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
            onPressed: () { setState(() => _items.clear()); _persist(); Navigator.pop(context); },
            child: Text(tr('btnDelete'), style: const TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
  }

  // ---- derived ----
  Color _statusColor(String s) => s == 'out' ? kDanger : (s == 'low' ? kWarn : kGreen);
  String _statusText(String s) => s == 'out' ? tr('statOut') : (s == 'low' ? tr('statLow') : tr('statusInStock'));

  List<PantryItem> get _shoppingList =>
      _items.where((i) => i.status != 'ok' || i.expiringSoon).toList()
        ..sort((a, b) {
          final c = (a.bought ? 1 : 0) - (b.bought ? 1 : 0);
          return c != 0 ? c : a.cat.compareTo(b.cat);
        });

  @override
  Widget build(BuildContext context) {
    final low = _items.where((i) => i.status == 'low').length;
    final out = _items.where((i) => i.status == 'out').length;
    final exp = _items.where((i) => i.expiringSoon).length;

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
          IconButton(tooltip: tr('tipData'), onPressed: _dataMenu, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              _stat('${_items.length}', tr('statItems'), null),
              _stat('$low', tr('statLow'), kWarn),
              _stat('$out', tr('statOut'), kDanger),
              _stat('$exp', tr('statExpiring'), kPurple),
            ]),
          ),
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '${tr('tabInventory')} (${_items.length})'),
              Tab(text: '\u{1F4CD} ${tr('tabLocation')}'),
              Tab(text: '\u{1F6D2} ${tr('tabShopping')} (${_shoppingList.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_inventoryTab(), _locationTab(), _shoppingTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String n, String label, Color? color) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(children: [
            Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          ]),
        ),
      ),
    );
  }

  // ---- Inventory tab ----
  Widget _inventoryTab() {
    final q = _searchCtrl.text.trim().toLowerCase();
    var shown = _items.where((i) =>
        (q.isEmpty || i.name.toLowerCase().contains(q)) &&
        (_filterCat.isEmpty || i.cat == _filterCat)).toList();

    final children = <Widget>[_addCard(), _toolbar(), _catChips(), const SizedBox(height: 8)];

    if (shown.isEmpty) {
      children.add(_empty(_items.isEmpty
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

  Widget _addCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: tr('lblItem'), hintText: tr('hintItemExample')),
                onSubmitted: (_) => _add(),
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
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _addCat,
                decoration: InputDecoration(labelText: tr('lblCategory')),
                items: kCats.map((c) => DropdownMenuItem(value: c, child: Text(catLabel(c)))).toList(),
                onChanged: (v) => setState(() => _addCat = v ?? _addCat),
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
                onChanged: (v) => setState(() => _addStatus = v ?? _addStatus),
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
                    if (added != null) setState(() => _addLoc = added);
                  } else {
                    setState(() => _addLoc = v ?? '');
                  }
                },
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
                    context: context,
                    initialDate: _addExp ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 6),
                  );
                  if (d != null) setState(() => _addExp = d);
                },
                icon: const Icon(Icons.event),
                label: Text(_addExp == null
                    ? tr('lblExpiryOptional')
                    : '${tr('expPrefix')} ${_addExp!.toIso8601String().substring(0, 10)}'),
              ),
            ),
            if (_addExp != null)
              IconButton(onPressed: () => setState(() => _addExp = null), icon: const Icon(Icons.clear)),
          ]),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(tr('btnAddItem')),
            style: FilledButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black),
          ),
          const SizedBox(height: 12),
          _presets(),
        ]),
      ),
    );
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
          itemBuilder: (_, i) =>
              ActionChip(label: Text('+ ${list[i]}'), onPressed: () => _quickAdd(list[i])),
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
          final count = c == 'All' ? _items.length : _items.where((it) => it.cat == c).length;
          return ChoiceChip(
            label: Text(count > 0 ? '$label ($count)' : label),
            selected: selected,
            onSelected: (_) => setState(() => _filterCat = c == 'All' ? '' : c),
          );
        },
      ),
    );
  }

  // ---- Location tab ----
  Widget _locationTab() {
    final unassigned = _items.any((i) => i.location.isEmpty);
    final locs = ['All', ..._locations, if (unassigned) 'Unassigned'];
    final shown = _items.where((i) {
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
                  ? _items.length
                  : (l == 'Unassigned'
                      ? _items.where((it) => it.location.isEmpty).length
                      : _items.where((it) => it.location == l).length);
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
          Text(catLabel(cat).toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  letterSpacing: .6, color: Theme.of(context).hintColor)),
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
    final col = _statusColor(it.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: col, width: 4)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(children: [
          _qtyStepper(it),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(
                  child: Text(it.location.isEmpty ? catLabel(it.cat) : '${catLabel(it.cat)} · ${it.location}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ),
                _expChip(it),
                if (it.price > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(_fmt(it.price * it.qty),
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ),
              ]),
            ]),
          ),
          DropdownButton<String>(
            value: it.status,
            underline: const SizedBox(),
            onChanged: (v) => _setStatus(it, v ?? it.status),
            items: const [
              DropdownMenuItem(value: 'ok', child: Text('✅')),
              DropdownMenuItem(value: 'low', child: Text('⚠️')),
              DropdownMenuItem(value: 'out', child: Text('❌')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Theme.of(context).hintColor,
            onPressed: () => _delete(it),
          ),
        ]),
      ),
    );
  }

  Widget _qtyStepper(PantryItem it) => Row(mainAxisSize: MainAxisSize.min, children: [
        _miniBtn(Icons.remove, () => _changeQty(it, -1)),
        SizedBox(
          width: 26,
          child: Text('${it.qty}', textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700)),
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
                        subtitle: Text('${catLabel(it.cat)}${it.location.isEmpty ? '' : ' · ${it.location}'} · ${tr('lblQty').toLowerCase()} ${it.qty}'),
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
                  width: 80,
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('lblQty')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: InputDecoration(labelText: tr('lblCategory')),
                    items: kCats.map((c) => DropdownMenuItem(value: c, child: Text(catLabel(c)))).toList(),
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
                      subtitle: Text('${catLabel(r.cat)} · ${tr('lblQty').toLowerCase()} ${r.qty} · ${_ds(r.date)}$expPart'),
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
  final Future<void> Function() onSynced;
  final void Function(List<PantryItem> items) onPulled;
  final VoidCallback onSignedOut;

  const SheetsSyncPage({
    super.key,
    required this.sheets,
    required this.spreadsheetId,
    required this.lastSync,
    required this.items,
    required this.genId,
    required this.onLinked,
    required this.onSynced,
    required this.onPulled,
    required this.onSignedOut,
  });

  @override
  State<SheetsSyncPage> createState() => _SheetsSyncPageState();
}

class _SheetsSyncPageState extends State<SheetsSyncPage> {
  bool _busy = false;
  String? _spreadsheetId;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _spreadsheetId = widget.spreadsheetId;
    _lastSync = widget.lastSync;
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await widget.sheets.signIn();
    } catch (e) {
      _snack('${tr('sheetsError')}: $e');
    }
    setState(() => _busy = false);
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
      await _push();
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

  Future<void> _push() async {
    if (_spreadsheetId == null) return;
    setState(() => _busy = true);
    try {
      await widget.sheets.pushInventory(_spreadsheetId!, widget.items);
      await widget.onSynced();
      setState(() => _lastSync = DateTime.now());
      _snack(tr('sheetsPushOk'));
    } catch (e) {
      _snack('${tr('sheetsError')}: $e');
    }
    setState(() => _busy = false);
  }

  Future<void> _pull() async {
    if (_spreadsheetId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('dlgPullTitle')),
        content: Text(tr('dlgPullBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('btnCancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('btnPullNow'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final list = await widget.sheets.pullInventory(_spreadsheetId!, widget.genId);
      widget.onPulled(list);
      await widget.onSynced();
      setState(() => _lastSync = DateTime.now());
      _snack(tr('sheetsPullOk'));
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
    final acc = widget.sheets.account;
    return Scaffold(
      appBar: AppBar(title: Text(tr('titleSheets'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(acc == null ? tr('sheetsNotSignedIn') : '${tr('sheetsSignedInAs')} ${acc.email}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (acc == null)
                  FilledButton.icon(
                    onPressed: _busy ? null : _signIn,
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
          if (acc != null) ...[
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
                        onPressed: _busy ? null : _push,
                        icon: const Icon(Icons.upload),
                        label: Text(tr('btnPushNow')),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _pull,
                        icon: const Icon(Icons.download),
                        label: Text(tr('btnPullNow')),
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
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13, BarcodeFormat.ean8,
      BarcodeFormat.upcA, BarcodeFormat.upcE,
      BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.itf,
    ],
  );
  bool _done = false;

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
                border: Border.all(color: kGreen, width: 3),
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
