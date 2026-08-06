import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../constants/currency_codes.dart';
import '../pages/home_page.dart';
import '../pages/currency_converter_page.dart';
import '../pages/saved_sessions_page.dart';
import '../pages/guide_page.dart';
import '../theme/app_theme.dart';
import '../widgets/footer.dart';
import '../widgets/reusable_components.dart';

enum AppTab { home, converter, history, guide }

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  AppTab _currentTab = AppTab.home;
  CurrencyOption _selectedCurrency = CurrencyConstants.currencies[0];
  Key _historyKey = UniqueKey();

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
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.labelPrimary.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const Text(
                "Select Currency",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.labelPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: CurrencyConstants.currencies.length,
                  itemBuilder: (context, index) {
                    final curr = CurrencyConstants.currencies[index];
                    final isSelected = curr.code == _selectedCurrency.code;
                    return ListTile(
                      title: Text(
                        "${curr.name} (${curr.code})",
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.green
                              : AppColors.labelPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        curr.symbol,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? AppColors.green
                              : AppColors.labelSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  String get _appBarTitle {
    switch (_currentTab) {
      case AppTab.converter:
        return "Currency Converter";
      case AppTab.history:
        return "Saved Split Sessions";
      case AppTab.guide:
        return "How to Use Expense Splitter";
      case AppTab.home:
      default:
        return "";
    }
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _currentTab.index,
      children: [
        ExpenseHomePage(
          selectedCurrency: _selectedCurrency,
          onCurrencyChanged: (curr) => setState(() => _selectedCurrency = curr),
          onOpenCurrencyPicker: _showCurrencyPicker,
        ),
        const CurrencyConverterPage(),
        SavedSessionsPage(key: _historyKey),
        const GuidePage(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _currentTab == AppTab.home
          ? null
          : AppBar(
              title: Text(_appBarTitle),
              leading: IconButton(
                icon: const Icon(CupertinoIcons.back,
                    color: AppColors.labelPrimary),
                onPressed: () => setState(() => _currentTab = AppTab.home),
              ),
            ),
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
          _buildBody(),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FloatingGlassFooter(
              selectedCurrencySymbol: _selectedCurrency.symbol,
              isHome: _currentTab == AppTab.home,
              isConverterActive: _currentTab == AppTab.converter,
              isHistoryActive: _currentTab == AppTab.history,
              isGuideActive: _currentTab == AppTab.guide,
              onCurrencyTap: _showCurrencyPicker,
              onHomeTap: () => setState(() => _currentTab = AppTab.home),
              onConverterTap: () =>
                  setState(() => _currentTab = AppTab.converter),
              onHistoryTap: () => setState(() {
                _currentTab = AppTab.history;
                _historyKey =
                    UniqueKey(); // Refreshes saved history list when opened
              }),
              onGuideTap: () => setState(() => _currentTab = AppTab.guide),
            ),
          ),
        ],
      ),
    );
  }
}
