class FamilyUnit {
  final String id;
  final String name;
  final List<String> members;

  FamilyUnit({required this.id, required this.name, required this.members});
}

class ExpenseEntry {
  final String title;
  final String paidByFamilyId;
  final double amount;
  final List<String> participatingFamilyIds;

  ExpenseEntry({
    required this.title,
    required this.paidByFamilyId,
    required this.amount,
    required this.participatingFamilyIds,
  });
}

class SettlementTransfer {
  final String from;
  final String to;
  final double amount;

  SettlementTransfer({required this.from, required this.to, required this.amount});
}