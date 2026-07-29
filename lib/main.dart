import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'models/expense_models.dart';
import 'services/export_service.dart';
import 'services/storage_service.dart';
import 'widgets/reusable_components.dart';

void main() {
  runApp(const ExpenseSplitterApp());
}

class ExpenseSplitterApp extends StatelessWidget {
  const ExpenseSplitterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Splitter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: '.SF Pro Text',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        cardColor: AppColors.secondaryBg,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const ExpenseHomeScreen(),
    );
  }
}

class ExpenseHomeScreen extends StatefulWidget {
  const ExpenseHomeScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends State<ExpenseHomeScreen> {
  final List<FamilyUnit> _units = [];
  final List<ExpenseEntry> _expenses = [];

  final TextEditingController _unitNameController = TextEditingController();
  final TextEditingController _membersController = TextEditingController();

  final TextEditingController _expenseTitleController = TextEditingController();
  final TextEditingController _expenseAmountController =
      TextEditingController();
  String? _selectedPayerId;

  // Add or Edit Unit
  void _saveUnit({String? editId}) {
    if (_unitNameController.text.isEmpty) return;
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
    Navigator.pop(context);
  }

  // Add or Edit Expense
  void _saveExpense({String? editId}) {
    if (_expenseTitleController.text.isEmpty ||
        _expenseAmountController.text.isEmpty ||
        _selectedPayerId == null) return;

    HapticFeedback.lightImpact();
    setState(() {
      if (editId != null) {
        int index = _expenses.indexWhere((e) => e.id == editId);
        if (index >= 0) {
          _expenses[index] = ExpenseEntry(
            id: editId,
            title: _expenseTitleController.text.trim(),
            paidByFamilyId: _selectedPayerId!,
            amount: double.tryParse(_expenseAmountController.text) ?? 0.0,
            participatingFamilyIds: _units.map((u) => u.id).toList(),
          );
        }
      } else {
        _expenses.add(
          ExpenseEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: _expenseTitleController.text.trim(),
            paidByFamilyId: _selectedPayerId!,
            amount: double.tryParse(_expenseAmountController.text) ?? 0.0,
            participatingFamilyIds: _units.map((u) => u.id).toList(),
          ),
        );
      }
      _expenseTitleController.clear();
      _expenseAmountController.clear();
      _selectedPayerId = null;
    });
    Navigator.pop(context);
  }

  double _getUnitTotalPaid(String unitId) {
    return _expenses
        .where((e) => e.paidByFamilyId == unitId)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  List<SettlementTransfer> _calculateSettlements() {
    Map<String, double> netBalances = {};
    for (var u in _units) {
      netBalances[u.name] = 0.0;
    }

    int totalMembersCount = 0;
    for (var u in _units) {
      int memberCount = u.members.isEmpty ? 1 : u.members.length;
      totalMembersCount += memberCount;
    }

    for (var exp in _expenses) {
      String payerName = _units
          .firstWhere((u) => u.id == exp.paidByFamilyId,
              orElse: () => FamilyUnit(id: '', name: 'Unknown', members: []))
          .name;
      if (payerName == 'Unknown') continue;
      netBalances[payerName] = (netBalances[payerName] ?? 0.0) + exp.amount;

      if (totalMembersCount > 0) {
        double perHeadAmount = exp.amount / totalMembersCount;
        for (var u in _units) {
          int memberCount = u.members.isEmpty ? 1 : u.members.length;
          double unitShare = perHeadAmount * memberCount;
          netBalances[u.name] = (netBalances[u.name] ?? 0.0) - unitShare;
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
    final session = SavedSplitSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateString: DateTime.now().toString().substring(0, 16),
      totalPool: _totalPool,
      units: List.from(_units),
      expenses: List.from(_expenses),
      settlements: settlements,
    );
    await ExpenseStorageService.saveSession(session);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Split session successfully saved to phone storage!")),
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
                  onHistoryTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SavedSessionsPage()),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryHeroCard(
                        totalPool: _totalPool,
                        unitCount: _units.length,
                        transferCount: settlements.length,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ReusableButton(
                              label: "Add Unit",
                              icon: CupertinoIcons.person_add_solid,
                              onPressed: () => _showAddOrEditUnitSheet(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ReusableButton(
                              label: "Add Expense",
                              icon: CupertinoIcons.doc_text_fill,
                              color: AppColors.tertiaryBg,
                              foreground: Colors.white,
                              onPressed: () =>
                                  _showAddOrEditExpenseSheet(context),
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
                                                  "Paid: ₹${totalPaid.toStringAsFixed(2)} • ${u.members.isEmpty ? 'No members' : u.members.join(', ')}",
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
                                          onPressed: () =>
                                              _showAddOrEditUnitSheet(context,
                                                  unitToEdit: u),
                                        ),
                                        IconButton(
                                          icon: const Icon(CupertinoIcons.trash,
                                              size: 16,
                                              color: AppColors.redAccent),
                                          onPressed: () {
                                            setState(() {
                                              _units.removeWhere(
                                                  (item) => item.id == u.id);
                                              _expenses.removeWhere((e) =>
                                                  e.paidByFamilyId == u.id);
                                            });
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
                                        Text("₹${s.amount.toStringAsFixed(2)}",
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
                        ReusableButton(
                          label: "Save Split Session to Phone",
                          icon: CupertinoIcons.floppy_disk,
                          color: AppColors.green,
                          foreground: Colors.black,
                          onPressed: () => _completeAndSaveSession(settlements),
                        ),
                        const SizedBox(height: 12),
                        ReusableButton(
                          label: "Export Settlement Report",
                          icon: CupertinoIcons.square_arrow_up_fill,
                          color: AppColors.tertiaryBg,
                          foreground: AppColors.labelPrimary,
                          onPressed: () =>
                              _showExportBottomSheet(context, settlements),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
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
              ReusableTextField(
                  controller: _unitNameController,
                  label: "Unit Name (e.g. Rony)"),
              const SizedBox(height: 12),
              ReusableTextField(
                  controller: _membersController,
                  label: "Members (comma separated)"),
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
    );
  }

  void _showAddOrEditExpenseSheet(BuildContext context,
      {ExpenseEntry? expenseToEdit}) {
    if (expenseToEdit != null) {
      _expenseTitleController.text = expenseToEdit.title;
      _expenseAmountController.text = expenseToEdit.amount.toString();
      _selectedPayerId = expenseToEdit.paidByFamilyId;
    } else {
      _expenseTitleController.clear();
      _expenseAmountController.clear();
      _selectedPayerId = null;
    }

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateModal) {
          final selectedUnit =
              _units.where((u) => u.id == _selectedPayerId).toList();
          final selectedName =
              selectedUnit.isEmpty ? null : selectedUnit.first.name;

          return ReusableBlurredSheet(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetGrabber(),
                  Text(expenseToEdit == null ? "Add Expense" : "Edit Expense",
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.labelPrimary,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 18),
                  ReusableTextField(
                      controller: _expenseTitleController,
                      label: "Expense Title"),
                  const SizedBox(height: 12),
                  ReusableTextField(
                      controller: _expenseAmountController,
                      label: "Total Amount (₹)",
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  PressableScale(
                    scaleAmount: 0.98,
                    onTap: _units.isEmpty
                        ? null
                        : () => _showPayerPicker(context, setStateModal),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                          color: AppColors.labelPrimary.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedName ?? "Select Payer",
                              style: TextStyle(
                                  color: selectedName == null
                                      ? AppColors.labelTertiary
                                      : AppColors.labelPrimary,
                                  fontSize: 15)),
                          const Icon(CupertinoIcons.chevron_down,
                              color: AppColors.labelTertiary, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ReusableButton(
                    label: expenseToEdit == null
                        ? "Save Expense"
                        : "Update Expense",
                    icon: CupertinoIcons.check_mark,
                    onPressed: () {
                      _saveExpense(editId: expenseToEdit?.id);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPayerPicker(BuildContext context, StateSetter setStateModal) {
    int initialIndex = _units.indexWhere((u) => u.id == _selectedPayerId);
    if (initialIndex < 0) initialIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int tempIndex = initialIndex;
        return ReusableBlurredSheet(
          radius: 24,
          child: SizedBox(
            height: 260,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel",
                              style:
                                  TextStyle(color: AppColors.labelSecondary))),
                      TextButton(
                        onPressed: () {
                          setStateModal(
                              () => _selectedPayerId = _units[tempIndex].id);
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        child: const Text("Done",
                            style: TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    backgroundColor: Colors.transparent,
                    itemExtent: 40,
                    scrollController:
                        FixedExtentScrollController(initialItem: initialIndex),
                    onSelectedItemChanged: (i) => tempIndex = i,
                    children: _units
                        .map((u) => Center(
                            child: Text(u.name,
                                style: const TextStyle(
                                    color: AppColors.labelPrimary,
                                    fontSize: 17))))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                  ExpenseExportService.exportPdf(settlements: settlements);
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
  late Future<List<SavedSplitSession>> _futureSessions;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() {
      _futureSessions = ExpenseStorageService.getSavedSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Saved Split Sessions"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<SavedSplitSession>>(
        future: _futureSessions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.green));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text("No saved split sessions found.",
                    style: TextStyle(color: AppColors.labelTertiary)));
          }
          final sessions = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ReusableGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(session.dateString,
                            style: const TextStyle(
                                color: AppColors.labelTertiary, fontSize: 12)),
                        IconButton(
                          icon: const Icon(CupertinoIcons.trash,
                              color: AppColors.redAccent, size: 18),
                          onPressed: () async {
                            await ExpenseStorageService.deleteSession(
                                session.id);
                            _loadSessions();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text("Total Pool: ₹${session.totalPool.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        "Units: ${session.units.length} | Transfers: ${session.settlements.length}",
                        style: const TextStyle(
                            color: AppColors.labelSecondary, fontSize: 13)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryHeroCard extends StatelessWidget {
  final double totalPool;
  final int unitCount;
  final int transferCount;

  const _SummaryHeroCard({
    required this.totalPool,
    required this.unitCount,
    required this.transferCount,
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
          border: Border.all(
            color: Colors.white.withOpacity(0.16),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TOTAL POOLED",
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "₹${totalPool.toStringAsFixed(2)}",
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _heroStat(CupertinoIcons.house_fill, "$unitCount", "Units"),
                const SizedBox(width: 24),
                _heroStat(
                  CupertinoIcons.arrow_right_arrow_left,
                  "$transferCount",
                  "To Settle",
                ),
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
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final double topPadding;
  final VoidCallback onHistoryTap;

  _CollapsingHeaderDelegate(
      {required this.title,
      required this.topPadding,
      required this.onHistoryTap});

  @override
  double get minExtent => 52.0 + topPadding;
  @override
  double get maxExtent => 118.0 + topPadding;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final progress = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18 * progress, sigmaY: 18 * progress),
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
                right: 16,
                top: 8,
                child: IconButton(
                  icon: const Icon(CupertinoIcons.time, color: AppColors.green),
                  onPressed: onHistoryTap,
                  tooltip: "View Saved Splits",
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.labelPrimary,
                    fontSize: 32 - (progress * 15),
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
  bool shouldRebuild(covariant _CollapsingHeaderDelegate oldDelegate) => true;
}
