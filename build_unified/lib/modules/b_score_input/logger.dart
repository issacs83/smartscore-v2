import 'package:intl/intl.dart';

/// Log levels for module logging.
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warn('WARN'),
  error('ERROR');

  final String label;
  const LogLevel(this.label);
}

/// A single log entry with structured metadata.
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String module;
  final String message;
  final Map<String, dynamic>? data;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.module,
    required this.message,
    this.data,
  });

  @override
  String toString() {
    final dataStr = data != null ? ' | data: ${data.toString()}' : '';
    return '[${_formatTime(timestamp)}] ${level.label} [$module] $message$dataStr';
  }

  String _formatTime(DateTime dt) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    return formatter.format(dt.toUtc());
  }
}

/// Module-wide logger with structured logging and history buffer.
///
/// Maintains a rotating buffer of the last 1000 log entries for debugging.
class ModuleLogger {
  static final ModuleLogger _instance = ModuleLogger._internal();
  static const int _maxBufferSize = 1000;

  final List<LogEntry> _buffer = [];

  ModuleLogger._internal();

  /// Gets the singleton instance.
  static ModuleLogger get instance => _instance;

  /// Logs a message with the given level.
  void log(
    LogLevel level,
    String module,
    String message, {
    Map<String, dynamic>? data,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now().toUtc(),
      level: level,
      module: module,
      message: message,
      data: data,
    );

    // Print to console
    print(entry.toString());

    // Add to buffer
    _buffer.add(entry);

    // Keep buffer size manageable
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeAt(0);
    }
  }

  /// Logs a debug message.
  void debug(String module, String message, {Map<String, dynamic>? data}) {
    log(LogLevel.debug, module, message, data: data);
  }

  /// Logs an info message.
  void info(String module, String message, {Map<String, dynamic>? data}) {
    log(LogLevel.info, module, message, data: data);
  }

  /// Logs a warning message.
  void warn(String module, String message, {Map<String, dynamic>? data}) {
    log(LogLevel.warn, module, message, data: data);
  }

  /// Logs an error message.
  void error(String module, String message, {Map<String, dynamic>? data}) {
    log(LogLevel.error, module, message, data: data);
  }

  /// Gets all log entries in the buffer.
  List<LogEntry> getBuffer() => List.unmodifiable(_buffer);

  /// Clears the log buffer.
  void clearBuffer() {
    _buffer.clear();
  }

  /// Gets recent log entries, up to [limit].
  List<LogEntry> getRecent({int limit = 100}) {
    final start = (_buffer.length - limit).clamp(0, _buffer.length);
    return _buffer.sublist(start);
  }

  /// Filters log entries by level.
  List<LogEntry> filterByLevel(LogLevel level) {
    return _buffer.where((e) => e.level == level).toList();
  }

  /// Filters log entries by module.
  List<LogEntry> filterByModule(String module) {
    return _buffer.where((e) => e.module == module).toList();
  }
}
