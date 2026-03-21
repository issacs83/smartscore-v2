/// Input conflict resolution and debouncing.
///
/// Takes a stream of raw [DeviceEvent] from multiple adapters,
/// applies debounce and priority filtering, and emits a single
/// deduplicated stream of [DeviceAction].

import 'dart:async';
import 'device_action.dart';

/// Logs events and decisions for debugging and metrics.
abstract class PrioritizerLogger {
  /// Log that an event was accepted and emitted as an action.
  void logAccepted(
    DeviceEvent event,
    DeviceAction action,
    String reason,
  );

  /// Log that an event was rejected.
  void logRejected(
    DeviceEvent event,
    String reason,
  );
}

/// Simple in-memory logger implementation.
class DefaultPrioritizerLogger implements PrioritizerLogger {
  static const int maxHistorySize = 100;
  final List<String> _history = [];

  @override
  void logAccepted(DeviceEvent event, DeviceAction action, String reason) {
    final entry = '[${event.timestamp.toIso8601String()}] '
        'ACCEPTED: ${event.source} -> $action (reason: $reason)';
    _addToHistory(entry);
  }

  @override
  void logRejected(DeviceEvent event, String reason) {
    final entry = '[${event.timestamp.toIso8601String()}] '
        'REJECTED: ${event.source} action ${event.action} (reason: $reason)';
    _addToHistory(entry);
  }

  void _addToHistory(String entry) {
    _history.add(entry);
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// Get the full log history.
  List<String> getHistory() => List.unmodifiable(_history);

  /// Clear the log history.
  void clear() => _history.clear();
}

/// Manages input conflict resolution and debouncing.
///
/// Implements:
/// - Debounce: ignore same action from same source within 150ms
/// - Priority: when conflicting events arrive within 200ms window, highest priority wins
/// - Logging: every decision logged with timestamp, source, action, reason
///
/// Priority order (highest to lowest):
/// 1. touch
/// 2. bluetoothPedal
/// 3. midiController
/// 4. keyboard
class InputPrioritizer {
  /// Priority order: lower index = higher priority
  static const priorityOrder = [
    DeviceType.touch,
    DeviceType.bluetoothPedal,
    DeviceType.midiController,
    DeviceType.keyboard,
  ];

  /// Debounce window: ignore same action from same source within this duration
  static const debounceWindow = Duration(milliseconds: 150);

  /// Priority window: consider events within this duration as conflicting
  static const priorityWindow = Duration(milliseconds: 200);

  final PrioritizerLogger logger;
  final StreamController<DeviceAction> _actionController;

  /// Maps (source, action) -> last emission time for debouncing
  final Map<({DeviceType source, DeviceAction action}), DateTime> _lastEmission =
      {};

  /// Maps action -> last event time for priority conflict detection
  final Map<DeviceAction, ({DateTime time, DeviceType source})> _lastActionTime =
      {};

  InputPrioritizer({PrioritizerLogger? logger})
      : logger = logger ?? DefaultPrioritizerLogger(),
        _actionController = StreamController<DeviceAction>.broadcast();

  /// Stream of processed device actions.
  Stream<DeviceAction> get onAction => _actionController.stream;

  /// Process a raw device event and emit an action if it passes all filters.
  void processEvent(DeviceEvent event) {
    final key = (source: event.source, action: event.action);
    final now = event.timestamp;

    // Check debounce: same action from same source
    final lastEmissionTime = _lastEmission[key];
    if (lastEmissionTime != null &&
        now.difference(lastEmissionTime) < debounceWindow) {
      logger.logRejected(
        event,
        'Debounced: same action from same source within ${debounceWindow.inMilliseconds}ms',
      );
      return;
    }

    // Check priority: conflicting actions within priority window
    final lastAction = _lastActionTime[event.action];
    if (lastAction != null &&
        now.difference(lastAction.time) < priorityWindow) {
      // There's a recent conflicting action from another source
      // Check if this event's source has higher priority
      final currentPriority =
          priorityOrder.indexOf(event.source);
      final lastPriority = priorityOrder.indexOf(lastAction.source);

      if (currentPriority > lastPriority) {
        // Lower priority source trying to emit after higher priority source
        logger.logRejected(
          event,
          'Rejected by priority: ${lastAction.source} (priority ${lastPriority}) '
              'already emitted within ${priorityWindow.inMilliseconds}ms',
        );
        return;
      }
    }

    // Event passes all filters - emit it
    _lastEmission[key] = now;
    _lastActionTime[event.action] = (time: now, source: event.source);

    _actionController.add(event.action);
    logger.logAccepted(event, event.action, 'Passed all filters');
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    await _actionController.close();
  }
}
