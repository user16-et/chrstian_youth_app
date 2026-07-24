import http from 'k6/http';
import { check, group, sleep } from 'k6';

// Load/perf baseline for the API's hot read paths. These numbers are the
// reference point for Phase 5 optimization work — run before and after a change
// and compare p95 latency and error rate.
//
// Target the TEST API (default :3100), never the dev API on :3000.
//   BASE_URL=http://localhost:3100 k6 run load/read-paths.js
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3100';

export const options = {
  stages: [
    { duration: '30s', target: 20 }, // ramp up
    { duration: '1m', target: 20 }, // steady
    { duration: '30s', target: 50 }, // spike
    { duration: '30s', target: 0 }, // ramp down
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'], // <1% errors
    http_req_duration: ['p(95)<500', 'p(99)<1500'],
    'group_duration{group:::health}': ['p(95)<150'],
  },
};

export default function () {
  group('health', () => {
    const res = http.get(`${BASE_URL}/health`);
    check(res, { 'health 200': (r) => r.status === 200 });
  });

  group('bible-read', () => {
    const versions = http.get(`${BASE_URL}/bible/versions`);
    check(versions, { 'versions 200': (r) => r.status === 200 });

    const daily = http.get(`${BASE_URL}/bible/daily-verses`);
    check(daily, { 'daily-verses 200': (r) => r.status === 200 });
  });

  sleep(1);
}
