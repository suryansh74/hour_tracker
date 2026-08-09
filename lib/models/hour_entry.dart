/// A single logged hour slot.
///
/// [date] is stored as 'yyyy-MM-dd' and [hour] as 0-23, together they
/// uniquely identify a slot (see DB unique index on date+hour).
class HourEntry {
  final int? id;
  final String date;
  final int hour;
  final int? categoryId;
  final String note;
  final String loggedAt; // ISO8601 timestamp of when the entry was actually saved
  final bool snoozed;

  HourEntry({
    this.id,
    required this.date,
    required this.hour,
    this.categoryId,
    this.note = '',
    required this.loggedAt,
    this.snoozed = false,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'hour': hour,
      'categoryId': categoryId,
      'note': note,
      'loggedAt': loggedAt,
      'snoozed': snoozed ? 1 : 0,
    };
  }

  factory HourEntry.fromMap(Map<String, Object?> map) {
    return HourEntry(
      id: map['id'] as int?,
      date: map['date'] as String,
      hour: map['hour'] as int,
      categoryId: map['categoryId'] as int?,
      note: (map['note'] as String?) ?? '',
      loggedAt: map['loggedAt'] as String,
      snoozed: (map['snoozed'] as int? ?? 0) == 1,
    );
  }
}
