class MortNotificationItem {
  const MortNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
    this.createdAt,
    this.data = const {},
  });

  final String id;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  bool get isUnread => readAt == null;

  factory MortNotificationItem.fromMap(Map<String, dynamic> json) {
    return MortNotificationItem(
      id: json['id'].toString(),
      title: (json['title'] as String?) ?? 'MORT',
      body: (json['body'] as String?) ?? '',
      readAt: DateTime.tryParse((json['read_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
    );
  }
}
