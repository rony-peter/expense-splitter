import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'layouts/main_layout.dart';
import 'theme/app_theme.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  GoogleFonts.config.allowRuntimeFetching = false;
  await MobileAds.instance.initialize();
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
