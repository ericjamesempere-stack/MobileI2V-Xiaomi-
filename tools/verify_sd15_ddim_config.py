#!/usr/bin/env python3
"""Compare the exact SD1.5 scheduler metadata to DDIM assumptions; fail closed."""
import json
import math
import sys
from pathlib import Path

def check(path):
    cfg = json.loads(Path(path).read_text())
    expected = {"num_train_timesteps": 1000, "beta_start": 0.00085,
                "beta_end": 0.012, "beta_schedule": "scaled_linear"}
    for key, value in expected.items():
        if cfg.get(key) != value:
            raise ValueError(f"scheduler {key}: expected {value!r}, actual {cfg.get(key)!r}")
    if cfg.get("prediction_type", "epsilon") != "epsilon":
        raise ValueError("DDIM implementation requires epsilon prediction")
    if cfg.get("variance_type", "fixed_small") not in ("fixed_small", "fixed_small_log"):
        raise ValueError("unexpected variance setting")
    alphas = []
    cumulative = 1.0
    for i in range(1000):
        beta = (math.sqrt(expected["beta_start"]) +
                (math.sqrt(expected["beta_end"]) - math.sqrt(expected["beta_start"])) * i / 999) ** 2
        cumulative *= 1.0 - beta
        alphas.append(cumulative)
    if not (0 < alphas[-1] < alphas[0] < 1):
        raise ValueError("alpha schedule invalid")
    for steps in (10, 20, 50):
        ratio = 1000 // steps
        timesteps = list(range(0, 1000, ratio))[::-1][:steps]
        if len(timesteps) != steps or any(timesteps[i] <= timesteps[i+1] for i in range(steps-1)):
            raise ValueError("invalid DDIM timestep sequence")
    print("KARMA_SD15_DDIM_CONFIG_REFERENCE_OK", "alpha0=", alphas[0],
          "alpha999=", alphas[-1], "prediction=epsilon")
if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: verify_sd15_ddim_config.py scheduler_config.json")
    check(sys.argv[1])
