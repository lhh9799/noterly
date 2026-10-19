import 'package:flutter/material.dart';
import 'package:noterly/models/repetition_data.dart';

class NotificationItem {
  String id;

  String title;
  String body;

  Color colour;

  DateTime? dateTime;
  RepetitionData? repetitionData;

  bool archived;
  DateTime? archivedDateTime;

  DateTime? snoozeDateTime;

  /// Whether the notification can be swiped away. Dismissing it does not mark the reminder as done.
  bool dismissible;

  /// When the item was last changed, used to settle edits made on the watch and the phone at the same time. Null for
  /// items saved before the watch app existed.
  DateTime? updatedAt;

  bool get isImmediate => dateTime == null;

  bool get isScheduled => dateTime != null;

  bool get isRepeating => repetitionData != null;

  bool get isNotRepeating => repetitionData == null;

  bool get isSnoozed => snoozeDateTime != null;

  bool get isNotSnoozed => snoozeDateTime == null;

  bool get isSnoozedPast => snoozeDateTime != null && snoozeDateTime!.isBefore(DateTime.now());

  bool get isSnoozedFuture => snoozeDateTime != null && snoozeDateTime!.isAfter(DateTime.now());

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.dateTime,
    this.repetitionData,
    required this.colour,
    this.archived = false,
    this.archivedDateTime,
    this.snoozeDateTime,
    this.dismissible = false,
    this.updatedAt,
  });

  @override
  String toString() {
    return 'NotificationItem(id: $id, title: $title, body: $body, dateTime: $dateTime, repetitionData: $repetitionData, colour: $colour, archived: $archived, archivedDateTime: $archivedDateTime, snoozeDateTime: $snoozeDateTime, dismissible: $dismissible, updatedAt: $updatedAt)';
  }

  DateTime get nextRepeatDateTime {
    if (repetitionData == null) return DateTime.now();

    // Return the datetime at which the notification should be sent next. Base it off the last time it was sent.
    return repetitionData!.nextDateTime(dateTime ?? DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'dateTime': dateTime?.toIso8601String(),
        'repetitionData': repetitionData?.toJson(),
        'colour': colour.value,
        'archived': archived,
        'archivedDateTime': archivedDateTime?.toIso8601String(),
        'snoozeDateTime': snoozeDateTime?.toIso8601String(),
        'dismissible': dismissible,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'],
        title: json['title'],
        body: json['body'],
        dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : null,
        repetitionData: json['repetitionData'] != null ? RepetitionData.fromJson(json['repetitionData']) : null,
        colour: Color(json['colour']),
        archived: json['archived'] ?? false,
        archivedDateTime: json['archivedDateTime'] != null ? DateTime.parse(json['archivedDateTime']) : null,
        snoozeDateTime: json['snoozeDateTime'] != null ? DateTime.parse(json['snoozeDateTime']) : null,
        dismissible: json['dismissible'] ?? false,
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      );
}
