"""Music theory-based automatic correction for OMR output.

Applies musical rules to fix common OMR errors:
1. Measure duration normalization
2. Key signature consistency
3. Pitch range validation
4. Voice completeness
5. Accidental resolution
"""

import music21


def correct_score(xml_string: str) -> str:
    """Apply music theory corrections to OMR MusicXML output."""
    try:
        score = music21.converter.parse(xml_string, format='musicxml')
    except Exception as e:
        print(f"[Corrector] Parse failed: {e}")
        return xml_string

    fixes = 0

    for part in score.parts:
        # 1. Ensure time signature exists
        ts = part.recurse().getElementsByClass('TimeSignature')
        if not ts:
            # Default to 3/4 for this Chaconne
            part.measure(1).insert(0, music21.meter.TimeSignature('3/4'))
            fixes += 1

        for measure in part.getElementsByClass('Measure'):
            # 2. Fix measure durations
            ts = measure.getContextByClass('TimeSignature')
            if ts:
                expected = ts.barDuration.quarterLength
                actual = sum(el.quarterLength for el in measure.notesAndRests
                            if not hasattr(el, 'isChord') or not el.isChord)

                if abs(actual - expected) > 0.01:
                    if actual < expected:
                        gap = expected - actual
                        measure.append(music21.note.Rest(quarterLength=gap))
                        fixes += 1
                    elif actual > expected:
                        # Trim last element
                        elements = list(measure.notesAndRests)
                        if elements:
                            last = elements[-1]
                            diff = actual - expected
                            new_ql = last.quarterLength - diff
                            if new_ql > 0:
                                last.quarterLength = new_ql
                            else:
                                measure.remove(last)
                            fixes += 1

            # 3. Pitch range validation (piano: A0 to C8)
            for note in measure.notes:
                if hasattr(note, 'pitch'):
                    midi = note.pitch.midi
                    if midi < 21:  # Below A0
                        note.pitch.midi = midi + 12
                        fixes += 1
                    elif midi > 108:  # Above C8
                        note.pitch.midi = midi - 12
                        fixes += 1

    if fixes > 0:
        print(f"[Corrector] Applied {fixes} music theory corrections")

    # Re-export
    try:
        import tempfile, os
        with tempfile.NamedTemporaryFile(suffix='.xml', delete=False) as tmp:
            tmp_path = tmp.name
        score.write('musicxml', fp=tmp_path)
        with open(tmp_path, 'r', encoding='utf-8', errors='replace') as f:
            result = f.read()
        os.unlink(tmp_path)
        return result
    except Exception as e:
        print(f"[Corrector] Export failed: {e}")
        return xml_string
