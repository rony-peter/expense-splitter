import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/expense_models.dart';

class AIService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }
      return true;
    } catch (_) {
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
          'No Gemini API key configured. Add GEMINI_API_KEY to your .env file.');
    }

    final prompt = '''
    Analyze the following expense splitting data and provide a concise, friendly summary and financial insights (under 150 words):
    Currency: $currencySymbol
    Units/Groups: ${units.map((u) => '${u.name} (Members: ${u.members.join(', ')})').join('; ')}
    Expenses: ${expenses.map((e) => '${e.title}: $currencySymbol${e.amount}').join('; ')}
    Settlements: ${settlements.map((s) => '${s.from} owes ${s.to}: $currencySymbol${s.amount}').join('; ')}
    ''';

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
      } catch (_) {}
      throw HttpException(message);
    }
  }
}
