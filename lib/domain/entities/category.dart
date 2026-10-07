enum CategoryType { expense, income }

class FinanceCategory {
  final String id;
  final String name;
  final CategoryType type;
  final String icon;

  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
  });
}
