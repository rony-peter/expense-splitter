import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FloatingGlassFooter extends StatelessWidget {
  final String selectedCurrencySymbol;
  final VoidCallback? onCurrencyTap;
  final VoidCallback? onHomeTap;
  final VoidCallback onConverterTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onGuideTap;
  final bool isHome;
  final bool isConverterActive;
  final bool isHistoryActive;
  final bool isGuideActive;

  const FloatingGlassFooter({
    Key? key,
    required this.selectedCurrencySymbol,
    this.onCurrencyTap,
    this.onHomeTap,
    required this.onConverterTap,
    required this.onHistoryTap,
    required this.onGuideTap,
    this.isHome = true,
    this.isConverterActive = false,
    this.isHistoryActive = false,
    this.isGuideActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(36),
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
                  if (isHome)
                    _buildFooterButton(
                      onTap: onCurrencyTap ?? () {},
                      icon: CupertinoIcons.money_dollar_circle_fill,
                      label: selectedCurrencySymbol,
                      isPrimary: false,
                    )
                  else
                    _buildFooterButton(
                      onTap: onHomeTap ?? () {},
                      icon: CupertinoIcons.house_fill,
                      label: "Home",
                      isPrimary: false,
                    ),
                  _buildFooterButton(
                    onTap: onConverterTap,
                    icon: CupertinoIcons.arrow_right_arrow_left_square_fill,
                    label: "Convert",
                    isPrimary: isConverterActive,
                  ),
                  _buildFooterButton(
                    onTap: onHistoryTap,
                    icon: CupertinoIcons.time,
                    label: "History",
                    isPrimary: isHistoryActive,
                  ),
                  _buildFooterButton(
                    onTap: onGuideTap,
                    icon: CupertinoIcons.question_circle,
                    label: "Guide",
                    isPrimary: isGuideActive,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFFB6FF3D).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? const Color(0xFFB6FF3D) : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? const Color(0xFFB6FF3D) : Colors.white,
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
