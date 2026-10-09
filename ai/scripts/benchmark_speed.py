"""Speed and resource benchmark for all candidate models on ONE machine (PBI 13).

Run by ONE person only, so the numbers are comparable:
    python scripts/benchmark_speed.py

Each model is measured in its own fresh Python process, so memory numbers are
fair (no model benefits from another having already started TensorFlow).
Per model: process memory after loading the model (framework included), model
load time, weights file size, and time per photo (YuNet detection + embedding)
over 100 LFW images. Writes results/speed.json (numbers only).
"""
import argparse
import json
import os
import platform
import random
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import psutil

from lfw_common import MODELS, DEFAULT_DETECTOR, RESULTS, IMG

WEIGHTS = {
    "ArcFace": "arcface_weights.h5",
    "Facenet512": "facenet512_weights.h5",
    "SFace": "face_recognition_sface_2021dec.onnx",
}
N_IMAGES, WARMUP = 100, 5


def measure(model):
    """Runs inside a fresh process."""
    proc = psutil.Process(os.getpid())
    rss_start = proc.memory_info().rss
    from deepface import DeepFace
    images = sorted(str(p) for p in IMG.rglob("*.jpg"))
    random.seed(0)
    sample = random.sample(images, N_IMAGES + WARMUP)
    DeepFace.extract_faces(sample[0], detector_backend=DEFAULT_DETECTOR, enforce_detection=False)
    rss_before_model = proc.memory_info().rss
    t0 = time.perf_counter()
    DeepFace.build_model(model)
    load_s = time.perf_counter() - t0
    for p in sample[:WARMUP]:
        DeepFace.represent(img_path=p, model_name=model, detector_backend=DEFAULT_DETECTOR, enforce_detection=False)
    rss_ready = proc.memory_info().rss
    times = []
    for p in sample[WARMUP:]:
        t = time.perf_counter()
        DeepFace.represent(img_path=p, model_name=model, detector_backend=DEFAULT_DETECTOR, enforce_detection=False)
        times.append(time.perf_counter() - t)
    w = Path.home() / ".deepface" / "weights" / WEIGHTS[model]
    return {
        "load_seconds": round(load_s, 2),
        "process_memory_ready_mb": round(rss_ready / 1e6, 1),
        "memory_added_by_model_and_first_runs_mb": round((rss_ready - rss_before_model) / 1e6, 1),
        "process_memory_at_start_mb": round(rss_start / 1e6, 1),
        "weights_file_mb": round(w.stat().st_size / 1e6, 1) if w.exists() else None,
        "ms_per_photo_mean": round(statistics.mean(times) * 1000, 1),
        "ms_per_photo_median": round(statistics.median(times) * 1000, 1),
        "ms_per_photo_p95": round(sorted(times)[int(0.95 * len(times)) - 1] * 1000, 1),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", choices=MODELS, help=argparse.SUPPRESS)  # internal: one model per process
    args = ap.parse_args()
    if args.model:
        print("RESULT_JSON " + json.dumps(measure(args.model)), flush=True)
        return

    results = {
        "date_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "machine": {"system": platform.system(), "processor": platform.processor(),
                    "cpu_count": os.cpu_count(), "ram_gb": round(psutil.virtual_memory().total / 1e9, 1),
                    "python": platform.python_version()},
        "detector": DEFAULT_DETECTOR, "images_timed": N_IMAGES,
        "method": "each model measured in a separate fresh process",
        "models": {},
    }
    for model in MODELS:
        # UTF-8 so DeepFace's emoji warnings don't crash the child process on Windows
        env = {**os.environ, "PYTHONIOENCODING": "utf-8", "PYTHONUTF8": "1"}
        out = subprocess.run([sys.executable, __file__, "--model", model], capture_output=True,
                             text=True, encoding="utf-8", errors="replace", env=env)
        line = next((l for l in out.stdout.splitlines() if l.startswith("RESULT_JSON ")), None)
        if line is None:
            print(out.stdout[-2000:], out.stderr[-2000:])
            raise RuntimeError(f"{model} benchmark failed")
        results["models"][model] = json.loads(line[len("RESULT_JSON "):])
        print(model, results["models"][model], flush=True)

    RESULTS.mkdir(exist_ok=True)
    (RESULTS / "speed.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\nSaved to {RESULTS / 'speed.json'}")


if __name__ == "__main__":
    main()
