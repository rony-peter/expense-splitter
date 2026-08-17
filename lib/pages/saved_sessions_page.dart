import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/expense_models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_components.dart';

class SavedSessionsPage extends StatefulWidget {
  const SavedSessionsPage({Key? key}) : super(key: key);

  @override
  State<SavedSessionsPage> createState() => _SavedSessionsPageState();
}

class _SavedSessionsPageState extends State<SavedSessionsPage> {
  List<SavedSplitSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await ExpenseStorageService.getSavedSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _deleteSession(String id) async {
    await ExpenseStorageService.deleteSession(id);
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.green))
        : _sessions.isEmpty
            ? const Center(
                child: Text(
                  "No saved split sessions found.",
                  style: TextStyle(color: AppColors.labelTertiary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 180),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  return ReusableGlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              session.dateString,
                              style: const TextStyle(
                                color: AppColors.labelSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                            Text(
                              "Pool: ₹${session.totalPool.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Units: ${session.units.map((u) => u.name).join(', ')}",
                          style: const TextStyle(
                            color: AppColors.labelPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (session.aiSummary != null &&
                            session.aiSummary!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.green.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.sparkles,
                                    size: 16, color: AppColors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    session.aiSummary!,
                                    style: const TextStyle(
                                      color: AppColors.labelPrimary,
                                      fontSize: 12.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _deleteSession(session.id),
                            icon: const Icon(CupertinoIcons.trash,
                                size: 14, color: AppColors.redAccent),
                            label: const Text("Delete",
                                style: TextStyle(
                                    color: AppColors.redAccent, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
  }
}
