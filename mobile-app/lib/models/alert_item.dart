class AlertItem {
  const AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    this.acknowledged = false,
  });

  final String id;
  final String title;
  final String message;
  final String severity;
  final DateTime createdAt;
  final bool acknowledged;
}
