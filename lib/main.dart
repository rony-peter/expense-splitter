import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'layouts/main_layout.dart';
import 'theme/app_theme.dart';

// Access your environment variable anywhere in the app like this:
const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow runtime fetching on web so Google Fonts won't crash
  if (!kIsWeb) {
    GoogleFonts.config.allowRuntimeFetching = false;
    await MobileAds.instance.initialize();
  }

  runApp(const ExpenseSplitterApp());
}

class ExpenseSplitterApp extends StatelessWidget {
  const ExpenseSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Splitter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainLayout(),
    );
  }
}
