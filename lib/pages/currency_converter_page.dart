import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import '../constants/currency_codes.dart';
import '../widgets/reusable_components.dart';

class CurrencyConverterPage extends StatefulWidget {
  const CurrencyConverterPage({Key? key}) : super(key: key);

  @override
  State<CurrencyConverterPage> createState() => _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
  final TextEditingController _amountController =
      TextEditingController(text: '1.0');
  String _fromCurrency = 'USD';
  String _toCurrency = 'INR';

  final Map<String, double> _rates = CurrencyConstants.defaultExchangeRates;

  double get _convertedAmount {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    double baseUsd = amount / (_rates[_fromCurrency] ?? 1.0);
    return baseUsd * (_rates[_toCurrency] ?? 1.0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: [
          ReusableGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Amount",
                    style: TextStyle(
                        color: AppColors.labelSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      color: AppColors.labelPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ReusableGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("From",
                          style: TextStyle(
                              color: AppColors.labelSecondary, fontSize: 12)),
                      DropdownButton<String>(
                        value: _fromCurrency,
                        dropdownColor: AppColors.secondaryBg,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            color: AppColors.labelPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        items: _rates.keys.map((code) {
                          return DropdownMenuItem(
                              value: code, child: Text(code));
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _fromCurrency = val!),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(CupertinoIcons.arrow_right,
                    color: AppColors.labelSecondary),
              ),
              Expanded(
                child: ReusableGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("To",
                          style: TextStyle(
                              color: AppColors.labelSecondary, fontSize: 12)),
                      DropdownButton<String>(
                        value: _toCurrency,
                        dropdownColor: AppColors.secondaryBg,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            color: AppColors.labelPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        items: _rates.keys.map((code) {
                          return DropdownMenuItem(
                              value: code, child: Text(code));
                        }).toList(),
                        onChanged: (val) => setState(() => _toCurrency = val!),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          ReusableGlassCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Text("Converted Amount",
                      style: TextStyle(
                          color: AppColors.labelSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    "${_convertedAmount.toStringAsFixed(2)} $_toCurrency",
                    style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 32,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
