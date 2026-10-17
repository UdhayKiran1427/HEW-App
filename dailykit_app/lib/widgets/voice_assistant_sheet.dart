import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/hinglish_voice_parser.dart';
import '../providers/expense_provider.dart';
import '../providers/item_provider.dart';
import '../providers/renewal_provider.dart';

class VoiceAssistantSheet extends StatefulWidget {
  final VoiceActionType? preferredType;

  const VoiceAssistantSheet({
    super.key,
    this.preferredType,
  });

  static Future<void> show(BuildContext context, {VoiceActionType? preferredType}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceAssistantSheet(preferredType: preferredType),
    );
  }

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _listeningStatus = 'Tap microphone to speak or type below';

  final TextEditingController _inputController = TextEditingController();
  ParsedVoiceAction? _parsedAction;

  // Selected action type if user manually overrides
  late VoiceActionType _activeType;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _activeType = widget.preferredType ?? VoiceActionType.expense;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.95,
      upperBound: 1.15,
    )..repeat(reverse: true);

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              if (status == 'listening') {
                _isListening = true;
                _listeningStatus = 'Listening... Speak in Hindi, English or Hinglish';
              } else if (status == 'notListening' || status == 'done') {
                _isListening = false;
                _listeningStatus = 'Tap mic to speak again or edit below';
              }
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _listeningStatus = 'Mic error: ${err.errorMsg}. You can also type!';
            });
          }
        },
      );
      if (mounted) {
        setState(() {});
        // Auto-start listening on open for seamless 1-tap UX
        if (_speechEnabled) {
          _startListening();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _speechEnabled = false;
          _listeningStatus = 'Type your command in Hindi / English below';
        });
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _inputController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _initSpeech();
      return;
    }

    setState(() {
      _isListening = true;
      _listeningStatus = 'Listening... Bolna shuru kijiye';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _inputController.text = result.recognizedWords;
            _parseInput(result.recognizedWords);
          });
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
        ),
      );
    } catch (_) {
      setState(() => _isListening = false);
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _parseInput(String text) {
    if (text.trim().isEmpty) {
      _parsedAction = null;
      return;
    }
    final parsed = HinglishVoiceParser.parse(text);
    if (widget.preferredType != null && parsed.type == VoiceActionType.unknown) {
      parsed.type = widget.preferredType!;
    }
    _parsedAction = parsed;
    _activeType = parsed.type;
  }

  Future<void> _confirmAndSave() async {
    if (_parsedAction == null || _inputController.text.trim().isEmpty) return;

    final parsed = _parsedAction!;
    bool success = false;
    String successMsg = '';

    if (_activeType == VoiceActionType.expense) {
      final expProvider = context.read<ExpenseProvider>();
      final amount = parsed.expenseAmount ?? 0.0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please specify a valid expense amount')),
        );
        return;
      }

      // Match category
      int categoryId = 1; // Default Food
      if (expProvider.categories.isNotEmpty) {
        final catMatch = expProvider.categories.firstWhere(
          (c) => c.name.toLowerCase() == (parsed.expenseCategoryName ?? '').toLowerCase(),
          orElse: () => expProvider.categories.first,
        );
        categoryId = catMatch.id;
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      success = await expProvider.addExpense(
        amount: amount,
        categoryId: categoryId,
        expenseDate: todayStr,
        note: parsed.expenseNote,
      );
      successMsg = 'Expense of ₹${amount.toStringAsFixed(0)} logged!';
    } else if (_activeType == VoiceActionType.whereKept) {
      final itemProvider = context.read<ItemProvider>();
      final name = parsed.itemName ?? 'Belonging';
      final location = parsed.itemLocation ?? 'Storage';

      success = await itemProvider.addItem(
        name: name,
        currentLocation: location,
        inUseBy: parsed.inUseBy,
        tags: 'voice',
      );
      successMsg = '"$name" saved in "$location"!';
    } else if (_activeType == VoiceActionType.renewal) {
      final renProvider = context.read<RenewalProvider>();
      final title = parsed.renewalTitle ?? 'Renewal';
      final category = parsed.renewalCategory ?? 'Subscription';
      final expiryDate = parsed.renewalExpiryDate ??
          DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));

      success = await renProvider.addRenewal(
        title: title,
        category: category,
        expiryDate: expiryDate,
        amount: parsed.renewalAmount,
        notes: parsed.renewalNotes,
        remindBeforeDays: '5,3,1',
      );
      successMsg = '"$title" added with 5, 3 & 1 day alerts!';
    }

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMsg)),
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
            // Handle Bar & Header
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Voice & Quick Add',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Pulsating Mic Button & Status
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isListening ? _pulseController.value : 1.0,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isListening
                                    ? [Colors.redAccent, Colors.deepOrange]
                                    : [AppColors.primary, const Color(0xFF7C4DFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? Colors.redAccent : AppColors.primary).withAlpha(100),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _listeningStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _isListening ? Colors.redAccent : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Type in Hinglish / English Text Field ("typing also remain as it is")
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: 'e.g. "Chai 20 rupaye", "Passport drawer mein rakha", "Jio recharge 299"',
                prefixIcon: const Icon(Icons.keyboard_outlined, size: 20),
                suffixIcon: _inputController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _inputController.clear();
                          setState(() => _parsedAction = null);
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _parseInput(val);
                });
              },
            ),
            const SizedBox(height: 14),

            // Target Selector Tabs (Expense / Where Kept / Renewal)
            Row(
              children: [
                _buildTypeChip(VoiceActionType.expense, '💰 Expense', AppColors.primary),
                const SizedBox(width: 8),
                _buildTypeChip(VoiceActionType.whereKept, '📦 Where Kept', const Color(0xFF009688)),
                const SizedBox(width: 8),
                _buildTypeChip(VoiceActionType.renewal, '⏰ Renewal', Colors.deepOrange),
              ],
            ),
            const SizedBox(height: 16),

            // Smart Preview Card
            if (_parsedAction != null && _inputController.text.trim().isNotEmpty)
              _buildParsedPreview(isDark),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _parsedAction != null ? _confirmAndSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Confirm & Save',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(VoiceActionType type, String label, Color color) {
    final isSelected = _activeType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeType = type;
            if (_parsedAction != null) {
              _parsedAction!.type = type;
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(35) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade400,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? color : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParsedPreview(bool isDark) {
    final p = _parsedAction!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.blue.shade50.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '⚡ Detected Details (Auto-Parsed):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _activeType.name.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          if (_activeType == VoiceActionType.expense) ...[
            _buildDetailRow('Amount', '₹${(p.expenseAmount ?? 0).toStringAsFixed(0)}', isBold: true),
            _buildDetailRow('Category', p.expenseCategoryName ?? 'Other'),
            _buildDetailRow('Note', p.expenseNote ?? 'Expense'),
          ] else if (_activeType == VoiceActionType.whereKept) ...[
            _buildDetailRow('Item Name', p.itemName ?? 'Item', isBold: true),
            _buildDetailRow('Location', p.itemLocation ?? 'Storage'),
            if (p.inUseBy != null) _buildDetailRow('Lent To', p.inUseBy!),
          ] else if (_activeType == VoiceActionType.renewal) ...[
            _buildDetailRow('Title', p.renewalTitle ?? 'Renewal', isBold: true),
            _buildDetailRow('Category', p.renewalCategory ?? 'Subscription'),
            _buildDetailRow('Expiry Date', p.renewalExpiryDate ?? 'Next Month'),
            if (p.renewalAmount != null) _buildDetailRow('Amount', '₹${p.renewalAmount!.toStringAsFixed(0)}'),
            _buildDetailRow('Alerts', '5, 3 & 1 days before expiry'),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

