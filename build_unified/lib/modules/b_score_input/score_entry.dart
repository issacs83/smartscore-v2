import 'package:uuid/uuid.dart';

/// Version type enum for score versions.
enum VersionType {
  originalImage('original_image'),
  restoredImage('restored_image'),
  omrMusicxml('omr_musicxml'),
  omrScoreJson('omr_score_json'),
  userEditedScoreJson('user_edited_score_json');

  final String label;
  const VersionType(this.label);

  /// Gets the file extension for this version type.
  String get fileExtension {
    return switch (this) {
      VersionType.originalImage => '.png',
      VersionType.restoredImage => '.png',
      VersionType.omrMusicxml => '.xml',
      VersionType.omrScoreJson => '.json',
      VersionType.userEditedScoreJson => '.json',
    };
  }

  /// Converts string to VersionType.
  static VersionType? fromLabel(String label) {
    try {
      return VersionType.values.firstWhere((e) => e.label == label);
    } catch (e) {
      return null;
    }
  }
}

/// Source type enum for score imports.
enum SourceType {
  pdf('pdf'),
  image('image'),
  musicxml('musicxml'),
  manualJson('manual_json');

  final String label;
  const SourceType(this.label);

  static SourceType? fromLabel(String label) {
    try {
      return SourceType.values.firstWhere((e) => e.label == label);
    } catch (e) {
      return null;
    }
  }
}

/// Metadata for a score version.
class VersionInfo {
  /// File path or content identifier.
  final String filePath;

  /// When this version was created.
  final DateTime createdAt;

  /// Size in bytes.
  final int sizeBytes;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  VersionInfo({
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
    this.metadata,
  });

  /// Converts to JSON for persistence.
  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'metadata': metadata,
  };

  /// Creates from JSON.
  factory VersionInfo.fromJson(Map<String, dynamic> json) => VersionInfo(
    filePath: json['filePath'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    sizeBytes: json['sizeBytes'] as int,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VersionInfo &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath &&
          createdAt == other.createdAt &&
          sizeBytes == other.sizeBytes &&
          metadata == other.metadata;

  @override
  int get hashCode =>
      filePath.hashCode ^ createdAt.hashCode ^ sizeBytes.hashCode ^ metadata.hashCode;
}

/// A single score entry in the library.
class ScoreEntry {
  /// Unique identifier (UUID v4).
  final String id;

  /// Score title (1-256 chars, non-empty).
  final String title;

  /// Composer name (0-256 chars, may be empty).
  final String? composer;

  /// How the score was originally imported.
  final SourceType sourceType;

  /// All versions of this score, keyed by VersionType.
  final Map<VersionType, VersionInfo> versions;

  /// When this entry was created.
  final DateTime createdAt;

  /// When this entry was last updated.
  final DateTime updatedAt;

  ScoreEntry({
    String? id,
    required this.title,
    this.composer,
    required this.sourceType,
    Map<VersionType, VersionInfo>? versions,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        versions = versions ?? {},
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc() {
    _validate();
  }

  /// Validates the score entry.
  ///
  /// Throws [ArgumentError] if validation fails.
  void _validate() {
    if (title.isEmpty || title.length > 256) {
      throw ArgumentError('Title must be 1-256 characters');
    }
    if (composer != null && composer!.length > 256) {
      throw ArgumentError('Composer must be 0-256 characters');
    }
    if (!_isValidUuid(id)) {
      throw ArgumentError('ID must be a valid UUID v4');
    }
  }

  /// Validates the score entry, returning any errors.
  ///
  /// Returns null if valid, error message otherwise.
  String? validate() {
    if (title.isEmpty || title.length > 256) {
      return 'Title must be 1-256 characters';
    }
    if (composer != null && composer!.length > 256) {
      return 'Composer must be 0-256 characters';
    }
    if (!_isValidUuid(id)) {
      return 'ID must be a valid UUID v4';
    }
    return null;
  }

  /// Adds or replaces a version.
  ScoreEntry addVersion(VersionType type, VersionInfo info) {
    return copyWith(
      versions: {...versions, type: info},
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Gets a version by type.
  VersionInfo? getVersion(VersionType type) => versions[type];

  /// Gets all version types that exist for this score.
  List<VersionType> getAvailableVersions() => versions.keys.toList();

  /// Creates a copy with optional field overrides.
  ScoreEntry copyWith({
    String? id,
    String? title,
    String? composer,
    SourceType? sourceType,
    Map<VersionType, VersionInfo>? versions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ScoreEntry(
        id: id ?? this.id,
        title: title ?? this.title,
        composer: composer ?? this.composer,
        sourceType: sourceType ?? this.sourceType,
        versions: versions ?? this.versions,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Converts to JSON for persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'composer': composer,
    'sourceType': sourceType.label,
    'versions': {
      for (final entry in versions.entries)
        entry.key.label: entry.value.toJson()
    },
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Creates from JSON.
  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    final versionsMap = <VersionType, VersionInfo>{};
    final versions = json['versions'] as Map<String, dynamic>?;
    if (versions != null) {
      versions.forEach((key, value) {
        final type = VersionType.fromLabel(key);
        if (type != null) {
          versionsMap[type] = VersionInfo.fromJson(value as Map<String, dynamic>);
        }
      });
    }

    return ScoreEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      composer: json['composer'] as String?,
      sourceType: SourceType.fromLabel(json['sourceType'] as String) ?? SourceType.pdf,
      versions: versionsMap,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Validates UUID v4 format (36 chars, lowercase hex with dashes).
  static bool _isValidUuid(String value) {
    if (value.length != 36) return false;
    final pattern = RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$');
    return pattern.hasMatch(value.toLowerCase());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          composer == other.composer &&
          sourceType == other.sourceType &&
          versions == other.versions &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      composer.hashCode ^
      sourceType.hashCode ^
      versions.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() => 'ScoreEntry(id: $id, title: $title, composer: $composer, sourceType: $sourceType)';
}
