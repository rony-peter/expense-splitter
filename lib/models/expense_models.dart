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

class ExpenseEntry {
  final String id;
  final String title;
  final String paidByFamilyId;
  final double amount;
  final List<String> participatingFamilyIds;

  ExpenseEntry({
    required this.id,
    required this.title,
    required this.paidByFamilyId,
    required this.amount,
    required this.participatingFamilyIds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'paidByFamilyId': paidByFamilyId,
        'amount': amount,
        'participatingFamilyIds': participatingFamilyIds,
      };

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) => ExpenseEntry(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'],
        paidByFamilyId: json['paidByFamilyId'],
        amount: json['amount'],
        participatingFamilyIds:
            List<String>.from(json['participatingFamilyIds']),
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
        amount: json['amount'],
      );
}

class SavedSplitSession {
  final String id;
  final String dateString;
  final double totalPool;
  final List<FamilyUnit> units;
  final List<ExpenseEntry> expenses;
  final List<SettlementTransfer> settlements;

  SavedSplitSession({
    required this.id,
    required this.dateString,
    required this.totalPool,
    required this.units,
    required this.expenses,
    required this.settlements,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateString': dateString,
        'totalPool': totalPool,
        'units': units.map((u) => u.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'settlements': settlements.map((s) => s.toJson()).toList(),
      };

  factory SavedSplitSession.fromJson(Map<String, dynamic> json) =>
      SavedSplitSession(
        id: json['id'],
        dateString: json['dateString'],
        totalPool: json['totalPool'],
        units:
            (json['units'] as List).map((u) => FamilyUnit.fromJson(u)).toList(),
        expenses: (json['expenses'] as List)
            .map((e) => ExpenseEntry.fromJson(e))
            .toList(),
        settlements: (json['settlements'] as List)
            .map((s) => SettlementTransfer.fromJson(s))
            .toList(),
      );
}
