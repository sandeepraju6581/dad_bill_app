// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'orders_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode');
  ThemeMode initialTheme = ThemeMode.system;
  if (savedTheme == 'light') initialTheme = ThemeMode.light;
  if (savedTheme == 'dark') initialTheme = ThemeMode.dark;

  runApp(MyApp(initialTheme: initialTheme));
}

class MyApp extends StatefulWidget {
  final ThemeMode initialTheme;
  const MyApp({super.key, required this.initialTheme});

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialTheme;
  }

  void changeTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove('theme_mode');
    } else {
      await prefs.setString(
        'theme_mode',
        mode == ThemeMode.light ? 'light' : 'dark',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sri Gayathri Digital',
      themeMode: _themeMode,
      theme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1d6f96),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1d6f96),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
      ),
      home: const BillingSuite(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Models
class Customer {
  int id;
  String name;
  double balance;
  String? lastBillDate;
  List<CustomerAction> history;

  Customer({
    required this.id,
    required this.name,
    required this.balance,
    this.lastBillDate,
    List<CustomerAction>? history,
  }) : history = history ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'balance': balance,
    'lastBillDate': lastBillDate,
    'history': history.map((e) => e.toJson()).toList(),
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    List<CustomerAction> parsedHistory = [];
    if (json['history'] != null) {
      parsedHistory = (json['history'] as List)
          .map((e) => CustomerAction.fromJson(e))
          .toList();
    }
    return Customer(
      id: json['id'],
      name: json['name'],
      balance: json['balance'],
      lastBillDate: json['lastBillDate'],
      history: parsedHistory,
    );
  }
}

class CustomerAction {
  String type; // 'bill' or 'payment'
  String date;
  String desc;
  double amount;

  CustomerAction({
    required this.type,
    required this.date,
    required this.desc,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'date': date,
    'desc': desc,
    'amount': amount,
  };

  factory CustomerAction.fromJson(Map<String, dynamic> json) => CustomerAction(
    type: json['type'] ?? 'bill',
    date: json['date'] ?? '',
    desc: json['desc'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
  );
}

class SavedPdf {
  final String fileName;
  final String filePath;
  final String customerName;
  final String date;
  final String type; // 'Invoice' or 'Receipt'

  SavedPdf({
    required this.fileName,
    required this.filePath,
    required this.customerName,
    required this.date,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'filePath': filePath,
        'customerName': customerName,
        'date': date,
        'type': type,
      };

  factory SavedPdf.fromJson(Map<String, dynamic> json) => SavedPdf(
        fileName: json['fileName'] ?? '',
        filePath: json['filePath'] ?? '',
        customerName: json['customerName'] ?? 'Unknown',
        date: json['date'] ?? '',
        type: json['type'] ?? 'Invoice',
      );
}

class BillItem {
  String desc;
  double w;
  double h;
  int rw;
  int rh;
  int qty;
  int holes;
  double holeCost;
  bool hasPolish;
  double polishCost;
  double designCost;
  double glassCost;
  double printCost;
  double total;
  String itemType; // 'both' or 'print_only'
  String dimUnit; // 'in' or 'mm'
  String thickness; // '4mm', '5mm', etc.

  BillItem({
    required this.desc,
    required this.w,
    required this.h,
    required this.rw,
    required this.rh,
    required this.qty,
    this.dimUnit = 'in',
    this.thickness = '5mm',
    this.holes = 0,
    this.holeCost = 0.0,
    this.hasPolish = false,
    this.polishCost = 0.0,
    this.designCost = 0.0,
    required this.glassCost,
    required this.printCost,
    required this.total,
    required this.itemType,
  });
}

// Settings class to store configurable rates
class AppSettings {
  static const String glassRateKey = 'glass_rate';
  static const String printRateKey = 'print_rate';

  double glassRate = 65.0; // ₹ per sqft
  double printRate = 180.0; // ₹ per sqft
  double holeRate = 25.0; // ₹ per hole
  double polishRate = 15.0; // ₹ per foot

  AppSettings();

  Map<String, dynamic> toJson() => {
    'glassRate': glassRate,
    'printRate': printRate,
    'holeRate': holeRate,
    'polishRate': polishRate,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    AppSettings settings = AppSettings();
    settings.glassRate = (json['glassRate'] ?? 65.0).toDouble();
    settings.printRate = (json['printRate'] ?? 180.0).toDouble();
    settings.holeRate = (json['holeRate'] ?? 25.0).toDouble();
    settings.polishRate = (json['polishRate'] ?? 5.0).toDouble();
    return settings;
  }
}

// Main Billing Suite Widget
class BillingSuite extends StatefulWidget {
  const BillingSuite({super.key});

  @override
  State<BillingSuite> createState() => _BillingSuiteState();
}

class _BillingSuiteState extends State<BillingSuite>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Bill data
  List<BillItem> currentBillItems = [];
  TextEditingController custNameController = TextEditingController();
  TextEditingController itemDescController = TextEditingController();
  TextEditingController widthController = TextEditingController();
  TextEditingController heightController = TextEditingController();
  TextEditingController qtyController = TextEditingController();
  TextEditingController holesController = TextEditingController();
  TextEditingController designCostController = TextEditingController();
  TextEditingController invDateController = TextEditingController();

  // New: Item type selection
  String selectedItemType = 'both'; // 'both' or 'print_only'
  String inputUnit = 'in'; // 'in' or 'mm'

  // Glass Polish
  bool applyPolish = false;

  // GST
  bool includeGST = false;

  // Invoice Counter
  int invoiceCounter = 1;

  // Customer management
  List<Customer> customers = [];

  // New customer form
  TextEditingController newCustNameController = TextEditingController();
  TextEditingController newCustBalanceController = TextEditingController();

  // Payment form
  Customer? selectedPaymentCustomer;
  TextEditingController paymentAmountController = TextEditingController();

  // Settings
  AppSettings settings = AppSettings();
  TextEditingController glassRateController = TextEditingController();
  TextEditingController printRateController = TextEditingController();
  TextEditingController holeRateController = TextEditingController();
  TextEditingController polishRateController = TextEditingController();

  // Saved PDFs
  List<SavedPdf> savedPdfs = [];

  // Glass Thickness selection
  String selectedThickness = '5mm';
  final Map<String, double> thicknessRates = {
    '4mm': 55.0,
    '5mm': 65.0,
    '6mm': 75.0,
    '8mm': 80.0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
    ); // 5 tabs: Bill, Customers, Orders, Saved Bills, Settings
    invDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    qtyController.text = '1';
    holesController.text = '0';
    designCostController.text = '0';
    newCustBalanceController.text = '0';
    loadInvoiceCounter();
    loadCustomers();
    loadSettings();
    loadSavedPdfs();
  }

  // Load invoice counter
  Future<void> loadInvoiceCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      invoiceCounter = prefs.getInt('invoice_counter') ?? 1;
    });
  }

  // Save invoice counter
  Future<void> saveInvoiceCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('invoice_counter', invoiceCounter);
  }

  @override
  void dispose() {
    _tabController.dispose();
    custNameController.dispose();
    itemDescController.dispose();
    widthController.dispose();
    heightController.dispose();
    qtyController.dispose();
    holesController.dispose();
    designCostController.dispose();
    invDateController.dispose();
    newCustNameController.dispose();
    newCustBalanceController.dispose();
    paymentAmountController.dispose();
    glassRateController.dispose();
    printRateController.dispose();
    holeRateController.dispose();
    polishRateController.dispose();
    super.dispose();
  }

  // Load settings from shared preferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsJson = prefs.getString('app_settings');
    if (settingsJson != null) {
      setState(() {
        settings = AppSettings.fromJson(json.decode(settingsJson));
        glassRateController.text = settings.glassRate.toString();
        printRateController.text = settings.printRate.toString();
        holeRateController.text = settings.holeRate.toString();
        polishRateController.text = settings.polishRate.toString();
      });
    } else {
      glassRateController.text = settings.glassRate.toString();
      printRateController.text = settings.printRate.toString();
      holeRateController.text = settings.holeRate.toString();
      polishRateController.text = settings.polishRate.toString();
    }
  }

  // Save settings
  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_settings', json.encode(settings.toJson()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Rates updated successfully!')),
    );
  }

  // Update glass rate
  void updateGlassRate() {
    double? newRate = double.tryParse(glassRateController.text);
    if (newRate != null && newRate > 0) {
      setState(() {
        settings.glassRate = newRate;
      });
      saveSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid glass rate. Please enter a positive number.'),
        ),
      );
      glassRateController.text = settings.glassRate.toString();
    }
  }

  // Update print rate
  void updatePrintRate() {
    double? newRate = double.tryParse(printRateController.text);
    if (newRate != null && newRate > 0) {
      setState(() {
        settings.printRate = newRate;
      });
      saveSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid print rate. Please enter a positive number.'),
        ),
      );
      printRateController.text = settings.printRate.toString();
    }
  }

  // Update hole rate
  void updateHoleRate() {
    double? newRate = double.tryParse(holeRateController.text);
    if (newRate != null && newRate >= 0) {
      setState(() {
        settings.holeRate = newRate;
      });
      saveSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid hole rate. Please enter a valid number.'),
        ),
      );
      holeRateController.text = settings.holeRate.toString();
    }
  }

  // Update polish rate
  void updatePolishRate() {
    double? newRate = double.tryParse(polishRateController.text);
    if (newRate != null && newRate >= 0) {
      setState(() {
        settings.polishRate = newRate;
      });
      saveSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid polish rate. Please enter a valid number.'),
        ),
      );
      polishRateController.text = settings.polishRate.toString();
    }
  }

  // Load customers from shared preferences
  Future<void> loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? customersJson = prefs.getString('customers');
    if (customersJson != null) {
      List<dynamic> decoded = json.decode(customersJson);
      setState(() {
        customers = decoded.map((item) => Customer.fromJson(item)).toList();
      });
    }
  }

  // Save customers to shared preferences
  Future<void> saveCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> customersMap = customers
        .map((c) => c.toJson())
        .toList();
    await prefs.setString('customers', json.encode(customersMap));
    setState(() {});
  }

  // Load saved PDFs from shared preferences
  Future<void> loadSavedPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? pdfsJson = prefs.getString('saved_pdfs');
    if (pdfsJson != null) {
      List<dynamic> decoded = json.decode(pdfsJson);
      setState(() {
        savedPdfs = decoded.map((item) => SavedPdf.fromJson(item)).toList();
        // Sort by date (newest first)
        savedPdfs.sort((a, b) => b.date.compareTo(a.date));
      });
    }
  }

  // Save PDF list to shared preferences
  Future<void> savePdfList() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> pdfsMap =
        savedPdfs.map((p) => p.toJson()).toList();
    await prefs.setString('saved_pdfs', json.encode(pdfsMap));
  }

  // Utility to save PDF file to local storage
  Future<void> savePdfToFile(
    Uint8List bytes,
    String fileName,
    String customerName,
    String type,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Create a specific folder for PDFs
      final pdfDir = Directory('${directory.path}/Saved_Bills');
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }

      final filePath = '${pdfDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      setState(() {
        savedPdfs.insert(
          0,
          SavedPdf(
            fileName: fileName,
            filePath: filePath,
            customerName: customerName,
            date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            type: type,
          ),
        );
      });
      await savePdfList();
    } catch (e) {
      debugPrint('Error saving PDF file: $e');
    }
  }

  // Round up to nearest 3
  int roundUpTo3(double value) {
    return (value / 3).ceil() * 3;
  }

  // Compute costs for an item based on type
  Map<String, dynamic> computeCosts(
    double w,
    double h,
    String itemType,
    String thickness,
  ) {
    int rw = roundUpTo3(w);
    int rh = roundUpTo3(h);
    double glassAreaSqFt = (rw * rh) / 144;
    double printAreaSqFt = (w.ceil() * h.ceil()) / 144;

    double glassCost = 0;
    double printCost = 0;

    double currentGlassRate = thicknessRates[thickness] ?? settings.glassRate;

    if (itemType == 'both') {
      glassCost = glassAreaSqFt * currentGlassRate;
      printCost = printAreaSqFt * settings.printRate;
    } else if (itemType == 'print_only') {
      glassCost = 0;
      printCost = printAreaSqFt * settings.printRate;
    }

    return {'glassCost': glassCost, 'printCost': printCost, 'rw': rw, 'rh': rh};
  }

  // Add item to bill
  void addItemToBill() {
    if (custNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name first')),
      );
      return;
    }

    if (itemDescController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item description')),
      );
      return;
    }

    double? w = double.tryParse(widthController.text);
    double? h = double.tryParse(heightController.text);
    int qty = int.tryParse(qtyController.text) ?? 1;
    int holes = (selectedItemType == 'print_only')
        ? 0
        : (int.tryParse(holesController.text) ?? 0);
    double designCost = double.tryParse(designCostController.text) ?? 0.0;

    if (w == null || h == null || w <= 0 || h <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid width and height required')),
      );
      return;
    }

    if (qty < 1) qty = 1;

    double w_in = inputUnit == 'mm' ? w / 25.4 : w;
    double h_in = inputUnit == 'mm' ? h / 25.4 : h;

    var costs = computeCosts(w_in, h_in, selectedItemType, selectedThickness);
    double holeCost = holes * settings.holeRate;
    double polishCost = 0.0;
    if (selectedItemType == 'both' && applyPolish) {
      polishCost =
          (((costs['rw'] * 2) + (costs['rh'] * 2)) / 12) * settings.polishRate;
    }
    double total =
        (costs['glassCost'] +
            costs['printCost'] +
            holeCost +
            polishCost +
            designCost) *
        qty;

    setState(() {
      currentBillItems.add(
        BillItem(
          desc: itemDescController.text,
          w: w,
          h: h,
          dimUnit: inputUnit,
          rw: costs['rw'],
          rh: costs['rh'],
          qty: qty,
          holes: holes,
          holeCost: holeCost,
          hasPolish: selectedItemType == 'both' ? applyPolish : false,
          polishCost: polishCost,
          designCost: designCost,
          glassCost: costs['glassCost'],
          printCost: costs['printCost'],
          total: total,
          itemType: selectedItemType,
          thickness: selectedThickness,
        ),
      );

      // Clear item fields
      itemDescController.clear();
      widthController.clear();
      heightController.clear();
      qtyController.text = '1';
      holesController.text = '0';
      designCostController.text = '0';
      applyPolish = false;
    });
  }

  // Remove item from bill
  void removeBillItem(int index) {
    setState(() {
      currentBillItems.removeAt(index);
    });
  }

  // Calculate subtotal
  double getSubTotal() {
    return currentBillItems.fold(0, (sum, item) => sum + item.total);
  }

  // Calculate grand total
  double getGrandTotal() {
    double subTotal = getSubTotal();
    if (includeGST) {
      return subTotal + (subTotal * 0.18);
    }
    return subTotal;
  }

  // Update customer balance after bill
  Future<void> updateCustomerBalance(
    String customerName,
    double billTotal,
    String billDate,
  ) async {
    Customer? existingCustomer = customers.firstWhere(
      (c) => c.name.toLowerCase() == customerName.toLowerCase(),
      orElse: () => Customer(
        id: DateTime.now().millisecondsSinceEpoch,
        name: customerName,
        balance: 0,
      ),
    );

    if (!customers.contains(existingCustomer)) {
      customers.add(existingCustomer);
    }

    existingCustomer.balance += billTotal;
    existingCustomer.lastBillDate = billDate;

    for (var item in currentBillItems) {
      existingCustomer.history.insert(
        0,
        CustomerAction(
          type: 'bill',
          date: billDate,
          desc: '${item.desc} (${item.w}"x${item.h}") x${item.qty}',
          amount: item.total,
        ),
      );
    }

    await saveCustomers();
  }

  // Helper to convert number to words
  String numberToWords(int number) {
    if (number == 0) return 'Zero';
    List<String> units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    List<String> tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String convert(int n) {
      if (n < 20) return units[n];
      if (n < 100)
        return tens[n ~/ 10] + (n % 10 != 0 ? ' ' + units[n % 10] : '');
      if (n < 1000)
        return units[n ~/ 100] +
            ' Hundred' +
            (n % 100 != 0 ? ' and ' + convert(n % 100) : '');
      if (n < 100000)
        return convert(n ~/ 1000) +
            ' Thousand' +
            (n % 1000 != 0 ? ' ' + convert(n % 1000) : '');
      if (n < 10000000)
        return convert(n ~/ 100000) +
            ' Lakh' +
            (n % 100000 != 0 ? ' ' + convert(n % 100000) : '');
      return '${convert(n ~/ 10000000)} Crore${n % 10000000 != 0 ? ' ' + convert(n % 10000000) : ''}';
    }

    return convert(number);
  }

  // Generate PDF and save
  Future<void> generatePDF() async {
    if (currentBillItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No items in bill')));
      return;
    }

    String customerName = custNameController.text.trim();
    if (customerName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Customer name missing')));
      return;
    }

    try {
      String invDate = invDateController.text;
      double totalSum = getGrandTotal();

      // Update customer balance
      await updateCustomerBalance(customerName, totalSum, invDate);

      // Load font from bundled assets — guarantees ₹ glyph is present
      final regularFontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final boldFontData = await rootBundle.load(
        'assets/fonts/NotoSans-Bold.ttf',
      );
      final regularFont = pw.Font.ttf(regularFontData);
      final boldFont = pw.Font.ttf(boldFontData);

      // Load company logo safely (won't crash if file has issues)
      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/logo.png');
        final bytes = logoBytes.buffer.asUint8List();
        // Only use if file is a real image (> 100 bytes)
        if (bytes.length > 100) {
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (_) {
        // Logo not found or invalid — continue without it
        logoImage = null;
      }

      // Create PDF with theme
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          footer: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Sri Gayathri Digital — where art meets perfection',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Thank you for your business! • Payment due within 15 days',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            );
          },
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Company Logo (only if loaded successfully)
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 80,
                          height: 90,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      // Company Name & Address
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SRI GAYATHRI DIGITAL',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Godown No :6, Under Moosapet Flyover Pillar,',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            'Bharath Nagar Flyover Sanathnagar,',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            'Sanath Nagar, Hyderabad-500018, Telangana',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            '+91 8106116622 | suryakameswararao@gmail.com',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Text('Date: $invDate'),
                      pw.Text('Invoice: SGD-$invoiceCounter'),
                    ],
                  ),
                ],
              ),
            ),
            pw.Divider(height: 20, thickness: 2),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'Bill To: $customerName',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'Item Description',
                'Dimensions',
                'Type',
                'Qty',
                'Amount (₹)',
              ],
              data: currentBillItems
                  .map(
                    (item) => [
                      '${item.desc}\n${item.itemType == 'both' ? 'Glass: ${item.thickness} | ${item.rw}"×${item.rh}"' : 'Print Only'}${item.holes > 0 ? '\nHoles: ${item.holes}' : ''}${item.hasPolish ? '\nPolish Applied' : ''}${item.designCost > 0 ? '\nDesign Cost: ₹${item.designCost.toStringAsFixed(2)}' : ''}',
                      '${item.w}${item.dimUnit == 'mm' ? 'mm' : '"'} × ${item.h}${item.dimUnit == 'mm' ? 'mm' : '"'}',
                      item.itemType == 'both' ? 'Glass + Print' : 'Print Only',
                      item.qty.toString(),
                      '₹ ${item.total.toStringAsFixed(2)}',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
              cellStyle: pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 12)),
                        pw.Text(
                          '₹ ${getSubTotal().toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    if (includeGST) ...[
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'CGST (9%):',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            '₹ ${(getSubTotal() * 0.09).toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'SGST (9%):',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            '₹ ${(getSubTotal() * 0.09).toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'GRAND TOTAL',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '₹ ${totalSum.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Amount in words: Rupees ${numberToWords(totalSum.toInt())} Only',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontStyle: pw.FontStyle.italic,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            // Footer handled by MultiPage footer property.
          ],
        ),
      );

      // Show loading and print
      final pdfBytes = await pdf.save();
      final fileName = 'SGD_Invoice_${customerName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );

      // Save to local storage
      await savePdfToFile(pdfBytes, fileName, customerName, 'Invoice');

      // Append bill details to Excel
      await appendBillToExcel(
        customerName,
        'SGD-$invoiceCounter',
        invDate,
        currentBillItems,
        totalSum,
      );

      // Increment invoice counter
      setState(() {
        invoiceCounter++;
      });
      await saveInvoiceCounter();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Invoice generated! Balance updated for $customerName',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  // Add new customer
  Future<void> addNewCustomer() async {
    String name = newCustNameController.text.trim();
    double? balance = double.tryParse(newCustBalanceController.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Customer name required')));
      return;
    }

    if (balance == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Valid balance required')));
      return;
    }

    if (customers.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Customer already exists!')));
      return;
    }

    setState(() {
      customers.add(
        Customer(
          id: DateTime.now().millisecondsSinceEpoch,
          name: name,
          balance: balance,
          lastBillDate: null,
        ),
      );
      newCustNameController.clear();
      newCustBalanceController.text = '0';
    });

    await saveCustomers();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ Customer $name added with balance ₹${balance.toStringAsFixed(2)}',
        ),
      ),
    );
  }

  // Record payment
  Future<void> recordPayment() async {
    if (selectedPaymentCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a customer')));
      return;
    }

    double? payment = double.tryParse(paymentAmountController.text);
    if (payment == null || payment <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid payment amount')),
      );
      return;
    }

    setState(() {
      selectedPaymentCustomer!.balance =
          (selectedPaymentCustomer!.balance - payment).clamp(
            0.0,
            double.infinity,
          );
      selectedPaymentCustomer!.history.insert(
        0,
        CustomerAction(
          type: 'payment',
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          desc: 'Payment Received',
          amount: payment,
        ),
      );
      paymentAmountController.clear();
    });

    await saveCustomers();

    // Generate PDF for this payment
    await generatePaymentReceiptPDF(selectedPaymentCustomer!, payment);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '💰 Received ₹${payment.toStringAsFixed(2)}. New balance: ₹${selectedPaymentCustomer!.balance.toStringAsFixed(2)}',
          ),
        ),
      );
    }
  }

  // Generate Payment PDF
  Future<void> generatePaymentReceiptPDF(
    Customer customer,
    double paymentAmount,
  ) async {
    try {
      final regularFontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final boldFontData = await rootBundle.load(
        'assets/fonts/NotoSans-Bold.ttf',
      );
      final regularFont = pw.Font.ttf(regularFontData);
      final boldFont = pw.Font.ttf(boldFontData);

      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/logo.png');
        final bytes = logoBytes.buffer.asUint8List();
        if (bytes.length > 100) logoImage = pw.MemoryImage(bytes);
      } catch (_) {
        logoImage = null;
      }

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
      );

      final dateNow = DateFormat('yyyy-MM-dd').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          footer: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Sri Gayathri Digital — where art meets perfection',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Thank you for your business! • Payment Received',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            );
          },
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 60,
                          height: 60,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SRI GAYATHRI DIGITAL',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Godown No :6, Under Moosapet Flyover Pillar,',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            'Bharath Nagar Flyover Sanathnagar,',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            'Sanath Nagar, Hyderabad-500018, Telangana',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            '+91 8106116622 | suryakameswararao@gmail.com',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PAYMENT RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Text('Date: $dateNow'),
                      pw.Text(
                        'Receipt: PR-${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 6)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Divider(height: 20, thickness: 2),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Received From: ${customer.name}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Container(
                width: 300,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'PAYMENT AMOUNT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      '₹ ${paymentAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Remaining Balance:',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          '₹ ${customer.balance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Text(
                'Amount in words: Rupees ${numberToWords(paymentAmount.toInt())} Only',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontStyle: pw.FontStyle.italic,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'SGD_Receipt_${customer.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );

      // Save to local storage
      await savePdfToFile(pdfBytes, fileName, customer.name, 'Receipt');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Clear full balance
  Future<void> clearFullBalance() async {
    if (selectedPaymentCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a customer')));
      return;
    }

    double previousBalance = selectedPaymentCustomer!.balance;
    setState(() {
      selectedPaymentCustomer!.balance = 0;
      selectedPaymentCustomer!.history.insert(
        0,
        CustomerAction(
          type: 'payment',
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          desc: 'Balance Cleared',
          amount: previousBalance,
        ),
      );
    });

    await saveCustomers();

    // Generate PDF for this payment
    if (previousBalance > 0) {
      await generatePaymentReceiptPDF(
        selectedPaymentCustomer!,
        previousBalance,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Balance cleared for ${selectedPaymentCustomer!.name}'),
        ),
      );
    }
  }

  // Reset all customers
  Future<void> resetAllCustomers() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Warning'),
        content: const Text(
          'This will delete ALL customer records and balances permanently. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        customers.clear();
        selectedPaymentCustomer = null;
      });
      await saveCustomers();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All customers removed')));
    }
  }

  // Delete customer
  Future<void> deleteCustomer(int id) async {
    setState(() {
      customers.removeWhere((c) => c.id == id);
      if (selectedPaymentCustomer?.id == id) {
        selectedPaymentCustomer = null;
      }
    });
    await saveCustomers();
  }

  // Export/Append bill to Excel
  Future<void> appendBillToExcel(
    String customerName,
    String invoiceNo,
    String date,
    List<BillItem> items,
    double grandTotal,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/SriGayathri_Bills.xlsx';
      final file = File(path);

      Excel excel;
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        excel = Excel.decodeBytes(bytes);
      } else {
        excel = Excel.createExcel();
        // Rename default sheet
        excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Bills');
        final sheet = excel['Bills'];
        sheet.appendRow([
          TextCellValue('Invoice No'),
          TextCellValue('Date'),
          TextCellValue('Customer Name'),
          TextCellValue('Item Description'),
          TextCellValue('Item Type'),
          TextCellValue('Dimensions'),
          TextCellValue('Qty'),
          TextCellValue('Holes'),
          TextCellValue('Polish Applied'),
          TextCellValue('Glass Cost (Rs)'),
          TextCellValue('Print Cost (Rs)'),
          TextCellValue('Design Cost (Rs)'),
          TextCellValue('Item Total (Rs)'),
          TextCellValue('Grand Total (Rs)'),
        ]);
      }

      final sheet = excel['Bills'];

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final dimStr =
            '${item.w}${item.dimUnit == 'mm' ? 'mm' : '"'} x ${item.h}${item.dimUnit == 'mm' ? 'mm' : '"'}';

        sheet.appendRow([
          TextCellValue(invoiceNo),
          TextCellValue(date),
          TextCellValue(customerName),
          TextCellValue(item.desc),
          TextCellValue(item.itemType == 'both' ? 'Glass+Print' : 'Print Only'),
          TextCellValue(dimStr),
          IntCellValue(item.qty),
          IntCellValue(item.holes),
          TextCellValue(item.hasPolish ? 'Yes' : 'No'),
          DoubleCellValue(item.glassCost),
          DoubleCellValue(item.printCost),
          DoubleCellValue(item.designCost),
          DoubleCellValue(item.total),
          if (i == 0) DoubleCellValue(grandTotal) else TextCellValue(''),
        ]);
      }

      file.writeAsBytesSync(excel.encode()!);
    } catch (e) {
      debugPrint('Error writing to Excel: $e');
    }
  }

  // Share generated Excel
  Future<void> shareExcelFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/SriGayathri_Bills.xlsx';
      final file = File(path);

      if (file.existsSync()) {
        await Share.shareXFiles([
          XFile(path),
        ], text: 'Sri Gayathri Digital Bills Excel Report');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No generated bills found yet. Please generate a bill first.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing file: $e')));
      }
    }
  }

  // Preview generated Excel
  Future<void> previewExcelFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/SriGayathri_Bills.xlsx';
      final file = File(path);

      if (file.existsSync()) {
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No generated bills found yet.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error previewing file: $e')),
        );
      }
    }
  }

  // Clear current bill
  void clearBill() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Bill'),
        content: const Text('Clear all bill items and reset?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                currentBillItems.clear();
                custNameController.clear();
                itemDescController.clear();
                widthController.clear();
                heightController.clear();
                qtyController.text = '1';
                holesController.text = '0';
                selectedItemType = 'both';
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Top safe area height (status bar)
    final topPad = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // ── App Header ──────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
                    : [Colors.blue.shade50, Colors.blue.shade100],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image,
                          color: Color(0xFFd4af37),
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sri Gayathri Digital',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          'precision glass & digital prints',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1d6f96).withOpacity(0.3)
                        : Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1d6f96)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt,
                        size: 16,
                        color: isDark ? Colors.blue.shade300 : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Billing Pro',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.blue.shade300 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Bar ──────────────────────────────────────────────────
          Container(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
              unselectedLabelColor: Colors.grey,
              indicatorColor: isDark
                  ? Colors.blue.shade300
                  : Colors.blue.shade800,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.receipt, size: 20), text: 'New Bill'),
                Tab(icon: Icon(Icons.people, size: 20), text: 'Customers'),
                Tab(
                  icon: Icon(Icons.photo_library_rounded, size: 20),
                  text: 'Orders',
                ),
                Tab(
                  icon: Icon(Icons.folder_shared, size: 20),
                  text: 'Saved Bills',
                ),
                Tab(icon: Icon(Icons.settings, size: 20), text: 'Settings'),
              ],
            ),
          ),

          // ── Tab Content (fills all remaining space) ──────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBillingTab(),
                _buildCustomersTab(),
                const OrdersPage(),
                _buildSavedBillsTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Customer and Date Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: custNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Read-only Invoice Number Display
                  TextField(
                    controller: TextEditingController(
                      text: 'SGD-$invoiceCounter',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Invoice Number',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: invDateController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          invDateController.text = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Item Entry Card with Type Selection
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Item Type Selection
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Glass + Print',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: 'both',
                            groupValue: selectedItemType,
                            onChanged: (value) {
                              setState(() {
                                selectedItemType = value!;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Print Only',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: 'print_only',
                            groupValue: selectedItemType,
                            onChanged: (value) {
                              setState(() {
                                selectedItemType = value!;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: itemDescController,
                    decoration: const InputDecoration(
                      labelText: 'Item Description',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Glass Thickness Selection
                  if (selectedItemType == 'both') ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Glass Thickness:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: thicknessRates.keys.map((thickness) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                '$thickness (₹${thicknessRates[thickness]?.toInt()})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selectedThickness == thickness
                                      ? Colors.white
                                      : null,
                                ),
                              ),
                              selected: selectedThickness == thickness,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    selectedThickness = thickness;
                                  });
                                }
                              },
                              selectedColor: Colors.blue.shade700,
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      const Text(
                        'Dimension Unit:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Radio<String>(
                        value: 'in',
                        groupValue: inputUnit,
                        onChanged: (val) {
                          setState(() {
                            inputUnit = val!;
                          });
                        },
                      ),
                      const Text('Inches'),
                      Radio<String>(
                        value: 'mm',
                        groupValue: inputUnit,
                        onChanged: (val) {
                          setState(() {
                            inputUnit = val!;
                          });
                        },
                      ),
                      const Text('mm'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Width (${inputUnit})',
                            prefixIcon: const Icon(Icons.arrow_left),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Height (${inputUnit})',
                            prefixIcon: const Icon(Icons.arrow_upward),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon: Icon(Icons.numbers),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (selectedItemType == 'both') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: holesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Holes (Glass)',
                              prefixIcon: Icon(Icons.radio_button_checked),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (selectedItemType == 'both') ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Add Glass Polish'),
                      subtitle: const Text(
                        'Calculated based on glass perimeter',
                      ),
                      value: applyPolish,
                      onChanged: (val) {
                        setState(() {
                          applyPolish = val ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: designCostController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Design Cost (₹)',
                      prefixIcon: Icon(Icons.design_services),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: addItemToBill,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('ADD ITEM'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bill Items Table
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Bill Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (currentBillItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      '✨ Add beautiful items to generate invoice ✨',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentBillItems.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      var item = currentBillItems[index];
                      return ListTile(
                        title: Text(item.desc),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Size: ${item.w}${item.dimUnit == 'mm' ? 'mm' : '"'}×${item.h}${item.dimUnit == 'mm' ? 'mm' : '"'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (item.itemType == 'both')
                              Text(
                                'Glass: ₹${item.glassCost.toStringAsFixed(2)} | Print: ₹${item.printCost.toStringAsFixed(2)}${item.holes > 0 ? '\nHoles (${item.holes}): ₹${item.holeCost.toStringAsFixed(2)}' : ''}${item.hasPolish ? '\nPolish: ₹${item.polishCost.toStringAsFixed(2)}' : ''}${item.designCost > 0 ? '\nDesign Cost: ₹${item.designCost.toStringAsFixed(2)}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              )
                            else
                              Text(
                                'Print Only: ₹${item.printCost.toStringAsFixed(2)}${item.designCost > 0 ? '\nDesign Cost: ₹${item.designCost.toStringAsFixed(2)}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: item.itemType == 'both'
                                    ? (isDark
                                          ? Colors.blue.shade900
                                          : Colors.blue.shade100)
                                    : (isDark
                                          ? Colors.green.shade900
                                          : Colors.green.shade100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.itemType == 'both' ? 'G+P' : 'Print',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.itemType == 'both'
                                      ? (isDark
                                            ? Colors.blue.shade200
                                            : Colors.blue.shade800)
                                      : (isDark
                                            ? Colors.green.shade200
                                            : Colors.green.shade800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${item.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => removeBillItem(index),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (includeGST) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Subtotal: ',
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              '₹ ${getSubTotal().toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'CGST (9%): ',
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              '₹ ${(getSubTotal() * 0.09).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'SGST (9%): ',
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              '₹ ${(getSubTotal() * 0.09).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'GRAND TOTAL: ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹ ${getGrandTotal().toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // GST Toggle Button
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Include GST (9% CGST + 9% SGST)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              value: includeGST,
              activeColor: Colors.blue.shade700,
              onChanged: (bool value) {
                setState(() {
                  includeGST = value;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: generatePDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate Bill'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: clearBill,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Bill'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Info Card with current rates
          Card(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Glass: ₹${settings.glassRate.toStringAsFixed(2)}/sqft',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Print: ₹${settings.printRate.toStringAsFixed(2)}/sqft',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const Text(
                        'Rounding: 3 inches',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (selectedItemType == 'print_only')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.green.shade900
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Print Only Mode - No glass cost applied',
                            style: TextStyle(fontSize: 10),
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
  }

  Widget _buildCustomersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add New Customer Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Customer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCustNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      prefixIcon: Icon(Icons.person_add),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCustBalanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Opening Balance (₹)',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: addNewCustomer,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Customer'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: resetAllCustomers,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Reset All'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Customer List
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Ledger',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (customers.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'No customers added yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: customers.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        var customer = customers[index];
                        return ExpansionTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(
                            customer.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Balance: ₹${customer.balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: customer.balance > 0
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                              if (customer.lastBillDate != null)
                                Text(
                                  'Last Activity: ${customer.lastBillDate}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deleteCustomer(customer.id),
                          ),
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              setState(() {
                                selectedPaymentCustomer = customer;
                              });
                            }
                          },
                          children: [
                            if (customer.history.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No transaction history yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: customer.history.length,
                                separatorBuilder: (ctx, hInd) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, hIndex) {
                                  var action = customer.history[hIndex];
                                  bool isPayment = action.type == 'payment';
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      isPayment
                                          ? Icons.account_balance_wallet
                                          : Icons.receipt,
                                      color: isPayment
                                          ? Colors.green
                                          : Colors.blue,
                                      size: 20,
                                    ),
                                    title: Text(
                                      action.desc,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      action.date,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Text(
                                      '${isPayment ? '-' : '+'} ₹${action.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: isPayment
                                            ? Colors.green
                                            : Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Payment Adjustment Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Adjust / Clear Balance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Customer>(
                    value: selectedPaymentCustomer,
                    decoration: const InputDecoration(
                      labelText: 'Select Customer',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    items: customers.map((customer) {
                      return DropdownMenuItem(
                        value: customer,
                        child: Text(
                          '${customer.name} (₹${customer.balance.toStringAsFixed(2)})',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPaymentCustomer = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paymentAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount (₹)',
                      prefixIcon: Icon(Icons.payment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: recordPayment,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Record Payment'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: clearFullBalance,
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('Clear Balance'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Theme Settings
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose your preferred theme mode',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Dark Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isDark,
                        onChanged: (val) {
                          MyApp.of(
                            context,
                          ).changeTheme(val ? ThemeMode.dark : ThemeMode.light);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Rate Configuration
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rate Configuration',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Update pricing rates for glass and print services',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 24),

                  // Glass Rate Setting
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.construction,
                              size: 20,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Glass Rate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Rate per square foot for glass cutting and framing',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: glassRateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                  ),
                                  hintText: 'Enter glass rate per sqft',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: updateGlassRate,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                backgroundColor: Colors.blue.shade700,
                              ),
                              child: const Text('Update'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current rate: ₹${settings.glassRate.toStringAsFixed(2)}/sqft',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Print Rate Setting
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.print, size: 20, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Print Rate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Rate per square foot for digital printing services',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: printRateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                  ),
                                  hintText: 'Enter print rate per sqft',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: updatePrintRate,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                backgroundColor: Colors.green.shade700,
                              ),
                              child: const Text('Update'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current rate: ₹${settings.printRate.toStringAsFixed(2)}/sqft',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Hole Rate Setting
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.radio_button_checked,
                              size: 20,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Hole Rate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Rate per glass hole',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: holeRateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                  ),
                                  hintText: 'Enter hole rate',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: updateHoleRate,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                backgroundColor: Colors.orange.shade700,
                              ),
                              child: const Text('Update'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current rate: ₹${settings.holeRate.toStringAsFixed(2)}/hole',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Polish Rate Setting
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.brush, size: 20, color: Colors.purple),
                            SizedBox(width: 8),
                            Text(
                              'Polish Rate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Rate per foot of glass perimeter',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: polishRateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                  ),
                                  hintText: 'Enter polish rate',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: updatePolishRate,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                backgroundColor: Colors.purple.shade700,
                              ),
                              child: const Text('Update'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current rate: ₹${settings.polishRate.toStringAsFixed(2)}/foot',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Important Notes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Glass dimensions are rounded up to the nearest 3 inches\n'
                          '• Print cost is calculated based on actual dimensions\n'
                          '• Updated rates will apply to all new items added to bills\n'
                          '• Existing items in current bill will not be affected',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reset to Default Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Reset to Default Rates?'),
                            content: const Text(
                              'This will reset glass rate to ₹65/sqft and print rate to ₹180/sqft. Continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    settings.glassRate = 65.0;
                                    settings.printRate = 180.0;
                                    glassRateController.text = '65';
                                    printRateController.text = '180';
                                  });
                                  saveSettings();
                                  Navigator.pop(context);
                                },
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.restore),
                      label: const Text('Reset to Default Rates'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Excel Actions
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: previewExcelFile,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1c2a3d) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.blue.shade700 : Colors.blue.shade300,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_red_eye, color: isDark ? Colors.blue.shade200 : Colors.blue.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Preview',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: shareExcelFile,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade500, Colors.green.shade700],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.share, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Share Excel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSavedBillsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (savedPdfs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No saved PDFs yet',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a bill or receipt to see it here',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: savedPdfs.length,
      itemBuilder: (context, index) {
        final pdf = savedPdfs[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: pdf.type == 'Invoice'
                  ? Colors.blue.shade100
                  : Colors.green.shade100,
              child: Icon(
                pdf.type == 'Invoice' ? Icons.description : Icons.receipt_long,
                color: pdf.type == 'Invoice'
                    ? Colors.blue.shade800
                    : Colors.green.shade800,
              ),
            ),
            title: Text(
              pdf.customerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${pdf.type} • ${pdf.date}'),
                Text(
                  pdf.fileName,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.blue, size: 20),
                  onPressed: () => Share.shareXFiles([XFile(pdf.filePath)]),
                  tooltip: 'Share',
                ),
                IconButton(
                  icon:
                      const Icon(Icons.open_in_new, color: Colors.green, size: 20),
                  onPressed: () async {
                    final result = await OpenFilex.open(pdf.filePath);
                    if (result.type != ResultType.done && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open file: ${result.message}'),
                        ),
                      );
                    }
                  },
                  tooltip: 'Open',
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete PDF?'),
                        content: const Text(
                          'Are you sure you want to delete this saved PDF from your storage?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                try {
                                  final file = File(pdf.filePath);
                                  if (file.existsSync()) {
                                    file.deleteSync();
                                  }
                                } catch (e) {
                                  debugPrint('Error deleting file: $e');
                                }
                                savedPdfs.removeAt(index);
                              });
                              savePdfList();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('PDF deleted')),
                              );
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'Delete',
                ),
              ],
            ),
            onTap: () async {
              final result = await OpenFilex.open(pdf.filePath);
              if (result.type != ResultType.done && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open file: ${result.message}')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
