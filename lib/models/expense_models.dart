class FamilyUnit {
  final String id;
  final String name;
  final List<String> members;

  FamilyUnit({
    required this.id,
    required this.name,
    required this.members,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'members': members};

  factory FamilyUnit.fromJson(Map<String, dynamic> json) => FamilyUnit(
        id: json['id'],
        name: json['name'],
        members: List<String>.from(json['members']),
      );
}

class ExpensePayerContribution {
  final String familyId;
  final double amountPaid;

  ExpensePayerContribution({
    required this.familyId,
    required this.amountPaid,
  });

  Map<String, dynamic> toJson() => {
        'familyId': familyId,
        'amountPaid': amountPaid,
      };

  factory ExpensePayerContribution.fromJson(Map<String, dynamic> json) =>
      ExpensePayerContribution(
        familyId: json['familyId'],
        amountPaid: (json['amountPaid'] as num).toDouble(),
      );
}

class ExpenseEntry {
  final String id;
  final String title;
  final List<ExpensePayerContribution> payers;
  final double amount;
  final List<String> participatingFamilyIds;
  final List<String> participatingMemberNames;

  ExpenseEntry({
    required this.id,
    required this.title,
    required this.payers,
    required this.amount,
    required this.participatingFamilyIds,
    required this.participatingMemberNames,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'payers': payers.map((p) => p.toJson()).toList(),
        'amount': amount,
        'participatingFamilyIds': participatingFamilyIds,
        'participatingMemberNames': participatingMemberNames,
      };

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) => ExpenseEntry(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'],
        payers: json['payers'] != null
            ? (json['payers'] as List)
                .map((p) => ExpensePayerContribution.fromJson(p))
                .toList()
            : [
                ExpensePayerContribution(
                  familyId: json['paidByFamilyId'] ?? '',
                  amountPaid: (json['amount'] as num?)?.toDouble() ?? 0.0,
                )
              ],
        amount: (json['amount'] as num).toDouble(),
        participatingFamilyIds:
            List<String>.from(json['participatingFamilyIds'] ?? []),
        participatingMemberNames:
            List<String>.from(json['participatingMemberNames'] ?? []),
      );
}

class SettlementTransfer {
  final String from;
  final String to;
  final double amount;

  SettlementTransfer(
      {required this.from, required this.to, required this.amount});

  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'amount': amount};

  factory SettlementTransfer.fromJson(Map<String, dynamic> json) =>
      SettlementTransfer(
        from: json['from'],
        to: json['to'],
        amount: (json['amount'] as num).toDouble(),
      );
}

class SavedSplitSession {
  final String id;
  final String dateString;
  final double totalPool;
  final List<FamilyUnit> units;
  final List<ExpenseEntry> expenses;
  final List<SettlementTransfer> settlements;
  final String? aiSummary; // Added field

  SavedSplitSession({
    required this.id,
    required this.dateString,
    required this.totalPool,
    required this.units,
    required this.expenses,
    required this.settlements,
    this.aiSummary,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateString': dateString,
        'totalPool': totalPool,
        'units': units.map((u) => u.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'settlements': settlements.map((s) => s.toJson()).toList(),
        'aiSummary': aiSummary,
      };

  factory SavedSplitSession.fromJson(Map<String, dynamic> json) =>
      SavedSplitSession(
        id: json['id'],
        dateString: json['dateString'],
        totalPool: (json['totalPool'] as num).toDouble(),
        units:
            (json['units'] as List).map((u) => FamilyUnit.fromJson(u)).toList(),
        expenses: (json['expenses'] as List)
            .map((e) => ExpenseEntry.fromJson(e))
            .toList(),
        settlements: (json['settlements'] as List)
            .map((s) => SettlementTransfer.fromJson(s))
            .toList(),
        aiSummary: json['aiSummary'],
      );
}
