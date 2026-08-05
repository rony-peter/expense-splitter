import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_models.dart';

class ExpenseStorageService {
  static const String _storageKey = 'saved_expense_split_sessions';

  static Future<void> saveSession(SavedSplitSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList(_storageKey) ?? [];

    // Remove existing session with the same ID to update it instead of creating a duplicate
    existing.removeWhere((item) {
      try {
        final decoded = jsonDecode(item);
        return decoded['id'] == session.id;
      } catch (_) {
        return false;
      }
    });

    existing.insert(0, jsonEncode(session.toJson()));
    await prefs.setStringList(_storageKey, existing);
  }

  static Future<List<SavedSplitSession>> getSavedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList(_storageKey) ?? [];
    return existing
        .map((item) => SavedSplitSession.fromJson(jsonDecode(item)))
        .toList();
  }

  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> existing = prefs.getStringList(_storageKey) ?? [];
    existing.removeWhere((item) {
      final decoded = jsonDecode(item);
      return decoded['id'] == id;
    });
    await prefs.setStringList(_storageKey, existing);
  }
}
