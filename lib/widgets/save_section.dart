import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import 'reusable_components.dart';

class SaveSection extends StatelessWidget {
  final bool isDataSaved;
  final bool isGeneratingAi;
  final VoidCallback? onSave;

  const SaveSection({
    Key? key,
    required this.isDataSaved,
    required this.isGeneratingAi,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReusableButton(
      label: isDataSaved ? "Saved to Phone" : "Save Split Session to Phone",
      icon: CupertinoIcons.floppy_disk,
      iconOnly: false,
      color: AppColors.green,
      foreground: Colors.black,
      onPressed: (isGeneratingAi || isDataSaved) ? () {} : onSave,
    );
  }
}
