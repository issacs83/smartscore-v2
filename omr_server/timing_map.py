"""Timing Map Generator — MusicXML to measure-beat-timestamp mapping.

Parses MusicXML and generates a timing map that maps each measure/beat
to an absolute time position given a tempo. Used by:
1. OTW score follower (reference frame → musical position)
2. MIDI playback sync
3. Page turn engine (measure → page mapping)
"""

import music21


def generate_timing_map(musicxml_str: str, default_tempo: float = 120.0) -> dict:
    """Generate timing map from MusicXML string.

    Returns:
        {
            "success": True,
            "tempo_bpm": 120.0,
            "time_signature": "3/4",
            "total_duration_sec": 180.5,
            "total_measures": 48,
            "measures": [
                {
                    "number": 1,
                    "start_sec": 0.0,
                    "end_sec": 1.5,
                    "beat_count": 3,
                    "quarter_length": 3.0,
                    "beats": [
                        {"beat": 1, "time_sec": 0.0},
                        {"beat": 2, "time_sec": 0.5},
                        {"beat": 3, "time_sec": 1.0}
                    ]
                }
            ]
        }
    """
    try:
        score = music21.converter.parse(musicxml_str, format="musicxml")
    except Exception as e:
        return {"success": False, "error": f"Parse failed: {e}"}

    # Find tempo
    tempo_bpm = default_tempo
    for el in score.recurse():
        if isinstance(el, music21.tempo.MetronomeMark):
            tempo_bpm = el.number
            break

    # Find initial time signature
    time_sig_str = "4/4"
    for el in score.recurse():
        if isinstance(el, music21.meter.TimeSignature):
            time_sig_str = el.ratioString
            break

    # Quarter note duration in seconds
    quarter_sec = 60.0 / tempo_bpm

    # Process measures from first part (piano right hand or melody)
    parts = score.parts
    if not parts:
        return {"success": False, "error": "No parts found"}

    part = parts[0]
    measures_data = []
    current_time = 0.0
    current_ts = None

    for measure in part.getElementsByClass("Measure"):
        # Update time signature if changed
        ts = measure.getContextByClass("TimeSignature")
        if ts:
            current_ts = ts

        if current_ts is None:
            current_ts = music21.meter.TimeSignature("4/4")

        beat_count = current_ts.numerator
        beat_type = current_ts.denominator
        measure_ql = current_ts.barDuration.quarterLength
        measure_sec = measure_ql * quarter_sec

        # Generate beat positions
        beats = []
        beat_ql = 4.0 / beat_type  # quarter length per beat
        for b in range(beat_count):
            beat_time = current_time + (b * beat_ql * quarter_sec)
            beats.append({
                "beat": b + 1,
                "time_sec": round(beat_time, 4),
            })

        measure_num = measure.number if measure.number else len(measures_data) + 1

        measures_data.append({
            "number": measure_num,
            "start_sec": round(current_time, 4),
            "end_sec": round(current_time + measure_sec, 4),
            "beat_count": beat_count,
            "quarter_length": measure_ql,
            "time_signature": f"{beat_count}/{beat_type}",
            "beats": beats,
        })

        current_time += measure_sec

    total_duration = current_time

    return {
        "success": True,
        "tempo_bpm": tempo_bpm,
        "time_signature": time_sig_str,
        "total_duration_sec": round(total_duration, 4),
        "total_measures": len(measures_data),
        "measures": measures_data,
    }
