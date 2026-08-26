import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_components.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 180),
      children: const [
        _GuideStepCard(
          stepNumber: "01",
          title: "Pick a Splitting Mode",
          description:
              "Choose 'Single Bill' for a quick one-off split, 'Individual Multi' for tracking several bills between friends, or 'Multi-Group' for splitting between families or larger groups. Switch modes anytime from the tabs.",
          icon: CupertinoIcons.square_grid_2x2_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "02",
          title: "Choose Your Currency",
          description:
              "Tap the currency badge in the footer anytime to instantly switch your preferred currency across the app.",
          icon: CupertinoIcons.money_dollar_circle_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "03",
          title: "Add People or Units",
          description:
              "In Individual Multi, tap 'Add Person' to bring people in. In Multi-Group, tap 'Add Unit' to create groups (e.g., 'Family' or 'Roommates') with optional comma-separated member names. You'll need at least 2 before you can start logging expenses.",
          icon: CupertinoIcons.person_2_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "04",
          title: "Log & Track Expenses",
          description:
              "Tap 'Add Expense' to record costs, specify how much each payer contributed, and select which members participated in sharing each expense.",
          icon: CupertinoIcons.doc_text_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "05",
          title: "View Instant Settlements",
          description:
              "As soon as you enter or edit an expense, settlements recalculate live — no need to leave the screen. You'll always see exactly who owes who, and how much.",
          icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "06",
          title: "Get an AI Summary",
          description:
              "Tap 'Summarize with Gemini AI' to generate a friendly, intelligent breakdown of your budget and spending patterns — powered by Google's Gemini API.",
          icon: CupertinoIcons.sparkles,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "07",
          title: "Save Your Session",
          description:
              "Save or update your split session locally on your device so you can revisit it later from the history page — even without an internet connection.",
          icon: CupertinoIcons.tray_arrow_down_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "08",
          title: "Export & Share",
          description:
              "Export a polished PDF report or a plain-text summary anytime, and share it straight to your group chat, email, or notes app.",
          icon: CupertinoIcons.square_arrow_up_fill,
        ),
      ],
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String description;
  final IconData icon;

  const _GuideStepCard({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ReusableGlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.green, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.labelPrimary,
                      ),
                    ),
                    Text(
                      stepNumber,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.labelSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
