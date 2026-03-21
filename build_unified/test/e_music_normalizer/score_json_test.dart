import 'package:test/test.dart';
import 'package:smartscore_build/modules/e_music_normalizer/score_json.dart';
import 'dart:convert';

void main() {
  group('Pitch Tests', () {
    test('Pitch.midiNumber C4 equals 60', () {
      final pitch = Pitch(step: 'C', octave: 4);
      expect(pitch.midiNumber, equals(60));
    });

    test('Pitch.midiNumber A4 equals 69', () {
      final pitch = Pitch(step: 'A', octave: 4);
      expect(pitch.midiNumber, equals(69));
    });

    test('Pitch.midiNumber C5 equals 72', () {
      final pitch = Pitch(step: 'C', octave: 5);
      expect(pitch.midiNumber, equals(72));
    });

    test('Pitch.midiNumber with sharps', () {
      final pitch = Pitch(step: 'C', octave: 4, alter: 1);
      expect(pitch.midiNumber, equals(61)); // C# = 61
    });

    test('Pitch.midiNumber with flats', () {
      final pitch = Pitch(step: 'D', octave: 4, alter: -1);
      expect(pitch.midiNumber, equals(61)); // Db = 61
    });

    test('Pitch.frequency A4 equals 440.0', () {
      final pitch = Pitch(step: 'A', octave: 4);
      expect(pitch.frequency, closeTo(440.0, 0.01));
    });

    test('Pitch.frequency C4 approximately 261.63', () {
      final pitch = Pitch(step: 'C', octave: 4);
      expect(pitch.frequency, closeTo(261.63, 0.1));
    });

    test('Pitch.frequency increases by semitone', () {
      final c = Pitch(step: 'C', octave: 4);
      final cSharp = Pitch(step: 'C', octave: 4, alter: 1);
      expect(cSharp.frequency, greaterThan(c.frequency));
      expect(cSharp.frequency / c.frequency, closeTo(1.05946, 0.0001));
    });

    test('Pitch.fromJson and toJson round-trip', () {
      final pitch = Pitch(step: 'G', octave: 5, alter: -1);
      final json = pitch.toJson();
      final restored = Pitch.fromJson(json);
      expect(restored.step, equals(pitch.step));
      expect(restored.octave, equals(pitch.octave));
      expect(restored.alter, equals(pitch.alter));
    });

    test('Pitch.copyWith', () {
      final pitch = Pitch(step: 'C', octave: 4, alter: 1);
      final modified = pitch.copyWith(octave: 5);
      expect(modified.step, equals('C'));
      expect(modified.octave, equals(5));
      expect(modified.alter, equals(1));
    });
  });

  group('InstrumentType Tests', () {
    test('InstrumentType.fromString returns correct type', () {
      expect(InstrumentType.fromString('violin'), equals(InstrumentType.violin));
      expect(InstrumentType.fromString('piano'), equals(InstrumentType.piano));
      expect(InstrumentType.fromString('flute'), equals(InstrumentType.flute));
    });

    test('InstrumentType.fromString case-insensitive', () {
      expect(InstrumentType.fromString('VIOLIN'), equals(InstrumentType.violin));
      expect(InstrumentType.fromString('Piano'), equals(InstrumentType.piano));
    });

    test('InstrumentType.fromString unknown returns generic', () {
      expect(InstrumentType.fromString('unknown'), equals(InstrumentType.generic));
      expect(InstrumentType.fromString('xyz'), equals(InstrumentType.generic));
    });

    test('InstrumentType.fromName handles common variations', () {
      expect(InstrumentType.fromName('Violin I'), equals(InstrumentType.violin));
      expect(InstrumentType.fromName('Cello'), equals(InstrumentType.cello));
      expect(InstrumentType.fromName('French Horn'), equals(InstrumentType.horn));
      expect(InstrumentType.fromName('Soprano'), equals(InstrumentType.soprano));
      expect(InstrumentType.fromName('Electric Guitar'), equals(InstrumentType.guitar));
    });

    test('InstrumentType.fromName case-insensitive', () {
      expect(InstrumentType.fromName('VIOLIN'), equals(InstrumentType.violin));
      expect(InstrumentType.fromName('Piano'), equals(InstrumentType.piano));
      expect(InstrumentType.fromName('TRUMPET'), equals(InstrumentType.trumpet));
    });

    test('InstrumentType.fromName with whitespace', () {
      expect(InstrumentType.fromName('  Violin  '), equals(InstrumentType.violin));
      expect(InstrumentType.fromName('  Piano  '), equals(InstrumentType.piano));
    });

    test('InstrumentType value property', () {
      expect(InstrumentType.violin.value, equals('violin'));
      expect(InstrumentType.piano.value, equals('piano'));
      expect(InstrumentType.generic.value, equals('generic'));
    });
  });

  group('Score JSON Serialization Tests', () {
    test('Pitch.fromJson and toJson round-trip', () {
      final json = {
        'step': 'A',
        'octave': 4,
        'alter': 0,
      };
      final pitch = Pitch.fromJson(json);
      final restored = pitch.toJson();
      expect(restored['step'], equals('A'));
      expect(restored['octave'], equals(4));
      expect(restored['alter'], equals(0));
    });

    test('NoteElement.fromJson and toJson round-trip', () {
      final json = {
        'type': 'note',
        'pitch': {'step': 'C', 'octave': 4, 'alter': 0},
        'duration': 64,
        'noteType': 'quarter',
        'voice': 0,
        'staff': 0,
        'dots': 0,
        'isChordMember': false,
        'articulations': [],
      };
      final note = NoteElement.fromJson(json);
      final restored = note.toJson();
      expect(restored['type'], equals('note'));
      expect(restored['pitch']['step'], equals('C'));
      expect(restored['duration'], equals(64));
    });

    test('RestElement.fromJson and toJson round-trip', () {
      final json = {
        'type': 'rest',
        'duration': 128,
        'noteType': 'half',
        'voice': 0,
        'staff': 0,
        'dots': 0,
      };
      final rest = RestElement.fromJson(json);
      final restored = rest.toJson();
      expect(restored['type'], equals('rest'));
      expect(restored['duration'], equals(128));
      expect(restored['noteType'], equals('half'));
    });

    test('KeySignature.fromJson and toJson', () {
      final json = {
        'step': 'G',
        'tonality': 'major',
        'alterations': 1,
      };
      final keySig = KeySignature.fromJson(json);
      final restored = keySig.toJson();
      expect(restored['step'], equals('G'));
      expect(restored['tonality'], equals('major'));
      expect(restored['alterations'], equals(1));
    });

    test('Measure.fromJson and toJson with partial data', () {
      final json = {
        'number': 0,
        'elements': [],
        'timeSignature': '4/4',
      };
      final measure = Measure.fromJson(json);
      final restored = measure.toJson();
      expect(restored['number'], equals(0));
      expect(restored['timeSignature'], equals('4/4'));
    });

    test('Part.fromJson and toJson', () {
      final json = {
        'id': 'P1',
        'name': 'Violin',
        'instrumentType': 'violin',
        'staveCount': 1,
        'measures': [
          {
            'number': 0,
            'elements': [],
            'timeSignature': '4/4',
          },
        ],
      };
      final part = Part.fromJson(json);
      final restored = part.toJson();
      expect(restored['id'], equals('P1'));
      expect(restored['name'], equals('Violin'));
      expect(restored['instrumentType'], equals('violin'));
      expect(restored['staveCount'], equals(1));
      expect(restored['measures'], isNotEmpty);
    });

    test('Score.fromJson and toJson round-trip', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'title': 'Test Score',
        'composer': 'Test Composer',
        'parts': [
          {
            'id': 'P1',
            'name': 'Melody',
            'instrumentType': 'voice',
            'staveCount': 1,
            'measures': [
              {
                'number': 0,
                'elements': [
                  {
                    'type': 'note',
                    'pitch': {'step': 'C', 'octave': 4, 'alter': 0},
                    'duration': 64,
                    'noteType': 'quarter',
                    'voice': 0,
                    'staff': 0,
                    'dots': 0,
                    'isChordMember': false,
                  },
                ],
                'timeSignature': '4/4',
              },
            ],
          },
        ],
        'metadata': {
          'format': '1.0',
          'source': 'test',
        },
      };

      final score = Score.fromJson(json);
      expect(score.title, equals('Test Score'));
      expect(score.composer, equals('Test Composer'));
      expect(score.parts, isNotEmpty);

      final restored = score.toJson();
      expect(restored['title'], equals('Test Score'));
      expect(restored['composer'], equals('Test Composer'));
      expect(restored['parts'].length, equals(1));
    });
  });

  group('Score Validation Tests', () {
    test('Valid score passes validation', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Valid Score',
        composer: 'Test',
        parts: [
          Part(
            id: 'P1',
            name: 'Part 1',
            instrumentType: InstrumentType.piano,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(
          format: '1.0',
          source: 'test',
        ),
      );

      final errors = score.validate();
      expect(errors, isEmpty);
    });

    test('Invalid UUID detected', () {
      final score = Score(
        id: 'invalid-uuid',
        title: 'Test',
        composer: '',
        parts: [],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final errors = score.validate();
      expect(errors.where((e) => e.category == 'UUID'), isNotEmpty);
    });

    test('Empty title detected', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: '',
        composer: '',
        parts: [],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final errors = score.validate();
      expect(errors.where((e) => e.category == 'Title'), isNotEmpty);
    });

    test('Empty parts detected', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final errors = score.validate();
      expect(errors.where((e) => e.category == 'Parts'), isNotEmpty);
    });
  });

  group('Copyable State Tests', () {
    test('Pitch.copyWith preserves immutability', () {
      final original = Pitch(step: 'C', octave: 4, alter: 1);
      final modified = original.copyWith(octave: 5);
      expect(original.octave, equals(4));
      expect(modified.octave, equals(5));
      expect(original, isNot(same(modified)));
    });

    test('NoteElement.copyWith', () {
      final pitch = Pitch(step: 'C', octave: 4);
      final original = NoteElement(
        pitch: pitch,
        duration: 64,
        noteType: 'quarter',
        voice: 0,
        staff: 0,
      );
      final modified = original.copyWith(duration: 128);
      expect(original.duration, equals(64));
      expect(modified.duration, equals(128));
    });

    test('Score.copyWith', () {
      final original = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Original',
        composer: 'Test',
        parts: [],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );
      final modified = original.copyWith(title: 'Modified');
      expect(original.title, equals('Original'));
      expect(modified.title, equals('Modified'));
    });

    test('Part.copyWith', () {
      final original = Part(
        id: 'P1',
        name: 'Original',
        instrumentType: InstrumentType.piano,
        staveCount: 1,
        measures: [],
      );
      final modified = original.copyWith(name: 'Modified');
      expect(original.name, equals('Original'));
      expect(modified.name, equals('Modified'));
    });

    test('Measure.copyWith', () {
      final original = Measure(number: 0, elements: []);
      final modified = original.copyWith(number: 1);
      expect(original.number, equals(0));
      expect(modified.number, equals(1));
    });
  });

  group('Tie and Slur Tests', () {
    test('Tie.fromJson and toJson', () {
      final json = {'type': 'start'};
      final tie = Tie.fromJson(json);
      expect(tie.type, equals('start'));
      expect(tie.toJson(), equals(json));
    });

    test('Slur.fromJson and toJson', () {
      final json = {'type': 'start', 'slurNumber': 1};
      final slur = Slur.fromJson(json);
      expect(slur.type, equals('start'));
      expect(slur.slurNumber, equals(1));
      final restored = slur.toJson();
      expect(restored['type'], equals('start'));
    });

    test('NoteElement with tie', () {
      final json = {
        'type': 'note',
        'pitch': {'step': 'C', 'octave': 4, 'alter': 0},
        'duration': 64,
        'noteType': 'quarter',
        'voice': 0,
        'staff': 0,
        'tie': {'type': 'start'},
      };
      final note = NoteElement.fromJson(json);
      expect(note.tie, isNotNull);
      expect(note.tie!.type, equals('start'));
    });

    test('NoteElement with slur', () {
      final json = {
        'type': 'note',
        'pitch': {'step': 'C', 'octave': 4, 'alter': 0},
        'duration': 64,
        'noteType': 'quarter',
        'voice': 0,
        'staff': 0,
        'slur': {'type': 'start', 'slurNumber': 0},
      };
      final note = NoteElement.fromJson(json);
      expect(note.slur, isNotNull);
      expect(note.slur!.type, equals('start'));
    });
  });

  group('DirectionElement Tests', () {
    test('DirectionElement.fromJson and toJson', () {
      final json = {
        'type': 'direction',
        'text': 'molto ritardando',
        'placement': 'above',
      };
      final direction = DirectionElement.fromJson(json);
      expect(direction.text, equals('molto ritardando'));
      expect(direction.placement, equals('above'));
      final restored = direction.toJson();
      expect(restored['text'], equals('molto ritardando'));
    });

    test('DirectionElement without placement', () {
      final json = {
        'type': 'direction',
        'text': 'pizz.',
      };
      final direction = DirectionElement.fromJson(json);
      expect(direction.text, equals('pizz.'));
      expect(direction.placement, isNull);
    });
  });
}
