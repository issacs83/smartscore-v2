import 'package:xml/xml.dart';
import 'package:uuid/uuid.dart';
import 'score_json.dart';


/// Parse error with location information
class ParseError {
  final String message;
  final int? lineNumber;
  final String? elementPath;

  ParseError({
    required this.message,
    this.lineNumber,
    this.elementPath,
  });

  @override
  String toString() => 'ParseError at line $lineNumber ($elementPath): $message';
}

/// Parse warning with location information
class ParseWarning {
  final String message;
  final int? lineNumber;
  final String? elementPath;

  ParseWarning({
    required this.message,
    this.lineNumber,
    this.elementPath,
  });

  @override
  String toString() => 'ParseWarning at line $lineNumber ($elementPath): $message';
}

/// Result of parsing a MusicXML document
class ParseResult {
  final Score? score;
  final List<ParseError> errors;
  final List<ParseWarning> warnings;
  final int parseTimeMs;

  ParseResult({
    this.score,
    required this.errors,
    required this.warnings,
    required this.parseTimeMs,
  });

  bool get isSuccess => score != null && errors.isEmpty;
}

/// MusicXML to Score JSON parser
class MusicXmlParser {
  final List<ParseError> errors = [];
  final List<ParseWarning> warnings = [];
  late XmlDocument _doc;
  late String _xml;

  /// Helper to safely get first element by name
  XmlElement? _getFirstElement(XmlElement? parent, String name) {
    if (parent == null) return null;
    try {
      final elements = parent.findElements(name).toList();
      return elements.isEmpty ? null : elements.first;
    } catch (e) {
      return null;
    }
  }

  /// Helper to safely get first element text
  String? _getFirstElementText(XmlElement? parent, String name) {
    return _getFirstElement(parent, name)?.innerText;
  }

  /// Parse MusicXML document in score-partwise format
  ParseResult parse(String musicXmlString) {
    final stopwatch = Stopwatch()..start();
    errors.clear();
    warnings.clear();
    _xml = musicXmlString;

    try {
      _doc = XmlDocument.parse(musicXmlString);
    } catch (e) {
      errors.add(ParseError(
        message: 'Failed to parse XML: $e',
        lineNumber: null,
      ));
      stopwatch.stop();
      return ParseResult(
        errors: errors,
        warnings: warnings,
        parseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    final scoreElement = _doc.rootElement;

    // Validate root element
    if (scoreElement.name.local != 'score-partwise') {
      errors.add(ParseError(
        message: 'Root element must be score-partwise, got ${scoreElement.name.local}',
        elementPath: '/',
      ));
      stopwatch.stop();
      return ParseResult(
        errors: errors,
        warnings: warnings,
        parseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    try {
      final score = _parseScore(scoreElement);
      stopwatch.stop();
      return ParseResult(
        score: score,
        errors: errors,
        warnings: warnings,
        parseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      errors.add(ParseError(
        message: 'Fatal parsing error: $e',
        elementPath: '/',
      ));
      stopwatch.stop();
      return ParseResult(
        errors: errors,
        warnings: warnings,
        parseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Score? _parseScore(XmlElement scoreElement) {
    // Parse work-title or score-title
    String title = 'Untitled';
    final workTitleList = scoreElement.findElements('work-title')?.toList() ?? [];
    final scoreTitleList = scoreElement.findElements('score-title')?.toList() ?? [];

    final workTitle = workTitleList.isNotEmpty ? workTitleList.first : null;
    final scoreTitle = scoreTitleList.isNotEmpty ? scoreTitleList.first : null;

    if (workTitle != null) {
      title = workTitle.innerText.trim();
    } else if (scoreTitle != null) {
      title = scoreTitle.innerText.trim();
    }

    // Parse composer
    String composer = '';
    final composerList = scoreElement.findElements('composer')?.toList() ?? [];
    final composerElem = composerList.isNotEmpty ? composerList.first : null;
    if (composerElem != null) {
      composer = composerElem.innerText.trim();
    }

    // Parse part-list
    final partListElem = this._getFirstElement(scoreElement, 'part-list');
    if (partListElem == null) {
      errors.add(ParseError(
        message: 'score-partwise must have part-list element',
        elementPath: '/score-partwise/part-list',
      ));
      return null;
    }

    final partInfoMap = _parsePartList(partListElem);
    if (partInfoMap.isEmpty) {
      errors.add(ParseError(
        message: 'part-list is empty or has no score-part elements',
        elementPath: '/score-partwise/part-list',
      ));
      return null;
    }

    // Parse parts
    final partElements = scoreElement.findElements('part')?.toList() ?? [];
    if (partElements.isEmpty) {
      errors.add(ParseError(
        message: 'score-partwise must have at least one part element',
        elementPath: '/score-partwise/part',
      ));
      return null;
    }

    final parts = <Part>[];
    for (final partElem in partElements) {
      final partId = partElem.getAttribute('id') ?? '';
      final partInfo = partInfoMap[partId];

      if (partInfo == null) {
        warnings.add(ParseWarning(
          message: 'Part $partId referenced but not defined in part-list',
          elementPath: '/score-partwise/part[@id="$partId"]',
        ));
        continue;
      }

      final part = _parsePart(partElem, partId, partInfo);
      if (part != null) {
        parts.add(part);
      }
    }

    if (parts.isEmpty) {
      errors.add(ParseError(
        message: 'Could not parse any valid parts',
        elementPath: '/score-partwise/part',
      ));
      return null;
    }

    final metadata = ScoreMetadata(
      format: '1.0',
      source: 'musicxml',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    return Score(
      id: _generateUuid(),
      title: title.isEmpty ? 'Untitled' : title,
      composer: composer,
      parts: parts,
      metadata: metadata,
    );
  }

  Map<String, Map<String, String>> _parsePartList(XmlElement partListElem) {
    final partInfoMap = <String, Map<String, String>>{};

    for (final scorePart in partListElem.findElements('score-part')?.toList() ?? []) {
      final partId = scorePart.getAttribute('id') ?? '';
      if (partId.isEmpty) {
        warnings.add(ParseWarning(
          message: 'score-part has no id attribute',
          elementPath: '/score-partwise/part-list/score-part',
        ));
        continue;
      }

      String partName = 'Part';
      String instrumentType = 'generic';

      final partNameElem = this._getFirstElement(scorePart, 'part-name');
      if (partNameElem != null) {
        partName = partNameElem.innerText.trim();
      }

      final scoreInstrument = this._getFirstElement(scorePart, 'score-instrument');
      if (scoreInstrument != null) {
        final instrName = this._getFirstElement(scoreInstrument, 'instrument-name');
        if (instrName != null) {
          instrumentType = InstrumentType.fromName(instrName.innerText.trim()).value;
        }
      }

      partInfoMap[partId] = {
        'name': partName,
        'instrumentType': instrumentType,
      };
    }

    return partInfoMap;
  }

  Part? _parsePart(
    XmlElement partElem,
    String partId,
    Map<String, String> partInfo,
  ) {
    final measureElements = partElem.findElements('measure')?.toList() ?? [];
    if (measureElements.isEmpty) {
      warnings.add(ParseWarning(
        message: 'Part $partId has no measures',
        elementPath: '/score-partwise/part[@id="$partId"]',
      ));
      return null;
    }

    final measures = <Measure>[];
    for (final measureElem in measureElements) {
      final measureNum = int.tryParse(measureElem.getAttribute('number') ?? '0') ?? 0;
      final measure = _parseMeasure(measureElem, measureNum);
      if (measure != null) {
        measures.add(measure);
      }
    }

    if (measures.isEmpty) {
      warnings.add(ParseWarning(
        message: 'Part $partId could not parse any measures',
        elementPath: '/score-partwise/part[@id="$partId"]',
      ));
      return null;
    }

    return Part(
      id: partId,
      name: partInfo['name'] ?? 'Part',
      instrumentType: InstrumentType.fromString(partInfo['instrumentType'] ?? 'generic'),
      staveCount: 1,
      measures: measures,
    );
  }

  Measure? _parseMeasure(XmlElement measureElem, int measureNum) {
    String? timeSignature;
    KeySignature? keySignature;
    int? tempo;
    String? rehearsalMark;
    bool repeatStart = false;
    bool repeatEnd = false;
    final clefs = <Clef>[];

    final elements = <Element>[];

    // Parse all measure elements
    for (final child in measureElem.childElements) {
      final localName = child.name.local;

      switch (localName) {
        case 'attributes':
          final attr = _parseAttributes(child);
          if (attr['timeSignature'] != null) {
            timeSignature = attr['timeSignature'] as String;
          }
          if (attr['keySignature'] != null) {
            keySignature = attr['keySignature'] as KeySignature;
          }
          if (attr['clefs'] != null) {
            clefs.addAll(attr['clefs'] as List<Clef>);
          }
          break;

        case 'sound':
          final tempoAttr = child.getAttribute('tempo');
          if (tempoAttr != null) {
            tempo = int.tryParse(tempoAttr);
          }
          break;

        case 'rehearsal':
          rehearsalMark = child.innerText.trim();
          break;

        case 'barline':
          final repeat = this._getFirstElement(child, 'repeat');
          if (repeat != null) {
            final direction = repeat.getAttribute('direction') ?? '';
            if (direction == 'forward') {
              repeatStart = true;
            } else if (direction == 'backward') {
              repeatEnd = true;
            }
          }
          break;

        case 'note':
          final note = _parseNote(child);
          if (note != null) {
            elements.add(note);
          }
          break;

        case 'rest':
          final rest = _parseRest(child);
          if (rest != null) {
            elements.add(rest);
          }
          break;

        case 'direction':
          final direction = _parseDirection(child);
          if (direction != null) {
            elements.add(direction);
          }
          break;

        default:
          // Log unknown elements as warnings
          warnings.add(ParseWarning(
            message: 'Unknown measure element: $localName',
            elementPath: '/score-partwise/part/measure/measure[@number="$measureNum"]/$localName',
          ));
          break;
      }
    }

    return Measure(
      number: measureNum,
      elements: elements,
      timeSignature: timeSignature,
      keySignature: keySignature,
      tempo: tempo,
      rehearsalMark: rehearsalMark,
      repeatStart: repeatStart,
      repeatEnd: repeatEnd,
      clefs: clefs,
    );
  }

  Map<String, dynamic> _parseAttributes(XmlElement attrElem) {
    final result = <String, dynamic>{};

    // Parse time signature
    final timeElem = this._getFirstElement(attrElem, 'time');
    if (timeElem != null) {
      final beats = this._getFirstElement(timeElem, 'beats')?.innerText ?? '4';
      final beatType = this._getFirstElement(timeElem, 'beat-type')?.innerText ?? '4';
      result['timeSignature'] = '$beats/$beatType';
    }

    // Parse key signature
    final keyElem = this._getFirstElement(attrElem, 'key');
    if (keyElem != null) {
      final fifthsStr = this._getFirstElement(keyElem, 'fifths')?.innerText ?? '0';
      final fifths = int.tryParse(fifthsStr) ?? 0;
      final modeElem = this._getFirstElement(keyElem, 'mode')?.innerText ?? 'major';

      final keyStep = _fifthsToKeyStep(fifths);
      result['keySignature'] = KeySignature(
        step: keyStep,
        tonality: modeElem,
        alterations: fifths,
      );
    }

    // Parse clefs
    final clefElem = this._getFirstElement(attrElem, 'clef');
    if (clefElem != null) {
      final sign = this._getFirstElement(clefElem, 'sign')?.innerText ?? 'G';
      final lineStr = this._getFirstElement(clefElem, 'line')?.innerText ?? '2';
      final line = int.tryParse(lineStr) ?? 2;
      final staffStr = clefElem.getAttribute('number') ?? '1';
      final staff = int.tryParse(staffStr) ?? 1;

      result['clefs'] = [
        Clef(sign: sign, line: line, staff: staff - 1),
      ];
    }

    return result;
  }

  String _fifthsToKeyStep(int fifths) {
    const majorKeys = ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#', 'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb'];
    const majorIndex = 7;

    final index = majorIndex + fifths;
    if (index >= 0 && index < majorKeys.length) {
      return majorKeys[index];
    }
    return 'C';
  }

  Element? _parseNote(XmlElement noteElem) {
    // Check if this is a rest
    if ((noteElem.findElements('rest')?.toList() ?? []).isNotEmpty) {
      return _parseRest(noteElem);
    }

    // Parse pitch
    final pitchElem = this._getFirstElement(noteElem, 'pitch');
    if (pitchElem == null) {
      warnings.add(ParseWarning(
        message: 'Note element has no pitch',
        elementPath: '/note',
      ));
      return null;
    }

    final step = this._getFirstElement(pitchElem, 'step')?.innerText ?? 'C';
    final octaveStr = this._getFirstElement(pitchElem, 'octave')?.innerText ?? '4';
    final alterStr = this._getFirstElement(pitchElem, 'alter')?.innerText ?? '0';

    final octave = int.tryParse(octaveStr) ?? 4;
    final alter = int.tryParse(alterStr) ?? 0;

    final pitch = Pitch(step: step, octave: octave, alter: alter);

    // Parse duration
    final durationStr = this._getFirstElement(noteElem, 'duration')?.innerText ?? '4';
    final duration = int.tryParse(durationStr) ?? 4;

    // Parse type
    final noteTypeElem = this._getFirstElement(noteElem, 'type');
    String noteType = 'quarter';
    if (noteTypeElem != null) {
      noteType = _mxmlTypeToNoteType(noteTypeElem.innerText.trim());
    }

    // Parse voice
    final voiceStr = this._getFirstElement(noteElem, 'voice')?.innerText ?? '1';
    final voice = int.tryParse(voiceStr) ?? 1;

    // Parse staff
    final staffStr = this._getFirstElement(noteElem, 'staff')?.innerText ?? '1';
    final staff = int.tryParse(staffStr) ?? 1;

    // Parse dots
    final dots = (noteElem.findElements('dot')?.toList() ?? []).length;

    // Parse chord membership
    final isChordMember = (noteElem.findElements('chord')?.toList() ?? []).isNotEmpty;

    // Parse articulations
    final articulations = <String>[];
    final articulationsElem = this._getFirstElement(noteElem, 'articulations');
    if (articulationsElem != null) {
      for (final child in articulationsElem.childElements) {
        articulations.add(child.name.local);
      }
    }

    // Parse tie
    Tie? tie;
    final tieElem = this._getFirstElement(noteElem, 'tie');
    if (tieElem != null) {
      final tieType = tieElem.getAttribute('type') ?? 'start';
      tie = Tie(type: tieType);
    }

    // Parse slur
    Slur? slur;
    final notationsElem = this._getFirstElement(noteElem, 'notations');
    final slurElem = notationsElem != null ? this._getFirstElement(notationsElem, 'slur') : null;
    if (slurElem != null) {
      final slurType = slurElem.getAttribute('type') ?? 'start';
      final slurNum = slurElem.getAttribute('number') ?? '1';
      slur = Slur(
        type: slurType,
        slurNumber: int.tryParse(slurNum) ?? 0,
      );
    }

    // Parse dynamics
    String? dynamic;
    final dynamicsElem = this._getFirstElement(noteElem, 'dynamics');
    if (dynamicsElem != null) {
      for (final child in dynamicsElem.childElements) {
        dynamic = child.name.local;
        break;
      }
    }

    // Parse text
    String? text;
    final lyricElem = this._getFirstElement(noteElem, 'lyric');
    if (lyricElem != null) {
      final syllabic = this._getFirstElement(lyricElem, 'text')?.innerText;
      if (syllabic != null) {
        text = syllabic.trim();
      }
    }

    return NoteElement(
      pitch: pitch,
      duration: duration,
      noteType: noteType,
      voice: voice - 1,
      staff: staff - 1,
      dots: dots,
      isChordMember: isChordMember,
      articulations: articulations,
      tie: tie,
      slur: slur,
      dynamicMarking: dynamic,
      text: text,
    );
  }

  Element? _parseRest(XmlElement restElem) {
    final durationStr = this._getFirstElement(restElem, 'duration')?.innerText ?? '4';
    final duration = int.tryParse(durationStr) ?? 4;

    final noteTypeElem = this._getFirstElement(restElem, 'type');
    String noteType = 'quarter';
    if (noteTypeElem != null) {
      noteType = _mxmlTypeToNoteType(noteTypeElem.innerText.trim());
    }

    final voiceStr = this._getFirstElement(restElem, 'voice')?.innerText ?? '1';
    final voice = int.tryParse(voiceStr) ?? 1;

    final staffStr = this._getFirstElement(restElem, 'staff')?.innerText ?? '1';
    final staff = int.tryParse(staffStr) ?? 1;

    final dots = (restElem.findElements('dot')?.toList() ?? []).length;

    return RestElement(
      duration: duration,
      noteType: noteType,
      voice: voice - 1,
      staff: staff - 1,
      dots: dots,
    );
  }

  Element? _parseDirection(XmlElement directionElem) {
    String? text;
    String? placement = directionElem.getAttribute('placement');

    // Look for dynamics
    final dynamicsElem = this._getFirstElement(directionElem, 'sound');
    if (dynamicsElem != null) {
      text = 'dynamic marking';
    }

    // Look for directions
    final directionTypeElem = this._getFirstElement(directionElem, 'direction-type');
    if (directionTypeElem != null) {
      final wordsElem = this._getFirstElement(directionTypeElem, 'words');
      if (wordsElem != null) {
        text = wordsElem.innerText.trim();
        placement = wordsElem.getAttribute('placement') ?? placement;
      }
    }

    if (text == null || text.isEmpty) {
      return null;
    }

    return DirectionElement(text: text, placement: placement);
  }

  String _mxmlTypeToNoteType(String mxmlType) {
    return switch (mxmlType) {
      'whole' => 'whole',
      'half' => 'half',
      'quarter' => 'quarter',
      'eighth' => 'eighth',
      '16th' => 'sixteenth',
      '32nd' => 'thirty-second',
      _ => 'quarter',
    };
  }

  String _generateUuid() {
    return const Uuid().v4();
  }
}
