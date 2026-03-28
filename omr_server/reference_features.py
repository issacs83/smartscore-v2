"""Reference Feature Generator — MusicXML to CENS chroma features.

Pipeline:
  MusicXML → music21 → MIDI → FluidSynth/timidity → WAV → librosa CENS
  → Annotated chroma frames with (measure, beat) mapping

Each frame contains:
  - 12-dim CENS chroma vector
  - timestamp in seconds
  - corresponding measure number and beat
"""

import hashlib
import json
import os
import subprocess
import tempfile

import numpy as np

from timing_map import generate_timing_map

# Cache directory for pre-computed features
CACHE_DIR = os.path.join(os.path.dirname(__file__), "chroma_cache")
os.makedirs(CACHE_DIR, exist_ok=True)

# CENS parameters (matching WAC 2024 paper)
SAMPLE_RATE = 22050
HOP_LENGTH = 1856  # ~84ms at 22050 Hz
WIN_LEN_SMOOTH = 5


def generate_reference_features(
    musicxml_str: str,
    tempo_bpm: float = 120.0,
    use_cache: bool = True,
) -> dict:
    """Generate CENS chroma reference features from MusicXML.

    Returns:
        {
            "success": True,
            "score_hash": "abc123...",
            "sample_rate": 22050,
            "hop_length": 1856,
            "hop_ms": 84.2,
            "total_frames": 1200,
            "total_duration_sec": 101.0,
            "frames": [
                {
                    "index": 0,
                    "time_sec": 0.0,
                    "measure": 1,
                    "beat": 1.0,
                    "chroma": [0.42, 0.0, ...]  // 12 values
                }
            ]
        }
    """
    # Check cache
    score_hash = hashlib.sha256(musicxml_str.encode()).hexdigest()[:16]
    cache_path = os.path.join(CACHE_DIR, f"{score_hash}.json")

    if use_cache and os.path.exists(cache_path):
        print(f"[RefFeatures] Cache hit: {cache_path}")
        with open(cache_path) as f:
            return json.load(f)

    # Step 1: Generate timing map
    timing = generate_timing_map(musicxml_str, tempo_bpm)
    if not timing.get("success"):
        return {"success": False, "error": timing.get("error", "Timing map failed")}

    # Step 2: MusicXML → MIDI → WAV
    wav_path = _synthesize_to_wav(musicxml_str, tempo_bpm)
    if not wav_path:
        return {"success": False, "error": "Audio synthesis failed"}

    try:
        # Step 3: Extract CENS features
        frames = _extract_cens(wav_path)
        if not frames:
            return {"success": False, "error": "CENS extraction failed"}

        # Step 4: Annotate frames with measure/beat
        hop_sec = HOP_LENGTH / SAMPLE_RATE
        annotated = _annotate_frames(frames, hop_sec, timing["measures"])

        result = {
            "success": True,
            "score_hash": score_hash,
            "sample_rate": SAMPLE_RATE,
            "hop_length": HOP_LENGTH,
            "hop_ms": round(hop_sec * 1000, 1),
            "total_frames": len(annotated),
            "total_duration_sec": timing["total_duration_sec"],
            "tempo_bpm": timing["tempo_bpm"],
            "frames": annotated,
        }

        # Cache result
        with open(cache_path, "w") as f:
            json.dump(result, f)
        print(f"[RefFeatures] Cached: {cache_path} ({len(annotated)} frames)")

        return result

    finally:
        if os.path.exists(wav_path):
            os.unlink(wav_path)


def _synthesize_to_wav(musicxml_str: str, tempo_bpm: float) -> str | None:
    """Synthesize MusicXML to WAV using music21 + MIDI + timidity/fluidsynth."""
    try:
        import music21

        score = music21.converter.parse(musicxml_str, format="musicxml")

        # Write MIDI
        with tempfile.NamedTemporaryFile(suffix=".mid", delete=False) as tmp:
            midi_path = tmp.name
        score.write("midi", fp=midi_path)

        # MIDI → WAV (try timidity first, then fluidsynth)
        wav_path = midi_path.replace(".mid", ".wav")

        # Try timidity
        result = subprocess.run(
            ["timidity", midi_path, "-Ow", "-o", wav_path,
             f"--output-mono", f"--sampling-freq={SAMPLE_RATE}"],
            capture_output=True, text=True, timeout=60,
        )
        if result.returncode == 0 and os.path.exists(wav_path):
            os.unlink(midi_path)
            return wav_path

        # Try fluidsynth
        sf2_paths = [
            "/usr/share/sounds/sf2/FluidR3_GM.sf2",
            "/usr/share/soundfonts/FluidR3_GM.sf2",
            "/usr/share/sounds/sf2/default-GM.sf2",
        ]
        sf2 = None
        for p in sf2_paths:
            if os.path.exists(p):
                sf2 = p
                break

        if sf2:
            result = subprocess.run(
                ["fluidsynth", "-ni", sf2, midi_path, "-F", wav_path,
                 "-r", str(SAMPLE_RATE), "-g", "1.0"],
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode == 0 and os.path.exists(wav_path):
                os.unlink(midi_path)
                return wav_path

        # Fallback: use music21's built-in (if available)
        os.unlink(midi_path)
        print("[RefFeatures] No MIDI synthesizer available (install timidity or fluidsynth)")
        return None

    except Exception as e:
        print(f"[RefFeatures] Synthesis error: {e}")
        return None


def _extract_cens(wav_path: str) -> list[list[float]] | None:
    """Extract CENS chroma features from WAV file."""
    try:
        import librosa

        y, sr = librosa.load(wav_path, sr=SAMPLE_RATE, mono=True)
        chroma = librosa.feature.chroma_cens(
            y=y, sr=sr,
            hop_length=HOP_LENGTH,
            win_len_smooth=WIN_LEN_SMOOTH,
        )
        # chroma shape: (12, n_frames)
        frames = chroma.T.tolist()  # (n_frames, 12)
        print(f"[RefFeatures] CENS: {len(frames)} frames from {len(y)/sr:.1f}s audio")
        return frames

    except ImportError:
        print("[RefFeatures] librosa not installed. pip install librosa")
        return None
    except Exception as e:
        print(f"[RefFeatures] CENS error: {e}")
        return None


def _annotate_frames(
    frames: list[list[float]],
    hop_sec: float,
    measures: list[dict],
) -> list[dict]:
    """Annotate each CENS frame with measure number and beat."""
    annotated = []
    for i, chroma in enumerate(frames):
        time_sec = i * hop_sec

        # Find which measure this timestamp belongs to
        measure_num = 1
        beat = 1.0
        for m in measures:
            if m["start_sec"] <= time_sec < m["end_sec"]:
                measure_num = m["number"]
                # Calculate beat within measure
                elapsed_in_measure = time_sec - m["start_sec"]
                measure_dur = m["end_sec"] - m["start_sec"]
                if measure_dur > 0:
                    beat = 1.0 + (elapsed_in_measure / measure_dur) * m["beat_count"]
                break
            elif time_sec >= m["end_sec"]:
                measure_num = m["number"]
                beat = m["beat_count"]

        annotated.append({
            "index": i,
            "time_sec": round(time_sec, 4),
            "measure": measure_num,
            "beat": round(beat, 2),
            "chroma": [round(v, 6) for v in chroma],
        })

    return annotated
