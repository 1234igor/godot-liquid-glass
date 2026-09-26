# Dynamic performance fixture

`benchmark.tscn` renders a continuously changing photographic shader beneath
moving Liquid Glass panels. The fixture records frame-time percentiles, missed
120 Hz and 60 Hz intervals, draw calls, renderer identity, and the active
capture strategy as JSON.

Run one configuration:

```sh
validation/performance/run.sh regular 24 /tmp/regular-24.json
```

Run every material:

```sh
validation/performance/run-matrix.sh /tmp/godot-liquid-glass-performance
```

Both runners use the exact `/Applications/Godot.app` bundle, launch it behind
the active app with `open -g`, serialize launches, and terminate only the child
they create.
Environment variables `PERF_WARMUP`, `PERF_FRAMES`, and `GODOT_APP` can override
the defaults. `PERF_TIMEOUT` controls the per-run 90-second timeout.
