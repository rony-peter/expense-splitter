import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/expense_models.dart';
import '../constants/currency_codes.dart';
import '../services/ai_service.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_components.dart';
import '../widgets/save_section.dart';

enum ExpenseMode { single, individualMulti, batch }

class ExpenseHomePage extends StatefulWidget {
  final CurrencyOption selectedCurrency;
  final ValueChanged<CurrencyOption> onCurrencyChanged;
  final VoidCallback onOpenCurrencyPicker;

  const ExpenseHomePage({
    Key? key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    required this.onOpenCurrencyPicker,
  }) : super(key: key);

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  ExpenseMode _activeMode = ExpenseMode.single;

  // Single Expense Mode Controllers
  final GlobalKey<FormState> _singleFormKey = GlobalKey<FormState>();
  final TextEditingController _singleTitleController = TextEditingController();
  final TextEditingController _singleAmountController = TextEditingController();
  final TextEditingController _singlePayerController = TextEditingController();
  final TextEditingController _singleParticipantsController =
      TextEditingController();

  // Individual Multi-Expense Mode State & Controllers
  final List<String> _individualPeople = [];
  final List<ExpenseEntry> _individualExpenses = [];
  final TextEditingController _individualPersonController =
      TextEditingController();
  final GlobalKey<FormState> _indExpenseFormKey = GlobalKey<FormState>();
  final TextEditingController _indExpenseTitleController =
      TextEditingController();
  final TextEditingController _indExpenseAmountController =
      TextEditingController();

  // Multi-Family (Batch) Mode State
  final List<FamilyUnit> _units = [];
  final List<ExpenseEntry> _expenses = [];

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
    _singleTitleController.dispose();
    _singleAmountController.dispose();
    _singlePayerController.dispose();
    _singleParticipantsController.dispose();

    _individualPersonController.dispose();
    _indExpenseTitleController.dispose();
    _indExpenseAmountController.dispose();

    _unitNameController.dispose();
    _membersController.dispose();
    _expenseTitleController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  void _markDataChanged() {
    setState(() {
      _isDataSaved = false;
      _latestAiSummary = null;
    });
  }

  Widget _buildAddExpenseHint(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.info_circle,
              size: 14, color: AppColors.labelTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.labelTertiary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearSingleEntries() {
    HapticFeedback.mediumImpact();
    setState(() {
      _singleTitleController.clear();
      _singleAmountController.clear();
      _singlePayerController.clear();
      _singleParticipantsController.clear();
      _currentSessionId = null;
      _latestAiSummary = null;
      _isDataSaved = false;
    });
    _showTopSnackBar("Single expense entries removed.", isError: false);
  }

  void _clearIndividualMultiEntries() {
    HapticFeedback.mediumImpact();
    setState(() {
      _individualPeople.clear();
      _individualExpenses.clear();
      _currentSessionId = null;
      _latestAiSummary = null;
      _isDataSaved = false;
    });
    _showTopSnackBar("Individual multi-expense entries removed.",
        isError: false);
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

  // Adapter converting any mode's current state to unified units and expenses for AI & Storage
  (List<FamilyUnit>, List<ExpenseEntry>, double) _getEffectiveData() {
    if (_activeMode == ExpenseMode.single) {
      final title = _singleTitleController.text.trim().isEmpty
          ? "Single Bill Expense"
          : _singleTitleController.text.trim();
      final amount = double.tryParse(_singleAmountController.text) ?? 0.0;
      final payer = _singlePayerController.text.trim();
      final rawParticipants = _singleParticipantsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final participantsSet = rawParticipants.toSet();
      if (payer.isNotEmpty) participantsSet.add(payer);
      final participants = participantsSet.toList();

      final dynamicUnits = participants
          .map((p) => FamilyUnit(id: p, name: p, members: [p]))
          .toList();

      final dynamicExpenses = [
        ExpenseEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          payers: [
            ExpensePayerContribution(familyId: payer, amountPaid: amount)
          ],
          amount: amount,
          participatingFamilyIds: participants,
          participatingMemberNames: rawParticipants,
        )
      ];
      return (dynamicUnits, dynamicExpenses, amount);
    } else if (_activeMode == ExpenseMode.individualMulti) {
      final dynamicUnits = _individualPeople
          .map((p) => FamilyUnit(id: p, name: p, members: [p]))
          .toList();
      final totalPool =
          _individualExpenses.fold(0.0, (sum, e) => sum + e.amount);
      return (dynamicUnits, _individualExpenses, totalPool);
    } else {
      return (_units, _expenses, _totalPool);
    }
  }

  List<SettlementTransfer> _calculateSingleSettlements() {
    final amount = double.tryParse(_singleAmountController.text) ?? 0.0;
    final payer = _singlePayerController.text.trim();
    final rawParticipants = _singleParticipantsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (amount <= 0 || payer.isEmpty || rawParticipants.isEmpty) {
      return [];
    }

    final participants = rawParticipants.toSet().toList();
    final share = amount / participants.length;
    final List<SettlementTransfer> result = [];

    for (var person in participants) {
      if (person.toLowerCase() != payer.toLowerCase()) {
        result.add(SettlementTransfer(
          from: person,
          to: payer,
          amount: share,
        ));
      }
    }
    return result;
  }

  List<SettlementTransfer> _calculateIndividualMultiSettlements() {
    Map<String, double> netBalances = {for (var p in _individualPeople) p: 0.0};

    for (var exp in _individualExpenses) {
      for (var p in exp.payers) {
        netBalances[p.familyId] =
            (netBalances[p.familyId] ?? 0.0) + p.amountPaid;
      }

      final activeParticipants = exp.participatingMemberNames;
      if (activeParticipants.isNotEmpty) {
        double perHeadAmount = exp.amount / activeParticipants.length;
        for (var person in activeParticipants) {
          netBalances[person] = (netBalances[person] ?? 0.0) - perHeadAmount;
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

  List<SettlementTransfer> _calculateBatchSettlements() {
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

      List<String> activeParticipants = List.from(exp.participatingMemberNames);
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

  Future<void> _generateAiSummary(List<SettlementTransfer> settlements) async {
    final (effectiveUnits, effectiveExpenses, totalPool) = _getEffectiveData();

    setState(() => _isGeneratingAi = true);
    HapticFeedback.lightImpact();

    try {
      final summary = await AIService.summarizeBudget(
        units: effectiveUnits,
        expenses: effectiveExpenses,
        settlements: settlements,
        currencySymbol: widget.selectedCurrency.symbol,
      );

      setState(() {
        _latestAiSummary = summary;
      });

      _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();
      final session = SavedSplitSession(
        id: _currentSessionId!,
        dateString: DateTime.now().toString().substring(0, 16),
        totalPool: totalPool,
        units: List.from(effectiveUnits),
        expenses: List.from(effectiveExpenses),
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

  Future<void> _completeAndSaveSession(
      List<SettlementTransfer> settlements) async {
    final (effectiveUnits, effectiveExpenses, totalPool) = _getEffectiveData();
    if (effectiveUnits.isEmpty || settlements.isEmpty) return;

    _currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

    final session = SavedSplitSession(
      id: _currentSessionId!,
      dateString: DateTime.now().toString().substring(0, 16),
      totalPool: totalPool,
      units: List.from(effectiveUnits),
      expenses: List.from(effectiveExpenses),
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

  double get _totalPool => _expenses.fold(0.0, (sum, e) => sum + e.amount);

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
          "This permanently deletes all items in this session. This can't be undone.",
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
                _singleTitleController.clear();
                _singleAmountController.clear();
                _singlePayerController.clear();
                _singleParticipantsController.clear();
                _individualPeople.clear();
                _individualExpenses.clear();
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return CustomScrollView(
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildModeTab("Single Bill", CupertinoIcons.bolt_fill,
                          ExpenseMode.single),
                      _buildModeTab(
                          "Individual Multi",
                          CupertinoIcons.person_2_fill,
                          ExpenseMode.individualMulti),
                      _buildModeTab("Multi Group", CupertinoIcons.layers_fill,
                          ExpenseMode.batch),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_activeMode == ExpenseMode.single)
                  _buildSingleExpenseView()
                else if (_activeMode == ExpenseMode.individualMulti)
                  _buildIndividualMultiExpenseView()
                else
                  _buildBatchExpenseView(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab(String label, IconData icon, ExpenseMode mode) {
    final bool isActive = _activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _activeMode = mode;
            _latestAiSummary = null;
            _isDataSaved = false;
            _currentSessionId = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.tertiaryBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isActive ? AppColors.green : AppColors.labelSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.labelPrimary
                        : AppColors.labelSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SINGLE EXPENSE MODE VIEW ---
  Widget _buildSingleExpenseView() {
    final singleSettlements = _calculateSingleSettlements();
    final totalAmount = double.tryParse(_singleAmountController.text) ?? 0.0;
    final rawParticipants = _singleParticipantsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final perPersonShare =
        rawParticipants.isNotEmpty ? totalAmount / rawParticipants.length : 0.0;

    final bool hasSingleData = _singleTitleController.text.isNotEmpty ||
        _singleAmountController.text.isNotEmpty ||
        _singlePayerController.text.isNotEmpty ||
        _singleParticipantsController.text.isNotEmpty;

    final bool isAiDisabled =
        _isGeneratingAi || (_isDataSaved && _latestAiSummary != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryHeroCard(
          totalPool: totalAmount,
          unitCount: rawParticipants.length,
          transferCount: singleSettlements.length,
          currencySymbol: widget.selectedCurrency.symbol,
        ),
        const SizedBox(height: 20),
        ReusableGlassCard(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _singleFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "QUICK SINGLE SPLIT",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AppColors.labelSecondary,
                      ),
                    ),
                    if (hasSingleData)
                      GestureDetector(
                        onTap: _clearSingleEntries,
                        child: const Text(
                          "Clear",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _singleTitleController,
                  style: const TextStyle(color: AppColors.labelPrimary),
                  onChanged: (_) => _markDataChanged(),
                  decoration: InputDecoration(
                    labelText: "Expense Title (e.g., Dinner, Uber)",
                    labelStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 14),
                    filled: true,
                    fillColor: AppColors.labelPrimary.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _singleAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.labelPrimary),
                  onChanged: (_) => _markDataChanged(),
                  decoration: InputDecoration(
                    labelText:
                        "Total Amount (${widget.selectedCurrency.symbol})",
                    labelStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 14),
                    filled: true,
                    fillColor: AppColors.labelPrimary.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _singlePayerController,
                  style: const TextStyle(color: AppColors.labelPrimary),
                  onChanged: (_) => _markDataChanged(),
                  decoration: InputDecoration(
                    labelText: "Who Paid?",
                    hintText: "e.g., Alex",
                    hintStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 13),
                    labelStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 14),
                    filled: true,
                    fillColor: AppColors.labelPrimary.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _singleParticipantsController,
                  style: const TextStyle(color: AppColors.labelPrimary),
                  onChanged: (_) => _markDataChanged(),
                  decoration: InputDecoration(
                    labelText: "Split Among (comma separated)",
                    hintText: "e.g., Alex, Sam, Jordan",
                    hintStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 13),
                    labelStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 14),
                    filled: true,
                    fillColor: AppColors.labelPrimary.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (perPersonShare > 0) ...[
          const SizedBox(height: 20),
          ReusableGlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Per Person Share",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.labelPrimary,
                  ),
                ),
                Text(
                  "${widget.selectedCurrency.symbol}${perPersonShare.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "SETTLEMENTS",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.labelSecondary,
              ),
            ),
            if (singleSettlements.isNotEmpty)
              ReusableBadge(text: "${singleSettlements.length}"),
          ],
        ),
        const SizedBox(height: 10),
        singleSettlements.isEmpty
            ? const EmptyState(
                icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
                title: "No single split calculated",
                subtitle: "Fill in the bill details above to view settlements.",
              )
            : ReusableGlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: singleSettlements.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: AppColors.green.withOpacity(0.16),
                                shape: BoxShape.circle),
                            child: const Icon(CupertinoIcons.arrow_up_right,
                                color: AppColors.green, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 15),
                                children: [
                                  TextSpan(
                                      text: s.from,
                                      style: const TextStyle(
                                          color: AppColors.labelPrimary,
                                          fontWeight: FontWeight.w600)),
                                  const TextSpan(
                                      text: " owes ",
                                      style: TextStyle(
                                          color: AppColors.labelTertiary)),
                                  TextSpan(
                                      text: s.to,
                                      style: const TextStyle(
                                          color: AppColors.labelPrimary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            "${widget.selectedCurrency.symbol}${s.amount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
        if (singleSettlements.isNotEmpty) ...[
          const SizedBox(height: 28),
          Column(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isAiDisabled ? 0.4 : 1.0,
                child: ReusableButton(
                  label: _isGeneratingAi
                      ? "Summarizing..."
                      : (_isDataSaved && _latestAiSummary != null
                          ? "AI Summary Up to Date"
                          : "Summarize with Gemini AI"),
                  icon: CupertinoIcons.sparkles,
                  iconOnly: false,
                  color: AppColors.secondaryBg,
                  foreground: AppColors.green,
                  onPressed: isAiDisabled
                      ? null
                      : () {
                          _generateAiSummary(singleSettlements);
                        },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_isGeneratingAi || _isDataSaved) ? 0.4 : 1.0,
                child: SaveSection(
                  isDataSaved: _isDataSaved,
                  isGeneratingAi: _isGeneratingAi,
                  onSave: (_isGeneratingAi || _isDataSaved)
                      ? null
                      : () {
                          _completeAndSaveSession(singleSettlements);
                        },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isGeneratingAi ? 0.4 : 1.0,
                child: ReusableButton(
                  label: "Export Settlement Report",
                  icon: CupertinoIcons.square_arrow_up_fill,
                  iconOnly: false,
                  color: AppColors.tertiaryBg,
                  foreground: AppColors.labelPrimary,
                  onPressed: _isGeneratingAi
                      ? null
                      : () {
                          _showExportBottomSheet(context, singleSettlements);
                        },
                ),
              ),
            ],
          ),
        ],
        if (hasSingleData) ...[
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isGeneratingAi ? 0.4 : 1.0,
            child: ReusableButton(
              label: "Remove Entries",
              icon: CupertinoIcons.trash,
              iconOnly: false,
              color: AppColors.redAccent,
              foreground: Colors.white,
              onPressed: _isGeneratingAi ? null : _clearSingleEntries,
            ),
          ),
        ],
      ],
    );
  }

  // --- INDIVIDUAL MULTI-EXPENSE MODE VIEW ---
  Widget _buildIndividualMultiExpenseView() {
    final settlements = _calculateIndividualMultiSettlements();
    final double totalPool =
        _individualExpenses.fold(0.0, (sum, e) => sum + e.amount);

    final bool hasData =
        _individualPeople.isNotEmpty || _individualExpenses.isNotEmpty;

    final bool isAiDisabled =
        _isGeneratingAi || (_isDataSaved && _latestAiSummary != null);

    final bool canAddExpense = _individualPeople.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryHeroCard(
          totalPool: totalPool,
          unitCount: _individualPeople.length,
          transferCount: settlements.length,
          currencySymbol: widget.selectedCurrency.symbol,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isGeneratingAi ? 0.4 : 1.0,
                child: ReusableButton(
                  label: "Add Person",
                  icon: CupertinoIcons.person_add_solid,
                  onPressed:
                      _isGeneratingAi ? null : () => _showAddPersonDialog(),
                ),
              ),
            ),
            if (canAddExpense) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isGeneratingAi ? 0.4 : 1.0,
                  child: ReusableButton(
                    label: "Add Expense",
                    icon: CupertinoIcons.doc_text_fill,
                    color: AppColors.tertiaryBg,
                    foreground: Colors.white,
                    onPressed: _isGeneratingAi
                        ? null
                        : () {
                            _showAddIndividualExpenseSheet();
                          },
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!canAddExpense)
          _buildAddExpenseHint(
              "Add at least 2 people to start logging expenses."),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("PARTICIPANTS",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.labelSecondary)),
            if (_individualPeople.isNotEmpty)
              ReusableBadge(text: "${_individualPeople.length}"),
          ],
        ),
        const SizedBox(height: 10),
        _individualPeople.isEmpty
            ? const EmptyState(
                icon: CupertinoIcons.person_3_fill,
                title: "No participants added",
                subtitle:
                    "Add individual people to start logging multiple shared bills.",
              )
            : ReusableGlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: _individualPeople.map((person) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: InitialsAvatar(name: person),
                      title: Text(person,
                          style: const TextStyle(
                              color: AppColors.labelPrimary,
                              fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        icon: const Icon(CupertinoIcons.trash,
                            size: 16, color: AppColors.redAccent),
                        onPressed: _isGeneratingAi
                            ? null
                            : () {
                                setState(() {
                                  _individualPeople.remove(person);
                                  _individualExpenses.removeWhere((e) =>
                                      e.payers
                                          .any((p) => p.familyId == person) ||
                                      e.participatingMemberNames
                                          .contains(person));
                                });
                                _markDataChanged();
                              },
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
            if (_individualExpenses.isNotEmpty)
              ReusableBadge(text: "${_individualExpenses.length}"),
          ],
        ),
        const SizedBox(height: 10),
        _individualExpenses.isEmpty
            ? const EmptyState(
                icon: CupertinoIcons.doc_text,
                title: "No expenses logged",
                subtitle: "Tap “Add Expense” to log bills between individuals.",
              )
            : ReusableGlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: _individualExpenses.map((e) {
                    final payerName = e.payers.first.familyId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.title,
                          style: const TextStyle(
                              color: AppColors.labelPrimary,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        "Paid by $payerName • Split among ${e.participatingMemberNames.join(', ')}",
                        style: const TextStyle(
                            color: AppColors.labelTertiary, fontSize: 12.5),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${widget.selectedCurrency.symbol}${e.amount.toStringAsFixed(2)}",
                            style: const TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.trash,
                                size: 16, color: AppColors.redAccent),
                            onPressed: _isGeneratingAi
                                ? null
                                : () {
                                    setState(() {
                                      _individualExpenses.removeWhere(
                                          (item) => item.id == e.id);
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
            const Text("SETTLEMENTS (WHO PAYS WHOM)",
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
                icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
                title: "No settlements calculated",
                subtitle:
                    "Log expenses above to calculate individual balances.",
              )
            : ReusableGlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: settlements.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: AppColors.green.withOpacity(0.16),
                                shape: BoxShape.circle),
                            child: const Icon(CupertinoIcons.arrow_up_right,
                                color: AppColors.green, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14.5),
                                children: [
                                  TextSpan(
                                      text: s.from,
                                      style: const TextStyle(
                                          color: AppColors.labelPrimary,
                                          fontWeight: FontWeight.w600)),
                                  const TextSpan(
                                      text: " owes ",
                                      style: TextStyle(
                                          color: AppColors.labelTertiary)),
                                  TextSpan(
                                      text: s.to,
                                      style: const TextStyle(
                                          color: AppColors.labelPrimary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            "${widget.selectedCurrency.symbol}${s.amount.toStringAsFixed(2)}",
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.green),
                          ),
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
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isAiDisabled ? 0.4 : 1.0,
                child: ReusableButton(
                  label: _isGeneratingAi
                      ? "Summarizing..."
                      : (_isDataSaved && _latestAiSummary != null
                          ? "AI Summary Up to Date"
                          : "Summarize with Gemini AI"),
                  icon: CupertinoIcons.sparkles,
                  iconOnly: false,
                  color: AppColors.secondaryBg,
                  foreground: AppColors.green,
                  onPressed: isAiDisabled
                      ? null
                      : () {
                          _generateAiSummary(settlements);
                        },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_isGeneratingAi || _isDataSaved) ? 0.4 : 1.0,
                child: SaveSection(
                  isDataSaved: _isDataSaved,
                  isGeneratingAi: _isGeneratingAi,
                  onSave: (_isGeneratingAi || _isDataSaved)
                      ? null
                      : () {
                          _completeAndSaveSession(settlements);
                        },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isGeneratingAi ? 0.4 : 1.0,
                child: ReusableButton(
                  label: "Export Settlement Report",
                  icon: CupertinoIcons.square_arrow_up_fill,
                  iconOnly: false,
                  color: AppColors.tertiaryBg,
                  foreground: AppColors.labelPrimary,
                  onPressed: _isGeneratingAi
                      ? null
                      : () {
                          _showExportBottomSheet(context, settlements);
                        },
                ),
              ),
            ],
          ),
        ],
        if (hasData) ...[
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isGeneratingAi ? 0.4 : 1.0,
            child: ReusableButton(
              label: "Remove Entries",
              icon: CupertinoIcons.trash,
              iconOnly: false,
              color: AppColors.redAccent,
              foreground: Colors.white,
              onPressed: _isGeneratingAi ? null : _clearIndividualMultiEntries,
            ),
          ),
        ],
      ],
    );
  }

  // --- MULTI-EXPENSE (BATCH) MODE VIEW ---
  Widget _buildBatchExpenseView() {
    final settlements = _calculateBatchSettlements();
    final bool isAiDisabled =
        _isGeneratingAi || (_isDataSaved && _latestAiSummary != null);

    final bool canAddExpense = _units.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryHeroCard(
          totalPool: _totalPool,
          unitCount: _units.length,
          transferCount: settlements.length,
          currencySymbol: widget.selectedCurrency.symbol,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isGeneratingAi ? 0.4 : 1.0,
                child: ReusableButton(
                  label: "Add Unit",
                  icon: CupertinoIcons.person_add_solid,
                  onPressed: _isGeneratingAi
                      ? null
                      : () {
                          _showAddOrEditUnitSheet(context);
                        },
                ),
              ),
            ),
            if (canAddExpense) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isGeneratingAi ? 0.4 : 1.0,
                  child: ReusableButton(
                    label: "Add Expense",
                    icon: CupertinoIcons.doc_text_fill,
                    color: AppColors.tertiaryBg,
                    foreground: Colors.white,
                    onPressed: _isGeneratingAi
                        ? null
                        : () {
                            _showAddOrEditExpenseSheet(context);
                          },
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!canAddExpense)
          _buildAddExpenseHint(
              "Add at least 2 units to start logging expenses."),
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
            if (_units.isNotEmpty) ReusableBadge(text: "${_units.length}"),
          ],
        ),
        const SizedBox(height: 10),
        _units.isEmpty
            ? const EmptyState(
                icon: CupertinoIcons.house_fill,
                title: "No units yet",
                subtitle: "Tap “Add Unit” to bring everyone into the split.")
            : ReusableGlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: _units.map((u) {
                    final totalPaid = _getUnitTotalPaid(u.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          InitialsAvatar(name: u.name),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.name,
                                    style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.labelPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                    "Paid: ${widget.selectedCurrency.symbol}${totalPaid.toStringAsFixed(2)} • ${u.members.isEmpty ? 'No members' : u.members.join(', ')}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.labelTertiary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.pencil,
                                size: 16, color: AppColors.labelSecondary),
                            onPressed: _isGeneratingAi
                                ? null
                                : () => _showAddOrEditUnitSheet(context,
                                    unitToEdit: u),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.trash,
                                size: 16, color: AppColors.redAccent),
                            onPressed: _isGeneratingAi
                                ? null
                                : () {
                                    setState(() {
                                      _units.removeWhere(
                                          (item) => item.id == u.id);
                                      for (var e in _expenses) {
                                        e.payers.removeWhere(
                                            (p) => p.familyId == u.id);
                                      }
                                      _expenses
                                          .removeWhere((e) => e.payers.isEmpty);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: _expenses.map((e) {
                    String payerSummary = e.payers.map((p) {
                      final uMatch = _units.firstWhere(
                        (u) => u.id == p.familyId,
                        orElse: () =>
                            FamilyUnit(id: '', name: 'Unknown', members: []),
                      );
                      return "${uMatch.name}: ${widget.selectedCurrency.symbol}${p.amountPaid.toStringAsFixed(0)}";
                    }).join(', ');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.title,
                                    style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.labelPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                    "Paid by [$payerSummary] • ${widget.selectedCurrency.symbol}${e.amount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.labelTertiary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.pencil,
                                size: 16, color: AppColors.labelSecondary),
                            onPressed: _isGeneratingAi
                                ? null
                                : () => _showAddOrEditExpenseSheet(context,
                                    expenseToEdit: e),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.trash,
                                size: 16, color: AppColors.redAccent),
                            onPressed: _isGeneratingAi
                                ? null
                                : () {
                                    setState(() {
                                      _expenses.removeWhere(
                                          (item) => item.id == e.id);
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
                icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
                title: "Nothing to settle yet",
                subtitle: "Add an expense and we'll work out who owes who.")
            : ReusableGlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: settlements.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: AppColors.green.withOpacity(0.16),
                                shape: BoxShape.circle),
                            child: const Icon(CupertinoIcons.arrow_up_right,
                                color: AppColors.green, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 15),
                                children: [
                                  TextSpan(
                                      text: s.from,
                                      style: const TextStyle(
                                          color: AppColors.labelPrimary,
                                          fontWeight: FontWeight.w600)),
                                  const TextSpan(
                                      text: "  owes  ",
                                      style: TextStyle(
                                          color: AppColors.labelTertiary)),
                                  TextSpan(
                                      text: s.to,
                                      style: const TextStyle(
                                          color: AppColors.labelPrimary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          Text(
                              "${widget.selectedCurrency.symbol}${s.amount.toStringAsFixed(2)}",
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
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isAiDisabled ? 0.4 : 1.0,
                child: ReusableButton(
                  label: _isGeneratingAi
                      ? "Summarizing..."
                      : (_isDataSaved && _latestAiSummary != null
                          ? "AI Summary Up to Date"
                          : "Summarize with Gemini AI"),
                  icon: CupertinoIcons.sparkles,
                  iconOnly: false,
                  color: AppColors.secondaryBg,
                  foreground: AppColors.green,
                  onPressed: isAiDisabled
                      ? null
                      : () {
                          _generateAiSummary(settlements);
                        },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_isGeneratingAi || _isDataSaved) ? 0.4 : 1.0,
                child: SaveSection(
                  isDataSaved: _isDataSaved,
                  isGeneratingAi: _isGeneratingAi,
                  onSave: (_isGeneratingAi || _isDataSaved)
                      ? null
                      : () {
                          _completeAndSaveSession(settlements);
                        },
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isGeneratingAi ? 0.4 : 1.0,
                child: ReusableButton(
                  label: "Export Settlement Report",
                  icon: CupertinoIcons.square_arrow_up_fill,
                  iconOnly: false,
                  color: AppColors.tertiaryBg,
                  foreground: AppColors.labelPrimary,
                  onPressed: _isGeneratingAi
                      ? null
                      : () {
                          _showExportBottomSheet(context, settlements);
                        },
                ),
              ),
            ],
          ),
        ],
        if (_units.isNotEmpty || _expenses.isNotEmpty) ...[
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isGeneratingAi ? 0.4 : 1.0,
            child: ReusableButton(
              label: "Remove Everything",
              icon: CupertinoIcons.trash,
              iconOnly: false,
              color: AppColors.redAccent,
              foreground: Colors.white,
              onPressed: _isGeneratingAi
                  ? null
                  : () {
                      _confirmClearAll();
                    },
            ),
          ),
        ],
      ],
    );
  }

  // --- DIALOGS AND BOTTOM SHEETS ---
  void _showAddPersonDialog() {
    _individualPersonController.clear();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    AppColors.secondaryBg.withOpacity(0.80),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.16),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add Person",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.labelPrimary,
                        letterSpacing: -0.3,
                      )),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _individualPersonController,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.labelPrimary),
                    decoration: InputDecoration(
                      hintText: "Enter person's name",
                      hintStyle: const TextStyle(
                          color: AppColors.labelTertiary, fontSize: 13.5),
                      filled: true,
                      fillColor: AppColors.labelPrimary.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.green, width: 1.4),
                      ),
                    ),
                    onSubmitted: (_) {
                      final name = _individualPersonController.text.trim();
                      if (name.isNotEmpty &&
                          !_individualPeople.contains(name)) {
                        setState(() {
                          _individualPeople.add(name);
                        });
                        _markDataChanged();
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel",
                            style: TextStyle(color: AppColors.labelSecondary)),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () {
                          final name = _individualPersonController.text.trim();
                          if (name.isNotEmpty &&
                              !_individualPeople.contains(name)) {
                            setState(() {
                              _individualPeople.add(name);
                            });
                            _markDataChanged();
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text("Add",
                            style: TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddIndividualExpenseSheet() {
    _indExpenseTitleController.clear();
    _indExpenseAmountController.clear();
    String selectedPayer = _individualPeople.first;
    Set<String> selectedParticipants = Set.from(_individualPeople);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          return ReusableBlurredSheet(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 12),
              child: SingleChildScrollView(
                child: Form(
                  key: _indExpenseFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetGrabber(),
                      const Text("Add Shared Expense",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.labelPrimary)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _indExpenseTitleController,
                        style: const TextStyle(color: AppColors.labelPrimary),
                        decoration: InputDecoration(
                          labelText: "Title (e.g. Snacks, Gas)",
                          labelStyle:
                              const TextStyle(color: AppColors.labelTertiary),
                          filled: true,
                          fillColor: AppColors.labelPrimary.withOpacity(0.04),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _indExpenseAmountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.labelPrimary),
                        decoration: InputDecoration(
                          labelText:
                              "Amount (${widget.selectedCurrency.symbol})",
                          labelStyle:
                              const TextStyle(color: AppColors.labelTertiary),
                          filled: true,
                          fillColor: AppColors.labelPrimary.withOpacity(0.04),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                        validator: (v) => double.tryParse(v ?? '') == null
                            ? "Enter valid amount"
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text("Who Paid?",
                          style: TextStyle(
                              color: AppColors.labelSecondary,
                              fontWeight: FontWeight.w600)),
                      DropdownButton<String>(
                        value: selectedPayer,
                        dropdownColor: AppColors.secondaryBg,
                        isExpanded: true,
                        items: _individualPeople.map((p) {
                          return DropdownMenuItem(
                              value: p,
                              child: Text(p,
                                  style: const TextStyle(
                                      color: AppColors.labelPrimary)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateModal(() => selectedPayer = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text("Split among:",
                          style: TextStyle(
                              color: AppColors.labelSecondary,
                              fontWeight: FontWeight.w600)),
                      ..._individualPeople.map((p) {
                        return CheckboxListTile(
                          title: Text(p,
                              style: const TextStyle(
                                  color: AppColors.labelPrimary)),
                          value: selectedParticipants.contains(p),
                          activeColor: AppColors.green,
                          checkColor: Colors.black,
                          dense: true,
                          onChanged: (val) {
                            setStateModal(() {
                              if (val == true) {
                                selectedParticipants.add(p);
                              } else {
                                selectedParticipants.remove(p);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 20),
                      ReusableButton(
                        label: "Save Expense",
                        icon: CupertinoIcons.check_mark,
                        onPressed: () {
                          if (!(_indExpenseFormKey.currentState?.validate() ??
                              false)) return;
                          if (selectedParticipants.isEmpty) {
                            _showTopSnackBar(
                                "Select at least 1 person to split.");
                            return;
                          }
                          final amt = double.parse(
                              _indExpenseAmountController.text.trim());
                          setState(() {
                            _individualExpenses.add(ExpenseEntry(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              title: _indExpenseTitleController.text.trim(),
                              amount: amt,
                              payers: [
                                ExpensePayerContribution(
                                    familyId: selectedPayer, amountPaid: amt)
                              ],
                              participatingFamilyIds:
                                  selectedParticipants.toList(),
                              participatingMemberNames:
                                  selectedParticipants.toList(),
                            ));
                          });
                          _markDataChanged();
                          Navigator.pop(ctx);
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
                const SizedBox(height: 6),
                const Text(
                  "A unit represents an individual, family, or subgroup sharing collective expenses.",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.labelSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _unitNameController,
                  style: const TextStyle(color: AppColors.labelPrimary),
                  decoration: InputDecoration(
                    labelText: "Unit / Group Name",
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
                    labelText: "Member Names",
                    hintText: "e.g. Alex, Sam, Taylor",
                    hintStyle: TextStyle(
                        color: AppColors.labelTertiary.withOpacity(0.5),
                        fontSize: 13.5),
                    helperText: "Separate multiple members with commas",
                    helperStyle: const TextStyle(
                        color: AppColors.labelTertiary, fontSize: 12),
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
                              "Total Amount (${widget.selectedCurrency.symbol})",
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
                                    hintText:
                                        "${widget.selectedCurrency.symbol}0.00",
                                    hintStyle: const TextStyle(
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
    final (effectiveUnits, effectiveExpenses, _) = _getEffectiveData();

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
                    units: effectiveUnits,
                    expenses: effectiveExpenses,
                    currencySymbol: widget.selectedCurrency.symbol,
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(CupertinoIcons.doc_text, color: Colors.white),
                title: const Text("Export as Document (.txt)"),
                onTap: () {
                  Navigator.pop(context);
                  ExpenseExportService.exportDocument(
                    settlements: settlements,
                    units: effectiveUnits,
                    expenses: effectiveExpenses,
                    currencySymbol: widget.selectedCurrency.symbol,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryHeroCard extends StatelessWidget {
  final double totalPool;
  final int unitCount;
  final int transferCount;
  final String currencySymbol;

  const _SummaryHeroCard({
    required this.totalPool,
    required this.unitCount,
    required this.transferCount,
    required this.currencySymbol,
  });

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
                _heroStat(CupertinoIcons.person_3_fill, "$unitCount", "People"),
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
