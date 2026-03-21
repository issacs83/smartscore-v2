import 'dart:math' as math;

/// Validation error for Score.validate()
class ValidationError {
  final String category;
  final String message;
  final String? path;

  ValidationError({
    required this.category,
    required this.message,
    this.path,
  });

  @override
  String toString() => 'ValidationError($category): $message${path != null ? ' at $path' : ''}';
}

/// Immutable Score JSON root object
class Score {
  final String id;
  final String title;
  final String composer;
  final List<Part> parts;
  final ScoreMetadata metadata;

  const Score({
    required this.id,
    required this.title,
    required this.composer,
    required this.parts,
    required this.metadata,
  });

  /// Validates score structure, completeness, and consistency
  List<ValidationError> validate() {
    final errors = <ValidationError>[];

    // Validate UUID format
    if (!_isValidUuid(id)) {
      errors.add(ValidationError(
        category: 'UUID',
        message: 'Invalid UUID format for score id',
        path: 'id',
      ));
    }

    // Validate title
    if (title.isEmpty || title.length > 256) {
      errors.add(ValidationError(
        category: 'Title',
        message: 'Title must be 1-256 characters',
        path: 'title',
      ));
    }

    // Validate composer length
    if (composer.length > 256) {
      errors.add(ValidationError(
        category: 'Composer',
        message: 'Composer must be 0-256 characters',
        path: 'composer',
      ));
    }

    // Validate parts
    if (parts.isEmpty) {
      errors.add(ValidationError(
        category: 'Parts',
        message: 'Score must have at least 1 part',
        path: 'parts',
      ));
    }

    for (int i = 0; i < parts.length; i++) {
      errors.addAll(parts[i].validate('parts[$i]'));
    }

    return errors;
  }

  static bool _isValidUuid(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }

  factory Score.fromJson(Map<String, dynamic> json) {
    return Score(
      id: json['id'] as String,
      title: json['title'] as String,
      composer: json['composer'] as String? ?? '',
      parts: (json['parts'] as List)
          .map((p) => Part.fromJson(p as Map<String, dynamic>))
          .toList(),
      metadata: ScoreMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'composer': composer,
      'parts': parts.map((p) => p.toJson()).toList(),
      'metadata': metadata.toJson(),
    };
  }

  Score copyWith({
    String? id,
    String? title,
    String? composer,
    List<Part>? parts,
    ScoreMetadata? metadata,
  }) {
    return Score(
      id: id ?? this.id,
      title: title ?? this.title,
      composer: composer ?? this.composer,
      parts: parts ?? this.parts,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Immutable Part object
class Part {
  final String id;
  final String name;
  final InstrumentType instrumentType;
  final int staveCount;
  final List<Measure> measures;

  const Part({
    required this.id,
    required this.name,
    required this.instrumentType,
    required this.staveCount,
    required this.measures,
  });

  List<ValidationError> validate(String path) {
    final errors = <ValidationError>[];

    if (id.isEmpty) {
      errors.add(ValidationError(
        category: 'Part.id',
        message: 'Part id cannot be empty',
        path: '$path.id',
      ));
    }

    if (name.isEmpty) {
      errors.add(ValidationError(
        category: 'Part.name',
        message: 'Part name cannot be empty',
        path: '$path.name',
      ));
    }

    if (staveCount < 1 || staveCount > 3) {
      errors.add(ValidationError(
        category: 'Part.staveCount',
        message: 'staveCount must be 1-3',
        path: '$path.staveCount',
      ));
    }

    if (measures.isEmpty) {
      errors.add(ValidationError(
        category: 'Part.measures',
        message: 'Part must have at least 1 measure',
        path: '$path.measures',
      ));
    }

    for (int i = 0; i < measures.length; i++) {
      errors.addAll(measures[i].validate('$path.measures[$i]'));
    }

    return errors;
  }

  factory Part.fromJson(Map<String, dynamic> json) {
    return Part(
      id: json['id'] as String,
      name: json['name'] as String,
      instrumentType: InstrumentType.fromString(json['instrumentType'] as String),
      staveCount: json['staveCount'] as int,
      measures: (json['measures'] as List)
          .map((m) => Measure.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'instrumentType': instrumentType.value,
      'staveCount': staveCount,
      'measures': measures.map((m) => m.toJson()).toList(),
    };
  }

  Part copyWith({
    String? id,
    String? name,
    InstrumentType? instrumentType,
    int? staveCount,
    List<Measure>? measures,
  }) {
    return Part(
      id: id ?? this.id,
      name: name ?? this.name,
      instrumentType: instrumentType ?? this.instrumentType,
      staveCount: staveCount ?? this.staveCount,
      measures: measures ?? this.measures,
    );
  }
}

/// Enumeration of instrument types
enum InstrumentType {
  violin('violin'),
  viola('viola'),
  cello('cello'),
  bass('bass'),
  flute('flute'),
  oboe('oboe'),
  clarinet('clarinet'),
  bassoon('bassoon'),
  horn('horn'),
  trumpet('trumpet'),
  trombone('trombone'),
  tuba('tuba'),
  piano('piano'),
  organ('organ'),
  harp('harp'),
  percussion('percussion'),
  timpani('timpani'),
  xylophone('xylophone'),
  voice('voice'),
  soprano('soprano'),
  alto('alto'),
  tenor('tenor'),
  bassVoice('bass_voice'),
  guitar('guitar'),
  banjo('banjo'),
  ukulele('ukulele'),
  generic('generic');

  final String value;

  const InstrumentType(this.value);

  factory InstrumentType.fromString(String value) {
    try {
      return InstrumentType.values.firstWhere(
        (type) => type.value == value.toLowerCase(),
      );
    } catch (e) {
      return InstrumentType.generic;
    }
  }

  /// Handle common instrument name variations
  factory InstrumentType.fromName(String name) {
    final normalized = name.toLowerCase().trim();

    // String instruments
    if (normalized.contains('violin')) return InstrumentType.violin;
    if (normalized.contains('viola')) return InstrumentType.viola;
    if (normalized.contains('cello')) return InstrumentType.cello;
    if (normalized.contains('bass') && !normalized.contains('trombone')) {
      return InstrumentType.bass;
    }

    // Woodwinds
    if (normalized.contains('flute')) return InstrumentType.flute;
    if (normalized.contains('oboe')) return InstrumentType.oboe;
    if (normalized.contains('clarinet')) return InstrumentType.clarinet;
    if (normalized.contains('bassoon')) return InstrumentType.bassoon;

    // Brass
    if (normalized.contains('horn')) return InstrumentType.horn;
    if (normalized.contains('trumpet')) return InstrumentType.trumpet;
    if (normalized.contains('trombone')) return InstrumentType.trombone;
    if (normalized.contains('tuba')) return InstrumentType.tuba;

    // Keyboards
    if (normalized.contains('piano')) return InstrumentType.piano;
    if (normalized.contains('organ')) return InstrumentType.organ;
    if (normalized.contains('harp')) return InstrumentType.harp;

    // Percussion
    if (normalized.contains('timpani')) return InstrumentType.timpani;
    if (normalized.contains('xylophone')) return InstrumentType.xylophone;
    if (normalized.contains('percussion')) return InstrumentType.percussion;

    // Voice
    if (normalized.contains('soprano')) return InstrumentType.soprano;
    if (normalized.contains('alto')) return InstrumentType.alto;
    if (normalized.contains('tenor')) return InstrumentType.tenor;
    if (normalized == 'bass' || normalized.contains('bass voice')) {
      return InstrumentType.bassVoice;
    }
    if (normalized.contains('voice') || normalized.contains('vocal')) {
      return InstrumentType.voice;
    }

    // Plucked
    if (normalized.contains('guitar')) return InstrumentType.guitar;
    if (normalized.contains('banjo')) return InstrumentType.banjo;
    if (normalized.contains('ukulele')) return InstrumentType.ukulele;

    return InstrumentType.generic;
  }
}

/// Immutable Measure object
class Measure {
  final int number;
  final List<Element> elements;
  final String? timeSignature;
  final KeySignature? keySignature;
  final int? tempo;
  final String? rehearsalMark;
  final bool repeatStart;
  final bool repeatEnd;
  final List<Clef> clefs;

  const Measure({
    required this.number,
    required this.elements,
    this.timeSignature,
    this.keySignature,
    this.tempo,
    this.rehearsalMark,
    this.repeatStart = false,
    this.repeatEnd = false,
    this.clefs = const [],
  });

  List<ValidationError> validate(String path) {
    final errors = <ValidationError>[];

    if (number < 0) {
      errors.add(ValidationError(
        category: 'Measure.number',
        message: 'Measure number must be non-negative',
        path: '$path.number',
      ));
    }

    if (timeSignature != null && !_isValidTimeSignature(timeSignature!)) {
      errors.add(ValidationError(
        category: 'Measure.timeSignature',
        message: 'Invalid time signature format',
        path: '$path.timeSignature',
      ));
    }

    if (tempo != null && (tempo! < 30 || tempo! > 300)) {
      errors.add(ValidationError(
        category: 'Measure.tempo',
        message: 'Tempo must be 30-300 BPM',
        path: '$path.tempo',
      ));
    }

    for (int i = 0; i < elements.length; i++) {
      errors.addAll(elements[i].validate('$path.elements[$i]'));
    }

    return errors;
  }

  static bool _isValidTimeSignature(String ts) {
    final parts = ts.split('/');
    if (parts.length != 2) return false;
    try {
      int.parse(parts[0]);
      int.parse(parts[1]);
      return true;
    } catch (e) {
      return false;
    }
  }

  factory Measure.fromJson(Map<String, dynamic> json) {
    return Measure(
      number: json['number'] as int,
      elements: (json['elements'] as List)
          .map((e) => Element.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeSignature: json['timeSignature'] as String?,
      keySignature: json['keySignature'] != null
          ? KeySignature.fromJson(json['keySignature'] as Map<String, dynamic>)
          : null,
      tempo: json['tempo'] as int?,
      rehearsalMark: json['rehearsalMark'] as String?,
      repeatStart: json['repeatStart'] as bool? ?? false,
      repeatEnd: json['repeatEnd'] as bool? ?? false,
      clefs: (json['clefs'] as List?)
              ?.map((c) => Clef.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'elements': elements.map((e) => e.toJson()).toList(),
      if (timeSignature != null) 'timeSignature': timeSignature,
      if (keySignature != null) 'keySignature': keySignature!.toJson(),
      if (tempo != null) 'tempo': tempo,
      if (rehearsalMark != null) 'rehearsalMark': rehearsalMark,
      if (repeatStart) 'repeatStart': repeatStart,
      if (repeatEnd) 'repeatEnd': repeatEnd,
      if (clefs.isNotEmpty) 'clefs': clefs.map((c) => c.toJson()).toList(),
    };
  }

  Measure copyWith({
    int? number,
    List<Element>? elements,
    String? timeSignature,
    KeySignature? keySignature,
    int? tempo,
    String? rehearsalMark,
    bool? repeatStart,
    bool? repeatEnd,
    List<Clef>? clefs,
  }) {
    return Measure(
      number: number ?? this.number,
      elements: elements ?? this.elements,
      timeSignature: timeSignature ?? this.timeSignature,
      keySignature: keySignature ?? this.keySignature,
      tempo: tempo ?? this.tempo,
      rehearsalMark: rehearsalMark ?? this.rehearsalMark,
      repeatStart: repeatStart ?? this.repeatStart,
      repeatEnd: repeatEnd ?? this.repeatEnd,
      clefs: clefs ?? this.clefs,
    );
  }
}

/// Immutable KeySignature object
class KeySignature {
  final String step;
  final String tonality;
  final int alterations;

  const KeySignature({
    required this.step,
    required this.tonality,
    required this.alterations,
  });

  factory KeySignature.fromJson(Map<String, dynamic> json) {
    return KeySignature(
      step: json['step'] as String,
      tonality: json['tonality'] as String,
      alterations: json['alterations'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'tonality': tonality,
      'alterations': alterations,
    };
  }

  KeySignature copyWith({
    String? step,
    String? tonality,
    int? alterations,
  }) {
    return KeySignature(
      step: step ?? this.step,
      tonality: tonality ?? this.tonality,
      alterations: alterations ?? this.alterations,
    );
  }
}

/// Immutable Clef object
class Clef {
  final String sign;
  final int line;
  final int staff;

  const Clef({
    required this.sign,
    required this.line,
    required this.staff,
  });

  factory Clef.fromJson(Map<String, dynamic> json) {
    return Clef(
      sign: json['sign'] as String,
      line: json['line'] as int,
      staff: json['staff'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sign': sign,
      'line': line,
      'staff': staff,
    };
  }

  Clef copyWith({
    String? sign,
    int? line,
    int? staff,
  }) {
    return Clef(
      sign: sign ?? this.sign,
      line: line ?? this.line,
      staff: staff ?? this.staff,
    );
  }
}

/// Immutable Pitch object with MIDI and frequency computation
class Pitch {
  final String step;
  final int octave;
  final int alter;

  const Pitch({
    required this.step,
    required this.octave,
    this.alter = 0,
  });

  /// Compute MIDI note number (C4 = 60)
  int get midiNumber {
    const stepValues = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final baseValue = stepValues[step] ?? 0;
    return 12 * (octave + 1) + baseValue + alter;
  }

  /// Compute frequency in Hz (A4 = 440.0 Hz)
  double get frequency {
    const a4Frequency = 440.0;
    const a4Midi = 69;
    final semitonesDifference = midiNumber - a4Midi;
    return a4Frequency * pow(2.0, semitonesDifference / 12.0);
  }

  factory Pitch.fromJson(Map<String, dynamic> json) {
    return Pitch(
      step: json['step'] as String,
      octave: json['octave'] as int,
      alter: json['alter'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'octave': octave,
      'alter': alter,
    };
  }

  Pitch copyWith({
    String? step,
    int? octave,
    int? alter,
  }) {
    return Pitch(
      step: step ?? this.step,
      octave: octave ?? this.octave,
      alter: alter ?? this.alter,
    );
  }
}

/// Helper function for pow calculation
double pow(double base, double exponent) {
  return math.pow(base, exponent) as double;
}

/// Base abstract class for all Element types
abstract class Element {
  const Element();

  List<ValidationError> validate(String path);

  factory Element.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'note':
        return NoteElement.fromJson(json);
      case 'rest':
        return RestElement.fromJson(json);
      case 'direction':
        return DirectionElement.fromJson(json);
      default:
        throw ArgumentError('Unknown element type: $type');
    }
  }

  Map<String, dynamic> toJson();
}

/// Immutable NoteElement object
class NoteElement extends Element {
  final Pitch pitch;
  final int duration;
  final String noteType;
  final int voice;
  final int staff;
  final int dots;
  final bool isChordMember;
  final List<String> articulations;
  final Tie? tie;
  final Slur? slur;
  final String? dynamicMarking;
  final String? text;

  const NoteElement({
    required this.pitch,
    required this.duration,
    required this.noteType,
    required this.voice,
    required this.staff,
    this.dots = 0,
    this.isChordMember = false,
    this.articulations = const [],
    this.tie,
    this.slur,
    this.dynamicMarking,
    this.text,
  });

  @override
  List<ValidationError> validate(String path) {
    final errors = <ValidationError>[];

    if (duration < 1) {
      errors.add(ValidationError(
        category: 'NoteElement.duration',
        message: 'Duration must be at least 1',
        path: '$path.duration',
      ));
    }

    if (octave < 0 || octave > 8) {
      errors.add(ValidationError(
        category: 'Pitch.octave',
        message: 'Octave must be 0-8',
        path: '$path.pitch.octave',
      ));
    }

    if (dots < 0 || dots > 3) {
      errors.add(ValidationError(
        category: 'NoteElement.dots',
        message: 'Dots must be 0-3',
        path: '$path.dots',
      ));
    }

    if (voice < 0 || voice > 3) {
      errors.add(ValidationError(
        category: 'NoteElement.voice',
        message: 'Voice must be 0-3',
        path: '$path.voice',
      ));
    }

    if (staff < 0) {
      errors.add(ValidationError(
        category: 'NoteElement.staff',
        message: 'Staff must be non-negative',
        path: '$path.staff',
      ));
    }

    return errors;
  }

  int get octave => pitch.octave;

  factory NoteElement.fromJson(Map<String, dynamic> json) {
    return NoteElement(
      pitch: Pitch.fromJson(json['pitch'] as Map<String, dynamic>),
      duration: json['duration'] as int,
      noteType: json['noteType'] as String,
      voice: json['voice'] as int,
      staff: json['staff'] as int,
      dots: json['dots'] as int? ?? 0,
      isChordMember: json['isChordMember'] as bool? ?? false,
      articulations: (json['articulations'] as List?)?.cast<String>() ?? [],
      tie: json['tie'] != null ? Tie.fromJson(json['tie'] as Map<String, dynamic>) : null,
      slur: json['slur'] != null ? Slur.fromJson(json['slur'] as Map<String, dynamic>) : null,
      dynamicMarking: json['dynamic'] as String?,
      text: json['text'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'note',
      'pitch': pitch.toJson(),
      'duration': duration,
      'noteType': noteType,
      'voice': voice,
      'staff': staff,
      'dots': dots,
      'isChordMember': isChordMember,
      if (articulations.isNotEmpty) 'articulations': articulations,
      if (tie != null) 'tie': tie!.toJson(),
      if (slur != null) 'slur': slur!.toJson(),
      if (dynamicMarking != null) 'dynamic': dynamicMarking,
      if (text != null) 'text': text,
    };
  }

  NoteElement copyWith({
    Pitch? pitch,
    int? duration,
    String? noteType,
    int? voice,
    int? staff,
    int? dots,
    bool? isChordMember,
    List<String>? articulations,
    Tie? tie,
    Slur? slur,
    String? dynamicMarking,
    String? text,
  }) {
    return NoteElement(
      pitch: pitch ?? this.pitch,
      duration: duration ?? this.duration,
      noteType: noteType ?? this.noteType,
      voice: voice ?? this.voice,
      staff: staff ?? this.staff,
      dots: dots ?? this.dots,
      isChordMember: isChordMember ?? this.isChordMember,
      articulations: articulations ?? this.articulations,
      tie: tie ?? this.tie,
      slur: slur ?? this.slur,
      dynamicMarking: dynamicMarking ?? this.dynamicMarking,
      text: text ?? this.text,
    );
  }
}

/// Immutable Tie object
class Tie {
  final String type;

  const Tie({required this.type});

  factory Tie.fromJson(Map<String, dynamic> json) {
    return Tie(type: json['type'] as String);
  }

  Map<String, dynamic> toJson() => {'type': type};

  Tie copyWith({String? type}) => Tie(type: type ?? this.type);
}

/// Immutable Slur object
class Slur {
  final String type;
  final int slurNumber;

  const Slur({
    required this.type,
    this.slurNumber = 0,
  });

  factory Slur.fromJson(Map<String, dynamic> json) {
    return Slur(
      type: json['type'] as String,
      slurNumber: json['slurNumber'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (slurNumber != 0) 'slurNumber': slurNumber,
    };
  }

  Slur copyWith({
    String? type,
    int? slurNumber,
  }) {
    return Slur(
      type: type ?? this.type,
      slurNumber: slurNumber ?? this.slurNumber,
    );
  }
}

/// Immutable RestElement object
class RestElement extends Element {
  final int duration;
  final String noteType;
  final int voice;
  final int staff;
  final int dots;

  const RestElement({
    required this.duration,
    required this.noteType,
    required this.voice,
    required this.staff,
    this.dots = 0,
  });

  @override
  List<ValidationError> validate(String path) {
    final errors = <ValidationError>[];

    if (duration < 1) {
      errors.add(ValidationError(
        category: 'RestElement.duration',
        message: 'Duration must be at least 1',
        path: '$path.duration',
      ));
    }

    if (dots < 0 || dots > 3) {
      errors.add(ValidationError(
        category: 'RestElement.dots',
        message: 'Dots must be 0-3',
        path: '$path.dots',
      ));
    }

    if (voice < 0 || voice > 3) {
      errors.add(ValidationError(
        category: 'RestElement.voice',
        message: 'Voice must be 0-3',
        path: '$path.voice',
      ));
    }

    if (staff < 0) {
      errors.add(ValidationError(
        category: 'RestElement.staff',
        message: 'Staff must be non-negative',
        path: '$path.staff',
      ));
    }

    return errors;
  }

  factory RestElement.fromJson(Map<String, dynamic> json) {
    return RestElement(
      duration: json['duration'] as int,
      noteType: json['noteType'] as String,
      voice: json['voice'] as int,
      staff: json['staff'] as int,
      dots: json['dots'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'rest',
      'duration': duration,
      'noteType': noteType,
      'voice': voice,
      'staff': staff,
      'dots': dots,
    };
  }

  RestElement copyWith({
    int? duration,
    String? noteType,
    int? voice,
    int? staff,
    int? dots,
  }) {
    return RestElement(
      duration: duration ?? this.duration,
      noteType: noteType ?? this.noteType,
      voice: voice ?? this.voice,
      staff: staff ?? this.staff,
      dots: dots ?? this.dots,
    );
  }
}

/// Immutable DirectionElement object
class DirectionElement extends Element {
  final String text;
  final String? placement;

  const DirectionElement({
    required this.text,
    this.placement,
  });

  @override
  List<ValidationError> validate(String path) {
    final errors = <ValidationError>[];

    if (text.isEmpty) {
      errors.add(ValidationError(
        category: 'DirectionElement.text',
        message: 'Direction text cannot be empty',
        path: '$path.text',
      ));
    }

    if (placement != null && placement != 'above' && placement != 'below') {
      errors.add(ValidationError(
        category: 'DirectionElement.placement',
        message: 'Placement must be "above" or "below"',
        path: '$path.placement',
      ));
    }

    return errors;
  }

  factory DirectionElement.fromJson(Map<String, dynamic> json) {
    return DirectionElement(
      text: json['text'] as String,
      placement: json['placement'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'direction',
      'text': text,
      if (placement != null) 'placement': placement,
    };
  }

  DirectionElement copyWith({
    String? text,
    String? placement,
  }) {
    return DirectionElement(
      text: text ?? this.text,
      placement: placement ?? this.placement,
    );
  }
}

/// Immutable ScoreMetadata object
class ScoreMetadata {
  final String format;
  final String source;
  final String? sourceId;
  final double? ocrConfidence;
  final bool edited;
  final int editCount;
  final String? createdAt;
  final String? updatedAt;
  final String? checksumSHA256;

  const ScoreMetadata({
    required this.format,
    required this.source,
    this.sourceId,
    this.ocrConfidence,
    this.edited = false,
    this.editCount = 0,
    this.createdAt,
    this.updatedAt,
    this.checksumSHA256,
  });

  factory ScoreMetadata.fromJson(Map<String, dynamic> json) {
    return ScoreMetadata(
      format: json['format'] as String,
      source: json['source'] as String,
      sourceId: json['sourceId'] as String?,
      ocrConfidence: json['ocrConfidence'] as double?,
      edited: json['edited'] as bool? ?? false,
      editCount: json['editCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      checksumSHA256: json['checksumSHA256'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'source': source,
      if (sourceId != null) 'sourceId': sourceId,
      if (ocrConfidence != null) 'ocrConfidence': ocrConfidence,
      'edited': edited,
      'editCount': editCount,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (checksumSHA256 != null) 'checksumSHA256': checksumSHA256,
    };
  }

  ScoreMetadata copyWith({
    String? format,
    String? source,
    String? sourceId,
    double? ocrConfidence,
    bool? edited,
    int? editCount,
    String? createdAt,
    String? updatedAt,
    String? checksumSHA256,
  }) {
    return ScoreMetadata(
      format: format ?? this.format,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      edited: edited ?? this.edited,
      editCount: editCount ?? this.editCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checksumSHA256: checksumSHA256 ?? this.checksumSHA256,
    );
  }
}
