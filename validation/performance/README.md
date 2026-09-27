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

The runners use `/Applications/Godot.app` by default, launch it behind the
active app with `open -g`, and terminate the child they create. The matrix runs
configurations one at a time; separate invocations are not locked against each other.
Environment variables `PERF_WARMUP`, `PERF_FRAMES`, and `GODOT_APP` can override
the defaults. `PERF_TIMEOUT` controls the per-run 90-second timeout.
