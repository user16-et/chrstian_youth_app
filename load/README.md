# Load / performance baselines (k6)

These [k6](https://k6.io) scripts establish latency/error baselines for the
API's hot paths. They are the reference point for Phase 5 optimization: capture
a baseline, make a change, re-run, and compare `http_req_duration` p95/p99 and
`http_req_failed`.

## Safety

**Always target the test API (default `http://localhost:3100`), never the dev
API on `:3000`.** Load-testing hammers the target; point it at a throwaway
instance backed by the test database.

## Install k6

```bash
# Debian/Ubuntu
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6
# or: brew install k6
```

## Run

```bash
# Read paths (health + bible reads)
BASE_URL=http://localhost:3100 k6 run load/read-paths.js
```

## Thresholds

The scripts fail (non-zero exit) if a threshold is breached, so they double as a
CI perf gate once a stable test target exists:

- `http_req_failed` < 1%
- `http_req_duration` p95 < 500ms, p99 < 1500ms
- `/health` p95 < 150ms

## Next scripts to add

- Authenticated write paths (login → post → feed read) using a seeded user.
- Personalized feed pagination under load (needs feed_events seeded).
