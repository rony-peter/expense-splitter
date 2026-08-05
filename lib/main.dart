import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'models/expense_models.dart';
import 'services/ai_service.dart';
import 'services/export_service.dart';
import 'services/storage_service.dart';
import 'widgets/reusable_components.dart';
import 'widgets/footer.dart';
import 'pages/guide_page.dart';
import 'pages/currency_converter_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ExpenseSplitterApp());
}

class ExpenseSplitterApp extends StatelessWidget {
  const ExpenseSplitterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.secondaryBg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

    return MaterialApp(
      title: 'Expense Splitter',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.dmSansTextTheme(baseTheme.textTheme),
      ),
      home: const ExpenseHomeScreen(),
    );
  }
}

class CurrencyOption {
  final String code;
  final String symbol;
  final String name;

  const CurrencyOption(
      {required this.code, required this.symbol, required this.name});
}

class ExpenseHomeScreen extends StatefulWidget {
  const ExpenseHomeScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends State<ExpenseHomeScreen> {
  final List<FamilyUnit> _units = [];
  final List<ExpenseEntry> _expenses = [];

  final List<CurrencyOption> _currencies = const [
    CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    CurrencyOption(code: 'USD', symbol: '\$', name: 'US Dollar'),
    CurrencyOption(code: 'EUR', symbol: '€', name: 'Euro'),
    CurrencyOption(code: 'GBP', symbol: '£', name: 'British Pound'),
    CurrencyOption(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar'),
    CurrencyOption(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
    CurrencyOption(code: 'AED', symbol: 'AED ', name: 'UAE Dirham'),
    CurrencyOption(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
    CurrencyOption(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  ];

  late CurrencyOption _selectedCurrency = _currencies[0];

  final GlobalKey<FormState> _unitFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _expenseFormKey = GlobalKey<FormState>();

  final TextEditingController _unitNameController = TextEditingController();
  final TextEditingController _membersController = TextEditingController();

  final TextEditingController _expenseTitleController = TextEditingController();
  final TextEditingController _expenseAmountController =
      TextEditingController();

  String? _latestAiSummary;
  bool _isGeneratingAi = false;
  bool _isDataSaved = false;
  String? _currentSessionId;

  @override
  void dispose() {
    _unitNameController.dispose();
    _membersController.dispose();
    _expenseTitleController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  void _markDataChanged() {
    if (_isDataSaved) {
      setState(() {
        _isDataSaved = false;
      });
    }
  }

  void _showTopSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isError ? AppColors.redAccent : AppColors.green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).size.height - 150,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _generateAiSummary(List<SettlementTransfer> settlements) async {
    setState(() => _isGeneratingAi = true);
    HapticFeedback.lightImpact();

    try {
      final summary = await AIService.summarizeBudget(
        units: _units,
        expenses: _expenses,
        settlements: settlements,
        currencySymbol: _selectedCurrency.symbol,
      );

      setState(() {
        _latestAiSummary = summary;
      });

      _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();
      final session = SavedSplitSession(
        id: _currentSessionId!,
        dateString: DateTime.now().toString().substring(0, 16),
        totalPool: _totalPool,
        units: List.from(_units),
        expenses: List.from(_expenses),
        settlements: settlements,
        aiSummary: _latestAiSummary,
      );
      await ExpenseStorageService.saveSession(session);

      setState(() {
        _isDataSaved = true;
      });

      _showTopSnackBar("AI Summary generated and session updated!",
          isError: false);
    } on SocketException catch (_) {
      _showTopSnackBar("No internet access. Please turn on the internet.");
    } on http.ClientException catch (_) {
      _showTopSnackBar("No internet access. Please turn on the internet.");
    } catch (e) {
      _showTopSnackBar("Failed to generate summary: ${e.toString()}");
    } finally {
      setState(() => _isGeneratingAi = false);
    }
  }

  void _saveUnit({String? editId}) {
    if (!(_unitFormKey.currentState?.validate() ?? false)) return;

    HapticFeedback.lightImpact();
    setState(() {
      if (editId != null) {
        int index = _units.indexWhere((u) => u.id == editId);
        if (index >= 0) {
          _units[index] = FamilyUnit(
            id: editId,
            name: _unitNameController.text.trim(),
            members: _membersController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          );
        }
      } else {
        _units.add(
          FamilyUnit(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: _unitNameController.text.trim(),
            members: _membersController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          ),
        );
      }
      _unitNameController.clear();
      _membersController.clear();
    });
    _markDataChanged();
    Navigator.pop(context);
  }

  void _saveExpense({
    String? editId,
    required Map<String, double> payerContributions,
    required List<String> participatingMembers,
    required StateSetter setStateModal,
  }) {
    if (!(_expenseFormKey.currentState?.validate() ?? false)) return;

    double totalAmount = double.tryParse(_expenseAmountController.text) ?? 0.0;

    List<ExpensePayerContribution> payersList = [];
    double totalPaid = 0.0;
    payerContributions.forEach((familyId, amt) {
      if (amt > 0) {
        payersList
            .add(ExpensePayerContribution(familyId: familyId, amountPaid: amt));
        totalPaid += amt;
      }
    });

    if (payersList.isEmpty) {
      _showTopSnackBar("Please specify at least one payer contribution.");
      return;
    }

    if ((totalPaid - totalAmount).abs() > 0.01) {
      _showTopSnackBar(
          "Sum of payer contributions ($totalPaid) must match total amount ($totalAmount).");
      return;
    }

    if (participatingMembers.isEmpty) {
      _showTopSnackBar("Select at least one member to split the expense with.");
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      if (editId != null) {
        int index = _expenses.indexWhere((e) => e.id == editId);
        if (index >= 0) {
          _expenses[index] = ExpenseEntry(
            id: editId,
            title: _expenseTitleController.text.trim(),
            payers: payersList,
            amount: totalAmount,
            participatingFamilyIds: _units.map((u) => u.id).toList(),
            participatingMemberNames: participatingMembers,
          );
        }
      } else {
        _expenses.add(
          ExpenseEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: _expenseTitleController.text.trim(),
            payers: payersList,
            amount: totalAmount,
            participatingFamilyIds: _units.map((u) => u.id).toList(),
            participatingMemberNames: participatingMembers,
          ),
        );
      }
      _expenseTitleController.clear();
      _expenseAmountController.clear();
    });
    _markDataChanged();
    Navigator.pop(context);
  }

  double _getUnitTotalPaid(String unitId) {
    double total = 0.0;
    for (var e in _expenses) {
      for (var p in e.payers) {
        if (p.familyId == unitId) {
          total += p.amountPaid;
        }
      }
    }
    return total;
  }

  List<SettlementTransfer> _calculateSettlements() {
    Map<String, double> netBalances = {};
    for (var u in _units) {
      netBalances[u.name] = 0.0;
    }

    for (var exp in _expenses) {
      for (var p in exp.payers) {
        final payerUnit = _units.firstWhere(
          (u) => u.id == p.familyId,
          orElse: () => FamilyUnit(id: '', name: 'Unknown', members: []),
        );
        if (payerUnit.name != 'Unknown') {
          netBalances[payerUnit.name] =
              (netBalances[payerUnit.name] ?? 0.0) + p.amountPaid;
        }
      }

      List<String> activeParticipants = exp.participatingMemberNames;
      if (activeParticipants.isEmpty) {
        for (var u in _units) {
          if (u.members.isEmpty) {
            activeParticipants.add(u.name);
          } else {
            activeParticipants.addAll(u.members);
          }
        }
      }

      if (activeParticipants.isNotEmpty) {
        double perHeadAmount = exp.amount / activeParticipants.length;
        for (var u in _units) {
          List<String> unitMemberKeys =
              u.members.isEmpty ? [u.name] : u.members;
          int participatingCountInUnit = unitMemberKeys
              .where((m) => activeParticipants.contains(m))
              .length;

          double unitLiability = perHeadAmount * participatingCountInUnit;
          netBalances[u.name] = (netBalances[u.name] ?? 0.0) - unitLiability;
        }
      }
    }

    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    netBalances.forEach((name, bal) {
      if (bal < -0.01) debtors.add(MapEntry(name, -bal));
      if (bal > 0.01) creditors.add(MapEntry(name, bal));
    });

    List<SettlementTransfer> transfers = [];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      var debtor = debtors[i];
      var creditor = creditors[j];
      double amount =
          debtor.value < creditor.value ? debtor.value : creditor.value;

      transfers.add(SettlementTransfer(
          from: debtor.key, to: creditor.key, amount: amount));

      debtors[i] = MapEntry(debtor.key, debtor.value - amount);
      creditors[j] = MapEntry(creditor.key, creditor.value - amount);

      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }

    return transfers;
  }

  double get _totalPool => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  Future<void> _completeAndSaveSession(
      List<SettlementTransfer> settlements) async {
    if (_units.isEmpty || settlements.isEmpty) return;

    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

    final session = SavedSplitSession(
      id: _currentSessionId!,
      dateString: DateTime.now().toString().substring(0, 16),
      totalPool: _totalPool,
      units: List.from(_units),
      expenses: List.from(_expenses),
      settlements: settlements,
      aiSummary: _latestAiSummary,
    );
    await ExpenseStorageService.saveSession(session);

    setState(() {
      _isDataSaved = true;
    });

    _showTopSnackBar("Split session successfully saved/updated on phone!",
        isError: false);
  }

  void _confirmClearAll() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Everything?",
            style: TextStyle(
                color: AppColors.labelPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          "This permanently deletes all units, expenses, and settlements in this session. This can't be undone.",
          style: TextStyle(color: AppColors.labelSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel",
                style: TextStyle(color: AppColors.labelSecondary)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _units.clear();
                _expenses.clear();
                _latestAiSummary = null;
                _currentSessionId = null;
                _isDataSaved = false;
              });
              Navigator.pop(ctx);
              _showTopSnackBar("Everything has been removed.", isError: false);
            },
            child: const Text("Remove Everything",
                style: TextStyle(
                    color: AppColors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReusableBlurredSheet(
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetGrabber(),
              const Text("Select Currency",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.labelPrimary)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _currencies.length,
                  itemBuilder: (context, index) {
                    final curr = _currencies[index];
                    final isSelected = curr.code == _selectedCurrency.code;
                    return ListTile(
                      title: Text("${curr.name} (${curr.code})",
                          style: TextStyle(
                              color: isSelected
                                  ? AppColors.green
                                  : AppColors.labelPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      trailing: Text(curr.symbol,
                          style: TextStyle(
                              fontSize: 16,
                              color: isSelected
                                  ? AppColors.green
                                  : AppColors.labelSecondary,
                              fontWeight: FontWeight.bold)),
                      onTap: () {
                        setState(() {
                          _selectedCurrency = curr;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settlements = _calculateSettlements();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.5, -1.0),
                    radius: 1.3,
                    colors: [
                      AppColors.green.withOpacity(0.10),
                      Colors.transparent
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _CollapsingHeaderDelegate(
                  title: "Expense Splitter",
                  topPadding: topPadding,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryHeroCard(
                        totalPool: _totalPool,
                        unitCount: _units.length,
                        transferCount: settlements.length,
                        currencySymbol: _selectedCurrency.symbol,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ReusableButton(
                              label: "Add Unit",
                              icon: CupertinoIcons.person_add_solid,
                              onPressed: () {
                                if (!_isGeneratingAi) {
                                  _showAddOrEditUnitSheet(context);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ReusableButton(
                              label: "Add Expense",
                              icon: CupertinoIcons.doc_text_fill,
                              color: AppColors.tertiaryBg,
                              foreground: Colors.white,
                              onPressed: () {
                                if (!_isGeneratingAi) {
                                  if (_units.isEmpty) {
                                    _showTopSnackBar(
                                        "Please add at least one unit before logging expenses.");
                                    return;
                                  }
                                  _showAddOrEditExpenseSheet(context);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("UNITS",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: AppColors.labelSecondary)),
                          if (_units.isNotEmpty)
                            ReusableBadge(text: "${_units.length}"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _units.isEmpty
                          ? const EmptyState(
                              icon: CupertinoIcons.house_fill,
                              title: "No units yet",
                              subtitle:
                                  "Tap “Add Unit” to bring everyone into the split.")
                          : ReusableGlassCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Column(
                                children: _units.map((u) {
                                  final totalPaid = _getUnitTotalPaid(u.id);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      children: [
                                        InitialsAvatar(name: u.name),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(u.name,
                                                  style: const TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors
                                                          .labelPrimary)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  "Paid: ${_selectedCurrency.symbol}${totalPaid.toStringAsFixed(2)} • ${u.members.isEmpty ? 'No members' : u.members.join(', ')}",
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: AppColors
                                                          .labelTertiary)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              CupertinoIcons.pencil,
                                              size: 16,
                                              color: AppColors.labelSecondary),
                                          onPressed: _isGeneratingAi
                                              ? null
                                              : () => _showAddOrEditUnitSheet(
                                                  context,
                                                  unitToEdit: u),
                                        ),
                                        IconButton(
                                          icon: const Icon(CupertinoIcons.trash,
                                              size: 16,
                                              color: AppColors.redAccent),
                                          onPressed: _isGeneratingAi
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _units.removeWhere((item) =>
                                                        item.id == u.id);
                                                    for (var e in _expenses) {
                                                      e.payers.removeWhere(
                                                          (p) =>
                                                              p.familyId ==
                                                              u.id);
                                                    }
                                                    _expenses.removeWhere((e) =>
                                                        e.payers.isEmpty);
                                                  });
                                                  _markDataChanged();
                                                },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("EXPENSES LIST",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: AppColors.labelSecondary)),
                          if (_expenses.isNotEmpty)
                            ReusableBadge(text: "${_expenses.length}"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _expenses.isEmpty
                          ? const EmptyState(
                              icon: CupertinoIcons.doc_text,
                              title: "No expenses logged",
                              subtitle: "Tap “Add Expense” to track expenses.")
                          : ReusableGlassCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Column(
                                children: _expenses.map((e) {
                                  String payerSummary = e.payers.map((p) {
                                    final uMatch = _units.firstWhere(
                                      (u) => u.id == p.familyId,
                                      orElse: () => FamilyUnit(
                                          id: '', name: 'Unknown', members: []),
                                    );
                                    return "${uMatch.name}: ${_selectedCurrency.symbol}${p.amountPaid.toStringAsFixed(0)}";
                                  }).join(', ');

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(e.title,
                                                  style: const TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors
                                                          .labelPrimary)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  "Paid by [$payerSummary] • ${_selectedCurrency.symbol}${e.amount.toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: AppColors
                                                          .labelTertiary)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              CupertinoIcons.pencil,
                                              size: 16,
                                              color: AppColors.labelSecondary),
                                          onPressed: _isGeneratingAi
                                              ? null
                                              : () =>
                                                  _showAddOrEditExpenseSheet(
                                                      context,
                                                      expenseToEdit: e),
                                        ),
                                        IconButton(
                                          icon: const Icon(CupertinoIcons.trash,
                                              size: 16,
                                              color: AppColors.redAccent),
                                          onPressed: _isGeneratingAi
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _expenses.removeWhere(
                                                        (item) =>
                                                            item.id == e.id);
                                                  });
                                                  _markDataChanged();
                                                },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("SETTLEMENTS",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: AppColors.labelSecondary)),
                          if (settlements.isNotEmpty)
                            ReusableBadge(text: "${settlements.length}"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      settlements.isEmpty
                          ? const EmptyState(
                              icon: CupertinoIcons
                                  .arrow_right_arrow_left_circle_fill,
                              title: "Nothing to settle yet",
                              subtitle:
                                  "Add an expense and we'll work out who owes who.")
                          : ReusableGlassCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Column(
                                children: settlements.map((s) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                              color: AppColors.green
                                                  .withOpacity(0.16),
                                              shape: BoxShape.circle),
                                          child: const Icon(
                                              CupertinoIcons.arrow_up_right,
                                              color: AppColors.green,
                                              size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: RichText(
                                            text: TextSpan(
                                              style:
                                                  const TextStyle(fontSize: 15),
                                              children: [
                                                TextSpan(
                                                    text: s.from,
                                                    style: const TextStyle(
                                                        color: AppColors
                                                            .labelPrimary,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                const TextSpan(
                                                    text: "  owes  ",
                                                    style: TextStyle(
                                                        color: AppColors
                                                            .labelTertiary)),
                                                TextSpan(
                                                    text: s.to,
                                                    style: const TextStyle(
                                                        color: AppColors
                                                            .labelPrimary,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Text(
                                            "${_selectedCurrency.symbol}${s.amount.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.green,
                                                letterSpacing: -0.2)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                      if (settlements.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Column(
                          children: [
                            ReusableButton(
                              label: _isGeneratingAi
                                  ? "Summarizing..."
                                  : (_isDataSaved && _latestAiSummary != null
                                      ? "AI Summary Up to Date"
                                      : "Summarize with Gemini AI"),
                              icon: CupertinoIcons.sparkles,
                              iconOnly: false,
                              color: AppColors.secondaryBg,
                              foreground: AppColors.green,
                              onPressed: (_isGeneratingAi ||
                                      (_isDataSaved &&
                                          _latestAiSummary != null))
                                  ? () {}
                                  : () {
                                      _generateAiSummary(settlements);
                                    },
                            ),
                            const SizedBox(height: 12),
                            ReusableButton(
                              label: _isDataSaved
                                  ? "Saved to Phone"
                                  : "Save Split Session to Phone",
                              icon: CupertinoIcons.floppy_disk,
                              iconOnly: false,
                              color: AppColors.green,
                              foreground: Colors.black,
                              onPressed: (_isGeneratingAi || _isDataSaved)
                                  ? () {}
                                  : () {
                                      _completeAndSaveSession(settlements);
                                    },
                            ),
                            const SizedBox(height: 12),
                            ReusableButton(
                              label: "Export Settlement Report",
                              icon: CupertinoIcons.square_arrow_up_fill,
                              iconOnly: false,
                              color: AppColors.tertiaryBg,
                              foreground: AppColors.labelPrimary,
                              onPressed: () {
                                if (!_isGeneratingAi) {
                                  _showExportBottomSheet(context, settlements);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                      if (_units.isNotEmpty || _expenses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ReusableButton(
                          label: "Remove Everything",
                          icon: CupertinoIcons.trash,
                          iconOnly: false,
                          color: AppColors.redAccent,
                          foreground: Colors.white,
                          onPressed: () {
                            if (!_isGeneratingAi) {
                              _confirmClearAll();
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FloatingGlassFooter(
              selectedCurrencySymbol: _selectedCurrency.symbol,
              onCurrencyTap: () => _showCurrencyPicker(),
              onConverterTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CurrencyConverterPage()),
                );
              },
              onHistoryTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SavedSessionsPage()),
                );
              },
              onGuideTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GuidePage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetGrabber() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        width: 36,
        height: 5,
        decoration: BoxDecoration(
            color: AppColors.labelPrimary.withOpacity(0.16),
            borderRadius: BorderRadius.circular(3)),
      ),
    );
  }

  void _showAddOrEditUnitSheet(BuildContext context, {FamilyUnit? unitToEdit}) {
    if (unitToEdit != null) {
      _unitNameController.text = unitToEdit.name;
      _membersController.text = unitToEdit.members.join(', ');
    } else {
      _unitNameController.clear();
      _membersController.clear();
    }

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReusableBlurredSheet(
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 12),
          child: Form(
            key: _unitFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetGrabber(),
                Text(unitToEdit == null ? "Add Unit" : "Edit Unit",
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.labelPrimary,
                        letterSpacing: -0.3)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _unitNameController,
                  style: const TextStyle(color: AppColors.labelPrimary),
                  decoration: InputDecoration(
                    labelText: "Unit Name (e.g. Rony)",
                    labelStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 14.5),
                    filled: true,
                    fillColor: AppColors.labelPrimary.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.green, width: 1.4)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a unit name";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _membersController,
                  style: const TextStyle(color: AppColors.labelPrimary),
                  decoration: InputDecoration(
                    labelText: "Members (comma separated)",
                    labelStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 14.5),
                    filled: true,
                    fillColor: AppColors.labelPrimary.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.green, width: 1.4)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter at least one member";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                ReusableButton(
                  label: unitToEdit == null ? "Save Unit" : "Update Unit",
                  icon: CupertinoIcons.check_mark,
                  onPressed: () => _saveUnit(editId: unitToEdit?.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddOrEditExpenseSheet(BuildContext context,
      {ExpenseEntry? expenseToEdit}) {
    _expenseTitleController.text = expenseToEdit?.title ?? '';
    _expenseAmountController.text =
        expenseToEdit != null ? expenseToEdit.amount.toString() : '';

    Map<String, double> payerContributions = {};
    for (var u in _units) {
      payerContributions[u.id] = 0.0;
    }

    if (expenseToEdit != null) {
      for (var p in expenseToEdit.payers) {
        payerContributions[p.familyId] = p.amountPaid;
      }
    }

    final Map<String, TextEditingController> payerControllers = {
      for (var u in _units)
        u.id: TextEditingController(
          text: payerContributions[u.id] == null ||
                  payerContributions[u.id] == 0.0
              ? ''
              : payerContributions[u.id].toString(),
        ),
    };

    Set<String> selectedParticipants = {};
    if (expenseToEdit != null) {
      selectedParticipants = Set.from(expenseToEdit.participatingMemberNames);
    } else {
      for (var u in _units) {
        if (u.members.isEmpty) {
          selectedParticipants.add(u.name);
        } else {
          selectedParticipants.addAll(u.members);
        }
      }
    }

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateModal) {
          return ReusableBlurredSheet(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 12),
              child: SingleChildScrollView(
                child: Form(
                  key: _expenseFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetGrabber(),
                      Text(
                          expenseToEdit == null
                              ? "Add Expense"
                              : "Edit Expense",
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.labelPrimary,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _expenseTitleController,
                        style: const TextStyle(color: AppColors.labelPrimary),
                        decoration: InputDecoration(
                          labelText: "Expense Title",
                          labelStyle: const TextStyle(
                              color: AppColors.labelTertiary, fontSize: 14.5),
                          filled: true,
                          fillColor: AppColors.labelPrimary.withOpacity(0.04),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.green, width: 1.4)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Please enter an expense title";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _expenseAmountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.labelPrimary),
                        onChanged: (val) {
                          setStateModal(() {});
                        },
                        decoration: InputDecoration(
                          labelText:
                              "Total Amount (${_selectedCurrency.symbol})",
                          labelStyle: const TextStyle(
                              color: AppColors.labelTertiary, fontSize: 14.5),
                          filled: true,
                          fillColor: AppColors.labelPrimary.withOpacity(0.04),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.green, width: 1.4)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Please enter a total amount";
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return "Please enter a valid positive number";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text("Who paid how much?",
                          style: TextStyle(
                              color: AppColors.labelSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._units.map((u) {
                        final ctrl = payerControllers[u.id]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(u.name,
                                    style: const TextStyle(
                                        color: AppColors.labelPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                      color: AppColors.labelPrimary,
                                      fontSize: 14),
                                  onChanged: (value) {
                                    payerContributions[u.id] =
                                        double.tryParse(value) ?? 0.0;
                                  },
                                  decoration: InputDecoration(
                                    hintText: "${_selectedCurrency.symbol}0.00",
                                    hintStyle: TextStyle(
                                        color: AppColors.labelTertiary),
                                    filled: true,
                                    fillColor: AppColors.labelPrimary
                                        .withOpacity(0.04),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: AppColors.green,
                                            width: 1.2)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text("Split among members:",
                          style: TextStyle(
                              color: AppColors.labelSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._units.map((u) {
                        List<String> memberList =
                            u.members.isEmpty ? [u.name] : u.members;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name,
                                style: const TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            ...memberList.map((m) {
                              bool isSelected =
                                  selectedParticipants.contains(m);
                              return CheckboxListTile(
                                title: Text(m,
                                    style: const TextStyle(fontSize: 14)),
                                value: isSelected,
                                activeColor: AppColors.green,
                                checkColor: Colors.black,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (bool? value) {
                                  setStateModal(() {
                                    if (value == true) {
                                      selectedParticipants.add(m);
                                    } else {
                                      selectedParticipants.remove(m);
                                    }
                                  });
                                },
                              );
                            }),
                          ],
                        );
                      }),
                      const SizedBox(height: 22),
                      ReusableButton(
                        label: expenseToEdit == null
                            ? "Save Expense"
                            : "Update Expense",
                        icon: CupertinoIcons.check_mark,
                        onPressed: () {
                          _saveExpense(
                            editId: expenseToEdit?.id,
                            payerContributions: payerContributions,
                            participatingMembers: selectedParticipants.toList(),
                            setStateModal: setStateModal,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      for (final c in payerControllers.values) {
        c.dispose();
      }
    });
  }

  void _showExportBottomSheet(
      BuildContext context, List<SettlementTransfer> settlements) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ReusableBlurredSheet(
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetGrabber(),
              const Text("Export Options",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.labelPrimary)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(CupertinoIcons.doc_richtext,
                    color: AppColors.green),
                title: const Text("Export as PDF Report"),
                onTap: () {
                  Navigator.pop(context);
                  ExpenseExportService.exportPdf(
                    settlements: settlements,
                    units: _units,
                    expenses: _expenses,
                    currencySymbol: _selectedCurrency.symbol,
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(CupertinoIcons.doc_text, color: Colors.white),
                title: const Text("Export as Document (.txt)"),
                onTap: () {
                  Navigator.pop(context);
                  ExpenseExportService.exportDocument(settlements: settlements);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedSessionsPage extends StatefulWidget {
  const SavedSessionsPage({Key? key}) : super(key: key);

  @override
  State<SavedSessionsPage> createState() => _SavedSessionsPageState();
}

class _SavedSessionsPageState extends State<SavedSessionsPage> {
  List<SavedSplitSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await ExpenseStorageService.getSavedSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _deleteSession(String id) async {
    await ExpenseStorageService.deleteSession(id);
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Saved Split Sessions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.labelPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.green))
              : _sessions.isEmpty
                  ? const Center(
                      child: Text(
                        "No saved split sessions found.",
                        style: TextStyle(color: AppColors.labelTertiary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return ReusableGlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    session.dateString,
                                    style: const TextStyle(
                                      color: AppColors.labelSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    "Pool: ₹${session.totalPool.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: AppColors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Units: ${session.units.map((u) => u.name).join(', ')}",
                                style: const TextStyle(
                                  color: AppColors.labelPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (session.aiSummary != null &&
                                  session.aiSummary!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color:
                                            AppColors.green.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(CupertinoIcons.sparkles,
                                          size: 16, color: AppColors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          session.aiSummary!,
                                          style: const TextStyle(
                                            color: AppColors.labelPrimary,
                                            fontSize: 12.5,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _deleteSession(session.id),
                                  icon: const Icon(CupertinoIcons.trash,
                                      size: 14, color: AppColors.redAccent),
                                  label: const Text("Delete",
                                      style: TextStyle(
                                          color: AppColors.redAccent,
                                          fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FloatingGlassFooter(
              selectedCurrencySymbol: '₹',
              isHome: false,
              onHomeTap: () => Navigator.pop(context),
              onConverterTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CurrencyConverterPage()),
                );
              },
              isHistoryActive: true,
              onHistoryTap: () {},
              onGuideTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const GuidePage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeroCard extends StatelessWidget {
  final double totalPool;
  final int unitCount;
  final int transferCount;
  final String currencySymbol;

  const _SummaryHeroCard(
      {required this.totalPool,
      required this.unitCount,
      required this.transferCount,
      required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(28));

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF000000), Color(0xFF1C1C1E), Color(0xFF2A2A2C)],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TOTAL POOLED",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text("$currencySymbol${totalPool.toStringAsFixed(2)}",
                style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                _heroStat(CupertinoIcons.house_fill, "$unitCount", "Units"),
                const SizedBox(width: 24),
                _heroStat(CupertinoIcons.arrow_right_arrow_left,
                    "$transferCount", "To Settle"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.85), size: 15),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
      ],
    );
  }
}

class _CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final double topPadding;

  _CollapsingHeaderDelegate({
    required this.title,
    required this.topPadding,
  });

  @override
  double get minExtent => 52.0 + topPadding;
  @override
  double get maxExtent => 110.0 + topPadding;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final progress = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10 * progress, sigmaY: 10 * progress),
        child: Container(
          padding: EdgeInsets.only(top: topPadding),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6 * progress),
            border: Border(
                bottom: BorderSide(
                    color: AppColors.labelPrimary.withOpacity(0.08 * progress),
                    width: 0.6)),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.labelPrimary,
                    fontSize: 32 - (progress * 14),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingHeaderDelegate oldDelegate) =>
      oldDelegate.title != title || oldDelegate.topPadding != topPadding;
}
