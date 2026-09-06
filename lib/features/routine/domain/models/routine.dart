class Routine {
  const Routine({
    required this.routineId,
    required this.anonymousId,
    required this.name,
    required this.isActive,
    this.description,
    this.scheduledTime,
    this.recurrence,
  });

  final String routineId;
  final String anonymousId;

  final String name;
  final String? description;
  final String? scheduledTime;
  final String? recurrence;

  final bool isActive;

  Routine copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    String? scheduledTime,
    bool clearScheduledTime = false,
    String? recurrence,
    bool clearRecurrence = false,
    bool? isActive,
  }) {
    return Routine(
      routineId: routineId,
      anonymousId: anonymousId,
      name: name ?? this.name,
      description: clearDescription ? null : description ?? this.description,
      scheduledTime: clearScheduledTime
          ? null
          : scheduledTime ?? this.scheduledTime,
      recurrence: clearRecurrence ? null : recurrence ?? this.recurrence,
      isActive: isActive ?? this.isActive,
    );
  }
}
