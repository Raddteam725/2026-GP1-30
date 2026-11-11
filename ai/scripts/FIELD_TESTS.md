# Field tests (PBI 13 follow-up)

These scripts test the face-matching models outside the app. They are self-contained:
they import nothing from `backend/`, so they keep working when the app code changes.
Run them from the repository folder, with the datasets in `ai/data`.
`ai/data` is never committed.

| Script | What it measures |
|---|---|
| `radd_engines.py` | The engines: `arcface` (C7, ArcFace R50, the app's engine), `facenet512` (C6), `arcface100` |
| `radd_model_compare.py` | Open-set search comparison of engines by age band (thresholds set on half the identities, reported on the other half) |
| `radd_photo_test.py` | Reusable test for the team's own photos (`--watch` re-runs when photos are added) |
| `radd_utkface_false_match.py` | False matches by age band (UTKFace has no identity labels, so it measures false matches only) |
| `radd_utkface_diagnose.py` | Finer age groups and probable duplicates behind the false matches |
| `radd_margin_test.py` | The "clear winner" rule for ages 0–5 (minimum score plus a gap to the next person) |
| `radd_utkface_holdout.py` | Held-out check of the age rules: thresholds chosen on one half of UTKFace with a fixed rule, results reported on the other half only |
| `agedb_sensitivity.py` | AgeDB results recomputed without the names flagged by the identity check (numbers only; names are never written) |

Models are read from `~/RaddModels/` (`w600k_r50.onnx`; `glintr100.onnx` only for `arcface100`).
They are never committed. InsightFace models are licensed for non-commercial research only.

## Privacy rules

- Our own photos stay in `~/RaddTest/people/<code_name>/`. Use code names only (`kid1`, `kid2`), and delete the photos after testing.
- No photos are copied or uploaded. Embeddings of our own photos are never saved to disk.
- Results (`~/RaddTest/results`) can contain dataset file names, which include celebrity names. Results are not committed. Only the numbers go into the report.
