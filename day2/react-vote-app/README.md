# Day 2 — Resilient UI: useState Vote Counter

Interactive **Vote** button backed by **useState**, optional main-thread blocking demo,
and a **Live Metrics Dashboard**.

## Quick start

```bash
bash start.sh --serve    # dashboard http://127.0.0.1:3000
bash start.sh --demo     # run demo + validate metrics
bash start.sh --test     # vitest
bash stop.sh             # stop servers
bash cleanup.sh          # stop + remove caches, node_modules, venv
```

## Failure demo

1. Toggle **Enable blocking demo** on the page, or click **Run Demo**.
2. Blocking freezes the UI for ~5s and updates dashboard metrics.
3. Metrics: Total Votes, Click Events, Main Thread Blocks, Last Block (ms),
   UI Freeze Detected, Responsiveness, Demo Runs.
