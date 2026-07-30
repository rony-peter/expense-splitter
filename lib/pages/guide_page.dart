import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/reusable_components.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          "How to Use Expense Splitter",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.labelPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: const [
          _GuideStepCard(
            stepNumber: "01",
            title: "Choose Your Currency",
            description:
                "Tap the currency badge (e.g., ₹, \$, €) in the top-right header anytime to change your preferred currency across the entire app instantly.",
            icon: CupertinoIcons.money_dollar_circle_fill,
          ),
          SizedBox(height: 16),
          _GuideStepCard(
            stepNumber: "02",
            title: "Add Units & Members",
            description:
                "Tap 'Add Unit' to create groups or individuals taking part in the pool (e.g., 'Rony Family'). You can optionally add comma-separated member names inside each unit.",
            icon: CupertinoIcons.house_fill,
          ),
          SizedBox(height: 16),
          _GuideStepCard(
            stepNumber: "03",
            title: "Log Expenses",
            description:
                "Tap 'Add Expense' to record costs. Specify who paid how much, and choose which members participated in sharing that particular expense.",
            icon: CupertinoIcons.doc_text_fill,
          ),
          SizedBox(height: 16),
          _GuideStepCard(
            stepNumber: "04",
            title: "View Instant Settlements",
            description:
                "The app automatically calculates net balances on the fly, showing you exact transfer instructions (who owes who and how much).",
            icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
          ),
          SizedBox(height: 16),
          _GuideStepCard(
            stepNumber: "05",
            title: "Save or Export Reports",
            description:
                "Once balanced, you can save the split session locally to your device storage or export clean PDF and text reports to share with your group.",
            icon: CupertinoIcons.square_arrow_up_fill,
          ),
        ],
      ),
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
