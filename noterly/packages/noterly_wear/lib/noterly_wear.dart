import 'package:flutter/services.dart';

/// A command from the watch as it sits in the Data Layer.
class QueuedWearCommand {
  /// The DataItem URI, used to delete the command once it has been applied.
  final String uri;
  final String json;

  QueuedWearCommand(this.uri, this.json);
}

/// Dart side of the 'noterly/wear' channel. Every call is a no-op on devices without Google Play services.
class NoterlyWear {
  static const _channel = MethodChannel('noterly/wear');

  /// Replaces the snapshot DataItem the watch reads.
  static Future<void> sendSnapshot(String json) => _channel.invokeMethod('sendSnapshot', {'json': json});

  /// Commands the watch has queued and the phone has not deleted yet.
  static Future<List<QueuedWearCommand>> fetchCommands() async {
    final result = await _channel.invokeListMethod<Map>('fetchCommands') ?? [];
    return [for (final item in result) QueuedWearCommand(item['uri'] as String, item['json'] as String)];
  }

  static Future<void> deleteCommand(String uri) => _channel.invokeMethod('deleteCommand', {'uri': uri});

  /// Adds a bridge tag to shown notifications, so the watch can leave out the ones it already showed by itself.
  /// [tags] maps a notification ID to its tag.
  static Future<void> applyBridgeTags(Map<int, String> tags) =>
      _channel.invokeMethod('applyBridgeTags', {'tags': tags.map((key, value) => MapEntry(key.toString(), value))});

  /// Tells the native side the headless command run is finished, so its Flutter engine can be destroyed.
  static Future<void> headlessDone() => _channel.invokeMethod('headlessDone');
}
