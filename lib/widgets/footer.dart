import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FloatingGlassFooter extends StatelessWidget {
  final String selectedCurrencySymbol;
  final VoidCallback onCurrencyTap; // Opens the Currency Selector picker
  final VoidCallback onConverterTap; // Opens the Currency Converter page
  final VoidCallback onHistoryTap;
  final VoidCallback onGuideTap;

  const FloatingGlassFooter({
    Key? key,
    required this.selectedCurrencySymbol,
    required this.onCurrencyTap,
    required this.onConverterTap,
    required this.onHistoryTap,
    required this.onGuideTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Adds horizontal padding to make the overall footer width smaller[cite: 4]
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36), // Fully rounded pill shape
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius:
                    BorderRadius.circular(36), // Fully rounded pill shape
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. Currency Selector Button (Primary symbol dropdown)[cite: 4]
                  _buildFooterButton(
                    onTap: onCurrencyTap,
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    label: selectedCurrencySymbol,
                    isPrimary: true,
                  ),
                  // 2. Currency Converter Page Button[cite: 4]
                  _buildFooterButton(
                    onTap: onConverterTap,
                    icon: CupertinoIcons.arrow_right_arrow_left_square_fill,
                    label: "Convert",
                  ),
                  // 3. Saved Sessions / History List Button[cite: 4]
                  _buildFooterButton(
                    onTap: onHistoryTap,
                    icon: CupertinoIcons.time,
                    label: "History",
                  ),
                  // 4. User Guide Button[cite: 4]
                  _buildFooterButton(
                    onTap: onGuideTap,
                    icon: CupertinoIcons.question_circle,
                    label: "Guide",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(24), // Fully rounded individual button
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? const Color(0xFF34C759) : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? const Color(0xFF34C759) : Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
