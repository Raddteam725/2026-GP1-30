"""Speed and resource benchmark for all candidate models on ONE machine (PBI 13).

Run by ONE person only, so the numbers are comparable:
    python scripts/benchmark_speed.py

Per model: model load time, process memory after loading, weights file size,
and average time per photo (YuNet detection + embedding) over 100 LFW images.
Writes results/speed.json (numbers only).
"""
import gc
import json
import os
import platform
import random
import statistics
import time
from datetime import datetime, timezone
from pathlib import Path

import psutil

from lfw_common import MODELS, DETECTOR, RESULTS, IMG

WEIGHTS = {
    "ArcFace": "arcface_weights.h5",
    "Facenet512": "facenet512_weights.h5",
    "SFace": "face_recognition_sface_2021dec.onnx",
}
N_IMAGES, WARMUP = 100, 5


def main():
    from deepface import DeepFace
    proc = psutil.Process(os.getpid())
    images = sorted(str(p) for p in IMG.rglob("*.jpg"))
    random.seed(0)
    sample = random.sample(images, N_IMAGES + WARMUP)
    DeepFace.extract_faces(sample[0], detector_backend=DETECTOR, enforce_detection=False)  # load detector

    weights_dir = Path.home() / ".deepface" / "weights"
    results = {
        "date_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "machine": {"system": platform.system(), "processor": platform.processor(),
                    "cpu_count": os.cpu_count(), "ram_gb": round(psutil.virtual_memory().total / 1e9, 1),
                    "python": platform.python_version()},
        "detector": DETECTOR, "images_timed": N_IMAGES, "models": {},
    }
    for model in MODELS:
        gc.collect()
        rss0 = proc.memory_info().rss
        t0 = time.perf_counter()
        DeepFace.build_model(model)
        load_s = time.perf_counter() - t0
        rss1 = proc.memory_info().rss
        for p in sample[:WARMUP]:
            DeepFace.represent(img_path=p, model_name=model, detector_backend=DETECTOR, enforce_detection=False)
        times = []
        for p in sample[WARMUP:]:
            t = time.perf_counter()
            DeepFace.represent(img_path=p, model_name=model, detector_backend=DETECTOR, enforce_detection=False)
            times.append(time.perf_counter() - t)
        w = weights_dir / WEIGHTS[model]
        results["models"][model] = {
            "load_seconds": round(load_s, 2),
            "memory_added_by_model_mb": round((rss1 - rss0) / 1e6, 1),
            "weights_file_mb": round(w.stat().st_size / 1e6, 1) if w.exists() else None,
            "ms_per_photo_mean": round(statistics.mean(times) * 1000, 1),
            "ms_per_photo_median": round(statistics.median(times) * 1000, 1),
            "ms_per_photo_p95": round(sorted(times)[int(0.95 * len(times)) - 1] * 1000, 1),
        }
        print(model, results["models"][model], flush=True)

    RESULTS.mkdir(exist_ok=True)
    (RESULTS / "speed.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\nSaved to {RESULTS / 'speed.json'}")


if __name__ == "__main__":
    main()
