"""MusicXML repair module — fix duration errors from OMR output.

Uses music21 to parse broken MusicXML, fix measure durations,
and re-export clean MusicXML that LilyPond/Verovio can render.
"""

import traceback


def repair(xml_string: str) -> str:
    """Repair MusicXML duration errors via music21 round-trip.

    Strategy:
    1. Parse into music21 Score (tolerant parser)
    2. Fix underfull measures (pad with rests)
    3. Fix overfull measures (trim last element)
    4. Re-export with makeNotation (normalizes beaming, ties, etc.)
    """
    try:
        import music21

        score = music21.converter.parse(xml_string, format="musicxml")

        fixed_count = 0
        for part in score.parts:
            for measure in part.getElementsByClass("Measure"):
                ts = measure.getContextByClass("TimeSignature")
                if ts is None:
                    continue

                expected_ql = ts.barDuration.quarterLength
                actual_ql = 0.0
                for el in measure.notesAndRests:
                    if not el.isChord or el.activeSite == measure:
                        actual_ql += el.quarterLength

                diff = actual_ql - expected_ql

                if abs(diff) < 0.001:
                    continue  # Measure is fine

                if diff < 0:
                    # Underfull: pad with rest
                    gap = expected_ql - actual_ql
                    rest = music21.note.Rest(quarterLength=gap)
                    measure.append(rest)
                    fixed_count += 1
                elif diff > 0:
                    # Overfull: trim last element
                    elements = list(measure.notesAndRests)
                    if elements:
                        last = elements[-1]
                        new_ql = last.quarterLength - diff
                        if new_ql > 0:
                            last.quarterLength = new_ql
                        else:
                            measure.remove(last)
                        fixed_count += 1

        if fixed_count > 0:
            print(f"[MusicXML Repair] Fixed {fixed_count} measures")

        # Re-export with makeNotation
        import tempfile
        import os

        with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            score.write("musicxml", fp=tmp_path)
            with open(tmp_path, "r", encoding="utf-8", errors="replace") as f:
                repaired = f.read()
            return repaired
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    except Exception as e:
        print(f"[MusicXML Repair] Failed: {e}")
        traceback.print_exc()
        return xml_string  # Return original if repair fails
