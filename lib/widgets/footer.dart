import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FloatingGlassFooter extends StatelessWidget {
  final String selectedCurrencySymbol;
  final VoidCallback onCurrencyTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onGuideTap;

  const FloatingGlassFooter({
    Key? key,
    required this.selectedCurrencySymbol,
    required this.onCurrencyTap,
    required this.onHistoryTap,
    required this.onGuideTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent, // Fully transparent background with blur
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Currency Selection Button
              _buildFooterButton(
                onTap: onCurrencyTap,
                icon: CupertinoIcons.money_dollar_circle_fill,
                label: selectedCurrencySymbol,
                isPrimary: true,
              ),
              const VerticalDivider(
                color: Colors.white24,
                thickness: 1,
                indent: 8,
                endIndent: 8,
              ),
              // Saved Sessions / History List Button
              _buildFooterButton(
                onTap: onHistoryTap,
                icon: CupertinoIcons.time,
                label: "History",
              ),
              const VerticalDivider(
                color: Colors.white24,
                thickness: 1,
                indent: 8,
                endIndent: 8,
              ),
              // User Guide Button
              _buildFooterButton(
                onTap: onGuideTap,
                icon: CupertinoIcons.question_circle,
                label: "Guide",
              ),
            ],
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
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? const Color(0xFF34C759) : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? const Color(0xFF34C759) : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
