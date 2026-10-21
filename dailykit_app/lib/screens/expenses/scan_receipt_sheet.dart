import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../core/constants/app_colors.dart';
import '../../core/utils/receipt_scanner_parser.dart';
import '../../providers/expense_provider.dart';
import '../../models/expense_model.dart';

class ScanReceiptSheet extends StatefulWidget {
  const ScanReceiptSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ScanReceiptSheet(),
    );
  }

  @override
  State<ScanReceiptSheet> createState() => _ScanReceiptSheetState();
}

class _ScanReceiptSheetState extends State<ScanReceiptSheet> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isScanning = false;
  ScannedReceiptData? _scannedData;

  // Editable form controllers
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  int? _selectedCategoryId;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _isScanning = true;
      });

      // 1. Process image using on-device Google ML Kit Text Recognition
      final inputImage = InputImage.fromFilePath(picked.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      // 2. Parse receipt fields
      final parsed = ReceiptScannerParser.parse(recognizedText.text);

      if (mounted) {
        final expProvider = context.read<ExpenseProvider>();

        // Match category
        int catId = 1;
        final match = expProvider.categories.firstWhere(
          (c) => c.name.toLowerCase() == parsed.categoryName.toLowerCase(),
          orElse: () => expProvider.categories.isNotEmpty
              ? expProvider.categories.first
              : ExpenseCategory(id: 1, name: 'Other', icon: 'category', color: '#2196F3', isDefault: true),
        );
        catId = match.id;

        setState(() {
          _isScanning = false;
          _scannedData = parsed;
          _merchantController.text = parsed.merchantName;
          _amountController.text = parsed.amount > 0 ? parsed.amount.toStringAsFixed(0) : '';
          _noteController.text = 'Scanned: ${parsed.merchantName}';
          _selectedCategoryId = catId;
          _selectedDate = DateTime.tryParse(parsed.date) ?? DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanning failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmAndSave() async {
    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: AppColors.error),
      );
      return;
    }

    final provider = context.read<ExpenseProvider>();
    final catId = _selectedCategoryId ??
        (provider.categories.isNotEmpty ? provider.categories.first.id : 1);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final success = await provider.addExpense(
      categoryId: catId,
      amount: amt,
      note: _merchantController.text.trim().isNotEmpty
          ? '${_merchantController.text.trim()} (${_noteController.text.trim()})'
          : _noteController.text.trim(),
      expenseDate: dateStr,
    );

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('₹${amt.toStringAsFixed(0)} expense logged from ${_merchantController.text}!'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expProvider = context.watch<ExpenseProvider>();

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: Colors.purple, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'AI Receipt Scanner',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Source Selector Buttons (Camera & Gallery)
            if (_imageFile == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.purple.shade50.withAlpha(100),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.withAlpha(50)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.camera_enhance_rounded, size: 48, color: Colors.purple),
                    const SizedBox(height: 12),
                    const Text(
                      'Bill ya Receipt ki photo kheencho',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dukaan ka naam, Total Amount aur Category AI khud nikal lega!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _pickAndScan(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purple,
                              side: const BorderSide(color: Colors.purple),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _pickAndScan(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Scanning Loader
            if (_isScanning) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: const [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 16),
                    Text(
                      'AI Receipt Scan Kar Raha Hai...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Extracting Store Name, Amount & Category',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],

            // Scanned Result & Edit Form
            if (_imageFile != null && !_isScanning && _scannedData != null) ...[
              // Image Thumbnail & Re-scan bar
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_imageFile!, width: 50, height: 50, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ AI Auto-Detected from Receipt',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple),
                        ),
                        Text(
                          'Verify or edit details before saving',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _imageFile = null),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Re-scan'),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Store / Merchant Name
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Dukaan / Merchant Name',
                  prefixIcon: Icon(Icons.storefront_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Total Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                decoration: const InputDecoration(
                  labelText: 'Total Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: Colors.purple),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Category Selector Chips
              const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: expProvider.categories.map((cat) {
                    final isSelected = _selectedCategoryId == cat.id;
                    final catColor = AppColors.fromHex(cat.color);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        avatar: Icon(
                          ExpenseCategory.getIconData(cat.icon),
                          size: 16,
                          color: isSelected ? Colors.white : catColor,
                        ),
                        label: Text(cat.name),
                        selectedColor: catColor,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Note
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Items (Optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),

              // Confirm Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _confirmAndSave,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Confirm & Save Expense',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

