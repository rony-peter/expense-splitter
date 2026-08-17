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
          title: "Choose Your Currency",
          description:
              "Tap the currency badge in the footer anytime to instantly switch your preferred currency across the app.",
          icon: CupertinoIcons.money_dollar_circle_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "02",
          title: "Add Units & Members",
          description:
              "Tap 'Add Unit' to create participating groups or individuals (e.g., 'Family' or 'Roommates'). Optionally add comma-separated member names inside each unit.",
          icon: CupertinoIcons.house_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "03",
          title: "Log & Track Expenses",
          description:
              "Tap 'Add Expense' to record costs, specify payer contributions, and select which members participated in sharing each expense.",
          icon: CupertinoIcons.doc_text_fill,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "04",
          title: "AI Summaries & Settlements",
          description:
              "View instant, accurate settlement transfers on the fly. Tap 'Summarize with Gemini AI' to generate intelligent budgeting breakdowns.",
          icon: CupertinoIcons.sparkles,
        ),
        SizedBox(height: 16),
        _GuideStepCard(
          stepNumber: "05",
          title: "Save & Export Reports",
          description:
              "Save or update sessions locally on your device history page. Export clean PDF or text reports anytime to share with your group.",
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
