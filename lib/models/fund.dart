class Fund {
  final String id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String description;
  final String? eventId; // Optional, if tied to an event
  final DateTime date;

  Fund({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.eventId,
    required this.date,
  });

  factory Fund.fromMap(Map<String, dynamic> data, String documentId) {
    return Fund(
      id: documentId,
      type: data['type'] ?? 'income',
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      eventId: data['event_id'],
      date: data['date'] != null
          ? (data['date'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'description': description,
      if (eventId != null) 'event_id': eventId,
      'date': date,
    };
  }
}
