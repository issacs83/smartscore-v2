import 'package:test/test.dart';
import 'package:smartscore_build/modules/e_music_normalizer/musicxml_parser.dart';
import 'package:smartscore_build/modules/e_music_normalizer/score_json.dart';

void main() {
  group('MusicXML Parser Tests', () {
    test('Parse valid Twinkle Twinkle Little Star', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work>
    <work-title>Twinkle Twinkle Little Star</work-title>
  </work>
  <identification>
    <composer>Traditional</composer>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>Melody</part-name>
      <score-instrument id="P1-I1">
        <instrument-name>Voice</instrument-name>
      </score-instrument>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <key>
          <fifths>0</fifths>
          <mode>major</mode>
        </key>
        <time>
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
        <clef>
          <sign>G</sign>
          <line>2</line>
        </clef>
      </attributes>
      <note>
        <pitch>
          <step>C</step>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <note>
        <pitch>
          <step>C</step>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <note>
        <pitch>
          <step>G</step>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <note>
        <pitch>
          <step>A</step>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
    <measure number="2">
      <note>
        <pitch>
          <step>B</step>
          <octave>3</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <note>
        <pitch>
          <step>B</step>
          <octave>3</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <note>
        <pitch>
          <step>B</step>
          <octave>3</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <rest>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </rest>
    </measure>
    <measure number="3">
      <note>
        <pitch>
          <step>A</step>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <note>
        <pitch>
          <step>A</step>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <note>
        <pitch>
          <step>A</step>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <rest>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </rest>
    </measure>
    <measure number="4">
      <note>
        <pitch>
          <step>G</step>
          <octave>4</octave>
        </pitch>
        <duration>8</duration>
        <type>half</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <rest>
        <duration>8</duration>
        <type>half</type>
        <voice>1</voice>
        <staff>1</staff>
      </rest>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.isSuccess, isTrue);
      expect(result.score, isNotNull);
      expect(result.errors, isEmpty);

      final score = result.score!;
      expect(score.title, equals('Twinkle Twinkle Little Star'));
      expect(score.composer, equals('Traditional'));
      expect(score.parts.length, equals(1));

      final part = score.parts[0];
      expect(part.id, equals('P1'));
      expect(part.name, equals('Melody'));
      expect(part.measures.length, equals(4));

      // Check first measure
      final measure1 = part.measures[0];
      expect(measure1.number, equals(1));
      expect(measure1.elements.length, equals(4));
      expect(measure1.timeSignature, equals('4/4'));

      // Check first note
      final note1 = measure1.elements[0] as NoteElement;
      expect(note1.pitch.step, equals('C'));
      expect(note1.pitch.octave, equals(4));
      expect(note1.duration, equals(4));

      // Check rest in measure 2
      final measure2 = part.measures[1];
      expect(measure2.elements.length, equals(4));
      final rest = measure2.elements[3] as RestElement;
      expect(rest.duration, equals(4));
    });

    test('Parse time returns elapsed milliseconds', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1">
      <part-name>Part 1</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.parseTimeMs, greaterThanOrEqualTo(0));
    });

    test('Malformed XML returns error', () {
      final invalidXml = '''<?xml version="1.0"?>
<score-partwise>
  <broken-tag>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(invalidXml);

      expect(result.score, isNull);
      expect(result.errors, isNotEmpty);
      expect(result.errors[0].message, contains('Failed to parse XML'));
    });

    test('Wrong root element returns error', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-timewise version="3.1">
  <part-list/>
</score-timewise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.score, isNull);
      expect(result.errors, isNotEmpty);
      expect(result.errors[0].message, contains('score-partwise'));
    });

    test('Missing part-list returns error', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part id="P1">
    <measure number="1"/>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.score, isNull);
      expect(result.errors, isNotEmpty);
      expect(result.errors[0].message, contains('part-list'));
    });

    test('Empty part-list returns error', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list/>
  <part id="P1">
    <measure number="1"/>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.score, isNull);
      expect(result.errors, isNotEmpty);
    });

    test('Parse multiple parts', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1">
      <part-name>Violin</part-name>
      <score-instrument id="P1-I1">
        <instrument-name>Violin</instrument-name>
      </score-instrument>
    </score-part>
    <score-part id="P2">
      <part-name>Piano</part-name>
      <score-instrument id="P2-I1">
        <instrument-name>Piano</instrument-name>
      </score-instrument>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
  </part>
  <part id="P2">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <note>
        <pitch><step>C</step><octave>3</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.isSuccess, isTrue);
      expect(result.score!.parts.length, equals(2));
      expect(result.score!.parts[0].name, equals('Violin'));
      expect(result.score!.parts[1].name, equals('Piano'));
    });

    test('Parse with accidentals', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <note>
        <pitch>
          <step>C</step>
          <alter>1</alter>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <note>
        <pitch>
          <step>D</step>
          <alter>-1</alter>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.isSuccess, isTrue);
      final measure = result.score!.parts[0].measures[0];
      expect((measure.elements[0] as NoteElement).pitch.alter, equals(1));
      expect((measure.elements[1] as NoteElement).pitch.alter, equals(-1));
    });

    test('Parse key signature', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <key>
          <fifths>1</fifths>
          <mode>major</mode>
        </key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.isSuccess, isTrue);
      final measure = result.score!.parts[0].measures[0];
      expect(measure.keySignature, isNotNull);
      expect(measure.keySignature!.tonality, equals('major'));
      expect(measure.keySignature!.alterations, equals(1));
    });

    test('Parse tempo marking', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <sound tempo="120"/>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.isSuccess, isTrue);
      final measure = result.score!.parts[0].measures[0];
      expect(measure.tempo, equals(120));
    });

    test('Parse rest element', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <rest>
        <duration>8</duration>
        <type>half</type>
        <voice>1</voice>
        <staff>1</staff>
      </rest>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.isSuccess, isTrue);
      final element = result.score!.parts[0].measures[0].elements[0];
      expect(element, isA<RestElement>());
      expect((element as RestElement).duration, equals(8));
      expect(element.noteType, equals('half'));
    });

    test('Unknown element logged as warning', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <unknown-element/>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.warnings, isNotEmpty);
      expect(result.warnings.any((w) => w.message.contains('unknown-element')), isTrue);
    });

    test('Parse with clef', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <clef>
          <sign>G</sign>
          <line>2</line>
        </clef>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.isSuccess, isTrue);
      final measure = result.score!.parts[0].measures[0];
      expect(measure.clefs, isNotEmpty);
      expect(measure.clefs[0].sign, equals('G'));
      expect(measure.clefs[0].line, equals(2));
    });

    test('Parse with repeats', () {
      final musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Part 1</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <barline>
        <repeat direction="forward"/>
      </barline>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
    </measure>
    <measure number="2">
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <type>quarter</type>
        <voice>1</voice>
        <staff>1</staff>
      </note>
      <barline>
        <repeat direction="backward"/>
      </barline>
    </measure>
  </part>
</score-partwise>''';

      final parser = MusicXmlParser();
      final result = parser.parse(musicXml);

      expect(result.isSuccess, isTrue);
      expect(result.score!.parts[0].measures[0].repeatStart, isTrue);
      expect(result.score!.parts[0].measures[1].repeatEnd, isTrue);
    });
  });
}
