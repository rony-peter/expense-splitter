import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  // Static mock exchange rates relative to USD
  final Map<String, double> _rates = {
    'USD': 1.0,
    'INR': 83.0,
    'EUR': 0.92,
    'GBP': 0.78,
    'CAD': 1.36,
    'AUD': 1.50,
    'AED': 3.67,
    'SGD': 1.35,
    'JPY': 155.0,
  };

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Currency Converter",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.labelPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
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
                          onChanged: (val) =>
                              setState(() => _toCurrency = val!),
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
      ),
    );
  }
}
