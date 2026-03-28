"""Ensemble OMR — run multiple engines and merge best results.

Strategy:
1. Run homr and oemer on the same image
2. Parse both MusicXML outputs with music21
3. For each measure, pick the one with valid duration
4. If both valid, pick the one with more notes (better recall)
5. Apply music theory corrections
"""

import os
import re
import sys
import time
import tempfile

sys.path.insert(0, os.path.dirname(__file__))


def ensemble_omr(image_path: str) -> str | None:
    """Run ensemble OMR and return best MusicXML."""
    results = {}

    # Engine 1: homr
    print("[Ensemble] Running homr...")
    t0 = time.time()
    try:
        from omr_engine import run_omr
        xml_homr = run_omr(image_path)
        if xml_homr:
            n = len(re.findall(r'<note', xml_homr))
            m = len(re.findall(r'<measure', xml_homr))
            results['homr'] = {'xml': xml_homr, 'notes': n, 'measures': m}
            print(f"  homr: {time.time()-t0:.1f}s, {n} notes, {m} measures")
    except Exception as e:
        print(f"  homr failed: {e}")

    # Engine 2: oemer
    print("[Ensemble] Running oemer...")
    t0 = time.time()
    try:
        xml_oemer = _run_oemer(image_path)
        if xml_oemer:
            n = len(re.findall(r'<note', xml_oemer))
            m = len(re.findall(r'<measure', xml_oemer))
            results['oemer'] = {'xml': xml_oemer, 'notes': n, 'measures': m}
            print(f"  oemer: {time.time()-t0:.1f}s, {n} notes, {m} measures")
    except Exception as e:
        print(f"  oemer failed: {e}")

    if not results:
        print("[Ensemble] All engines failed!")
        return None

    # Select best result
    best = _select_best(results)
    print(f"[Ensemble] Selected: {best}")

    xml = results[best]['xml']

    # Apply music theory correction
    try:
        from music_corrector import correct_score
        xml = correct_score(xml)
    except Exception as e:
        print(f"[Ensemble] Correction skipped: {e}")

    return xml


def _run_oemer(image_path: str) -> str | None:
    """Run oemer OMR engine."""
    try:
        output_dir = tempfile.mkdtemp(prefix="oemer_")
        sys_argv_backup = sys.argv
        sys.argv = ['oemer', image_path, '-o', output_dir]

        from oemer.ete import extract, get_parser
        parser = get_parser()
        args = parser.parse_args([image_path, '-o', output_dir])
        extract(args)

        sys.argv = sys_argv_backup

        # Find output MusicXML
        for f in os.listdir(output_dir):
            if f.endswith('.musicxml') or f.endswith('.xml'):
                path = os.path.join(output_dir, f)
                with open(path) as fh:
                    return fh.read()
    except Exception as e:
        print(f"  oemer error: {e}")
    return None


def _select_best(results: dict) -> str:
    """Select best engine result based on quality metrics."""
    if len(results) == 1:
        return list(results.keys())[0]

    # Criteria:
    # 1. Can it be rendered? (valid MusicXML)
    # 2. More notes = better recall
    # 3. More measures = better structure detection

    scores = {}
    for name, data in results.items():
        xml = data['xml']
        score = 0

        # Bonus for more notes
        score += data['notes'] * 2

        # Bonus for more measures
        score += data['measures'] * 5

        # Check if MusicXML parses cleanly
        try:
            import music21
            s = music21.converter.parse(xml, format='musicxml')
            score += 50  # Bonus for valid parse

            # Check measure durations
            valid_measures = 0
            for part in s.parts:
                for m in part.getElementsByClass('Measure'):
                    ts = m.getContextByClass('TimeSignature')
                    if ts:
                        expected = ts.barDuration.quarterLength
                        actual = sum(el.quarterLength for el in m.notesAndRests)
                        if abs(actual - expected) < 0.01:
                            valid_measures += 1
            score += valid_measures * 3
        except Exception:
            pass

        scores[name] = score

    best = max(scores, key=scores.get)
    print(f"[Ensemble] Scores: {scores}")
    return best
