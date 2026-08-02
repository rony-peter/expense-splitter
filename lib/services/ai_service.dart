import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../models/expense_models.dart';

class AIService {
  // Get a free key at https://aistudio.google.com/apikey — it should look
  // like "AIzaSy...". Pass it in at build/run time rather than committing
  // a real key here:
  //   flutter run --dart-define=GEMINI_API_KEY=your_key_here
  static const String _apiKey = String.fromEnvironment('AQ.Ab8RN6Lckc_Fk25AaPnjzHrzgb588kqc3fMWbBwb63mIdWE_NA');

  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  static Future<String> summarizeBudget({
    required List<FamilyUnit> units,
    required List<ExpenseEntry> expenses,
    required List<SettlementTransfer> settlements,
    required String currencySymbol,
  }) async {
    final connected = await hasInternetConnection();
    if (!connected) {
      throw const SocketException(
          'No internet connection. Please switch on your network.');
    }

    if (_apiKey.isEmpty) {
      throw const HttpException(
          'No Gemini API key configured. Get a free one at aistudio.google.com/apikey and run with --dart-define=GEMINI_API_KEY=your_key.');
    }

    final prompt = '''
    Analyze the following expense splitting data and provide a concise, friendly summary and financial insights (under 150 words):
    Currency: $currencySymbol
    Units/Groups: ${units.map((u) => '${u.name} (Members: ${u.members.join(', ')})').join('; ')}
    Expenses: ${expenses.map((e) => '${e.title}: $currencySymbol${e.amount}').join('; ')}
    Settlements: ${settlements.map((s) => '${s.from} owes ${s.to}: $currencySymbol${s.amount}').join('; ')}
    ''';

    // gemini-1.5-flash was fully shut down — all requests to it now return
    // 404. gemini-2.5-flash is the current stable model (retiring no
    // earlier than Oct 16, 2026; check ai.google.dev/gemini-api/docs/deprecations
    // if this stops working later).
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        return data['candidates'][0]['content']['parts'][0]['text'] ??
            'No summary available.';
      } catch (_) {
        return 'No summary available.';
      }
    } else {
      String message = 'Failed to generate summary (${response.statusCode}).';
      try {
        final data = jsonDecode(response.body);
        final apiMessage = data['error']?['message'];
        if (apiMessage is String && apiMessage.isNotEmpty) {
          message = apiMessage;
        }
      } catch (_) {
        // Response wasn't JSON — fall back to the generic message above.
      }
      throw HttpException(message);
    }
  }
}
