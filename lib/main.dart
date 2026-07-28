import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'models/expense_models.dart';
import 'services/export_service.dart';

// NOTE: This file intentionally defines its own UI primitives
// (buttons, cards, list rows) instead of importing
// widgets/reusable_components.dart, so it is fully self-contained.
// Your models/expense_models.dart and services/export_service.dart
// are used exactly as before — no changes needed there.

void main() {
  runApp(const ExpenseSplitterApp());
}

/// ---------------------------------------------------------------------------
/// Design tokens — matched to iOS 17/18 dark mode system colors, not generic
/// Material defaults. This is what makes it feel "native" rather than themed.
/// ---------------------------------------------------------------------------
class AppColors {
  static const bg = Color(0xFF000000);
  static const secondaryBg = Color(0xFF1C1C1E);
  static const tertiaryBg = Color(0xFF2C2C2E);
  static const separator = Color(0x1FFFFFFF); // white 12%
  static const labelPrimary = Colors.white;
  static const labelSecondary = Color(0x99FFFFFF); // white 60%
  static const labelTertiary = Color(0x59FFFFFF); // white 35%

  // Dark-mode system accent colors (these differ from light-mode iOS colors)
  static const blue = Color(0xFF0A84FF);
  static const green = Color(0xFF30D158);
  static const red = Color(0xFFFF453A);
  static const indigo = Color(0xFF5E5CE6);
  static const purple = Color(0xFFBF5AF2);
  static const orange = Color(0xFFFF9F0A);
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
          seedColor: AppColors.blue,
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

/// ---------------------------------------------------------------------------
/// PressableScale — the tactile "give" every iOS control has on touch-down.
/// Wrap anything tappable in this to make it feel alive.
/// ---------------------------------------------------------------------------
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;

  const PressableScale({
    Key? key,
    required this.child,
    this.onTap,
    this.scaleAmount = 0.96,
  }) : super(key: key);

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleAmount : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// PrimaryButton — filled iOS tinted button with icon + haptic feedback.
/// ---------------------------------------------------------------------------
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final bool expand;

  const PrimaryButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.blue,
    this.expand = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.55), color.withOpacity(0.24)],
              ),
              border: Border.all(color: color.withOpacity(0.55), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quieter, outlined variant used for secondary actions (e.g. list-row ListTiles).
class GhostRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const GhostRow({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scaleAmount: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.labelPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.labelTertiary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// GlassCard — refined glassmorphism container: continuous corners, subtle
/// inner top highlight (mimics specular light on real glass), softer blur.
/// ---------------------------------------------------------------------------
class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const GlassCard({
    Key? key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.only(bottom: 12),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.14),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: Colors.transparent,
                highlightColor: Colors.white.withOpacity(0.03),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single glass card whose body is a list of rows separated by hairline
/// dividers — this is the classic iOS "grouped list" look (Settings app),
/// which reads as far more premium than a stack of separate floating cards.
class GroupedGlassCard extends StatelessWidget {
  final List<Widget> rows;

  const GroupedGlassCard({Key? key, required this.rows}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              const Divider(
                height: 1,
                thickness: 0.6,
                color: AppColors.separator,
              ),
          ],
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// BlurredSheet — wraps bottom-sheet content in the same frosted-glass
/// material iOS uses for its own sheets/action sheets (like a UIBlurEffect),
/// so pop-ups match the rest of the app instead of being flat solid panels.
/// ---------------------------------------------------------------------------
class BlurredSheet extends StatelessWidget {
  final Widget child;
  final double radius;

  const BlurredSheet({Key? key, required this.child, this.radius = 28})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.09),
                AppColors.secondaryBg.withOpacity(0.80),
              ],
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.16), width: 1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// SectionHeader — small caps section title like iOS Settings groups.
/// ---------------------------------------------------------------------------
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionHeader({Key? key, required this.title, this.trailing})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppColors.labelSecondary,
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.labelTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// EmptyState — friendly, centered placeholder instead of a bare text line.
/// ---------------------------------------------------------------------------
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.labelSecondary, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.labelPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.labelTertiary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Avatar — colored initials circle, deterministic color from name hash.
/// ---------------------------------------------------------------------------
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const InitialsAvatar({Key? key, required this.name, this.size = 40})
    : super(key: key);

  static const _palette = [
    AppColors.blue,
    AppColors.indigo,
    AppColors.purple,
    AppColors.orange,
    AppColors.green,
  ];

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? "?"
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .map((e) => e[0])
              .take(2)
              .join()
              .toUpperCase();
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.6)],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class ExpenseHomeScreen extends StatefulWidget {
  const ExpenseHomeScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends State<ExpenseHomeScreen> {
  final List<FamilyUnit> _families = [];
  final List<ExpenseEntry> _expenses = [];

  final TextEditingController _familyNameController = TextEditingController();
  final TextEditingController _membersController = TextEditingController();

  final TextEditingController _expenseTitleController = TextEditingController();
  final TextEditingController _expenseAmountController =
      TextEditingController();
  String? _selectedPayerId;

  void _addFamily() {
    if (_familyNameController.text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _families.add(
        FamilyUnit(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _familyNameController.text.trim(),
          members: _membersController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
      );
      _familyNameController.clear();
      _membersController.clear();
    });
    Navigator.pop(context);
  }

  void _addExpense() {
    if (_expenseTitleController.text.isEmpty ||
        _expenseAmountController.text.isEmpty ||
        _selectedPayerId == null)
      return;

    HapticFeedback.lightImpact();
    setState(() {
      _expenses.add(
        ExpenseEntry(
          title: _expenseTitleController.text.trim(),
          paidByFamilyId: _selectedPayerId!,
          amount: double.tryParse(_expenseAmountController.text) ?? 0.0,
          participatingFamilyIds: _families.map((f) => f.id).toList(),
        ),
      );
      _expenseTitleController.clear();
      _expenseAmountController.clear();
      _selectedPayerId = null;
    });
    Navigator.pop(context);
  }

  List<SettlementTransfer> _calculateSettlements() {
    Map<String, double> netBalances = {};
    for (var f in _families) {
      netBalances[f.name] = 0.0;
    }

    for (var exp in _expenses) {
      String payerName = _families
          .firstWhere((f) => f.id == exp.paidByFamilyId)
          .name;
      netBalances[payerName] = (netBalances[payerName] ?? 0.0) + exp.amount;

      if (_families.isNotEmpty) {
        double splitAmount = exp.amount / _families.length;
        for (var f in _families) {
          netBalances[f.name] = (netBalances[f.name] ?? 0.0) - splitAmount;
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
      double amount = debtor.value < creditor.value
          ? debtor.value
          : creditor.value;

      transfers.add(
        SettlementTransfer(from: debtor.key, to: creditor.key, amount: amount),
      );

      debtors[i] = MapEntry(debtor.key, debtor.value - amount);
      creditors[j] = MapEntry(creditor.key, creditor.value - amount);

      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }

    return transfers;
  }

  double get _totalPool => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    final settlements = _calculateSettlements();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Ambient background wash — a full-bleed gradient instead of
          // hard-edged circles, so the atmosphere feels like moody lighting
          // rather than two visible blobs. Cool indigo top-left, a warm
          // amber undertone bottom-right, both fading to pure black.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -1.0),
                    radius: 1.3,
                    colors: [
                      AppColors.indigo.withOpacity(0.30),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.9, 0.5),
                    radius: 1.2,
                    colors: [
                      AppColors.orange.withOpacity(0.14),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.bg],
                    stops: const [0.3, 1.0],
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wallet-style hero summary card
                      _SummaryHeroCard(
                        totalPool: _totalPool,
                        familyCount: _families.length,
                        transferCount: settlements.length,
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: "Add Family",
                              icon: CupertinoIcons.person_add_solid,
                              onPressed: () => _showAddFamilyDialog(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: "Add Expense",
                              icon: CupertinoIcons.doc_text_fill,
                              color: AppColors.indigo,
                              onPressed: () => _showAddExpenseDialog(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      SectionHeader(
                        title: "Family Units",
                        trailing: _families.isEmpty
                            ? null
                            : "${_families.length}",
                      ),
                      _families.isEmpty
                          ? const EmptyState(
                              icon: CupertinoIcons.house_fill,
                              title: "No family units yet",
                              subtitle:
                                  "Tap “Add Family” to bring everyone into the split.",
                            )
                          : GroupedGlassCard(
                              rows: _families
                                  .map(
                                    (f) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          InitialsAvatar(name: f.name),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  f.name,
                                                  style: const TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.labelPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  f.members.isEmpty
                                                      ? "No members listed"
                                                      : f.members.join(', '),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color:
                                                        AppColors.labelTertiary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                      const SizedBox(height: 28),

                      SectionHeader(
                        title: "Settlements",
                        trailing: settlements.isEmpty
                            ? null
                            : "${settlements.length}",
                      ),
                      settlements.isEmpty
                          ? const EmptyState(
                              icon: CupertinoIcons
                                  .arrow_right_arrow_left_circle_fill,
                              title: "Nothing to settle yet",
                              subtitle:
                                  "Add an expense and we'll work out who owes who.",
                            )
                          : GroupedGlassCard(
                              rows: settlements
                                  .map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.green
                                                  .withOpacity(0.16),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              CupertinoIcons.arrow_up_right,
                                              color: AppColors.green,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: s.from,
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .labelPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const TextSpan(
                                                    text: "  owes  ",
                                                    style: TextStyle(
                                                      color: AppColors
                                                          .labelTertiary,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: s.to,
                                                    style: const TextStyle(
                                                      color: AppColors.blue,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "₹${s.amount.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.green,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),

                      if (settlements.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        PrimaryButton(
                          label: "Export Settlement Report",
                          icon: CupertinoIcons.square_arrow_up_fill,
                          color: AppColors.tertiaryBg,
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

  // ---------------------------------------------------------------------
  // Bottom sheets
  // ---------------------------------------------------------------------

  Widget _sheetGrabber() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        width: 36,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.labelTertiary,
        fontSize: 14.5,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
      ),
    );
  }

  void _showAddFamilyDialog(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlurredSheet(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetGrabber(),
              const Text(
                "Add Family Unit",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.labelPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _familyNameController,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration("Family Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _membersController,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration("Members (comma separated)"),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: "Save Family",
                icon: CupertinoIcons.check_mark,
                onPressed: _addFamily,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateModal) {
          final selectedFamily = _families
              .where((f) => f.id == _selectedPayerId)
              .toList();
          final selectedName = selectedFamily.isEmpty
              ? null
              : selectedFamily.first.name;

          return BlurredSheet(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetGrabber(),
                  const Text(
                    "Add Expense",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.labelPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _expenseTitleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration("Expense Title"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _expenseAmountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration("Total Amount (₹)"),
                  ),
                  const SizedBox(height: 12),

                  // Cupertino-style payer picker button
                  PressableScale(
                    scaleAmount: 0.98,
                    onTap: _families.isEmpty
                        ? null
                        : () => _showPayerPicker(context, setStateModal),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedName ?? "Select Payer",
                            style: TextStyle(
                              color: selectedName == null
                                  ? AppColors.labelTertiary
                                  : Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_down,
                            color: AppColors.labelTertiary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: "Save Expense",
                    icon: CupertinoIcons.check_mark,
                    onPressed: () {
                      _addExpense();
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
    int initialIndex = _families.indexWhere((f) => f.id == _selectedPayerId);
    if (initialIndex < 0) initialIndex = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int tempIndex = initialIndex;
        return BlurredSheet(
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
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: AppColors.labelSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setStateModal(() {
                            _selectedPayerId = _families[tempIndex].id;
                          });
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Done",
                          style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    backgroundColor: Colors.transparent,
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: initialIndex,
                    ),
                    onSelectedItemChanged: (i) => tempIndex = i,
                    children: _families
                        .map(
                          (f) => Center(
                            child: Text(
                              f.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        )
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
    BuildContext context,
    List<SettlementTransfer> settlements,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BlurredSheet(
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetGrabber(),
              const Text(
                "Export Options",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.labelPrimary,
                ),
              ),
              const SizedBox(height: 8),
              GhostRow(
                icon: CupertinoIcons.doc_richtext,
                iconColor: AppColors.red,
                title: "Export as PDF Report",
                subtitle: "Clean, printable summary",
                trailing: const Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.labelTertiary,
                  size: 16,
                ),
                onTap: () {
                  Navigator.pop(context);
                  ExpenseExportService.exportPdf(settlements: settlements);
                },
              ),
              GhostRow(
                icon: CupertinoIcons.doc_text,
                iconColor: AppColors.blue,
                title: "Export as Document (.txt)",
                subtitle: "Plain text, easy to paste anywhere",
                trailing: const Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.labelTertiary,
                  size: 16,
                ),
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

/// ---------------------------------------------------------------------------
/// Wallet-style hero summary card — total pool, families, pending transfers.
/// ---------------------------------------------------------------------------
class _SummaryHeroCard extends StatelessWidget {
  final double totalPool;
  final int familyCount;
  final int transferCount;

  const _SummaryHeroCard({
    required this.totalPool,
    required this.familyCount,
    required this.transferCount,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4B2E9E), // deep violet
                  AppColors.indigo,
                  AppColors.blue,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withOpacity(0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
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
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _heroStat(
                      CupertinoIcons.house_fill,
                      "$familyCount",
                      "Families",
                    ),
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
          // Diagonal glass sheen — a soft streak of light across the top-left
          // corner, the way premium cards (Apple Card, banking apps) catch
          // light without resorting to a literal circular highlight.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-1, -1),
                    end: const Alignment(0.2, 0.2),
                    colors: [
                      Colors.white.withOpacity(0.14),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Thin light edge — mimics the beveled rim of a physical card.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
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
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Collapsing large-title header: expands to a 34pt bold title, and as the
/// user scrolls it shrinks into a small pinned title with a blurred bar
/// behind it — the exact behavior of Messages / Mail / App Store on iOS.
/// ---------------------------------------------------------------------------
class _CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final double topPadding;

  _CollapsingHeaderDelegate({required this.title, required this.topPadding});

  double get _expandedExtra => 118.0;
  double get _collapsedExtra => 52.0;

  @override
  double get minExtent => _collapsedExtra + topPadding;

  @override
  double get maxExtent => _expandedExtra + topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final progress = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final largeTitleOpacity = (1 - progress * 1.7).clamp(0.0, 1.0);
    final smallTitleOpacity = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18 * progress, sigmaY: 18 * progress),
        child: Container(
          padding: EdgeInsets.only(top: topPadding),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6 * progress),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.08 * progress),
                width: 0.6,
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Opacity(
                  opacity: smallTitleOpacity,
                  child: Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Opacity(
                  opacity: largeTitleOpacity,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
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
  bool shouldRebuild(covariant _CollapsingHeaderDelegate oldDelegate) {
    return oldDelegate.title != title || oldDelegate.topPadding != topPadding;
  }
}
