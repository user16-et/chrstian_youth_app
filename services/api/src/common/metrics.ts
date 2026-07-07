type RouteStats = {
  count: number;
  errorCount: number;
  totalDurationMs: number;
  maxDurationMs: number;
};

type RequestLike = { method?: string; path?: string; url?: string; route?: { path?: string } };

const startedAt = new Date();
const routes = new Map<string, RouteStats>();

export function observeHttpRequest(request: RequestLike, statusCode: number, durationMs: number) {
  const method = request.method ?? 'UNKNOWN';
  const path = normalizePath(request.route?.path ?? request.path ?? request.url ?? 'unknown');
  const key = `${method} ${path}`;
  const current = routes.get(key) ?? { count: 0, errorCount: 0, totalDurationMs: 0, maxDurationMs: 0 };
  current.count += 1;
  current.errorCount += statusCode >= 500 ? 1 : 0;
  current.totalDurationMs += durationMs;
  current.maxDurationMs = Math.max(current.maxDurationMs, durationMs);
  routes.set(key, current);
}

export function metricsSnapshot() {
  const routeMetrics = Array.from(routes.entries()).map(([route, stats]) => ({
    route,
    count: stats.count,
    errorCount: stats.errorCount,
    averageDurationMs: stats.count === 0 ? 0 : Math.round(stats.totalDurationMs / stats.count),
    maxDurationMs: Math.round(stats.maxDurationMs),
  }));
  return {
    startedAt: startedAt.toISOString(),
    uptimeSeconds: Math.round(process.uptime()),
    memory: process.memoryUsage(),
    routes: routeMetrics,
  };
}

export function prometheusMetrics() {
  const lines = [
    '# HELP api_uptime_seconds API process uptime in seconds',
    '# TYPE api_uptime_seconds gauge',
    `api_uptime_seconds ${Math.round(process.uptime())}`,
    '# HELP api_http_requests_total HTTP requests by route',
    '# TYPE api_http_requests_total counter',
    '# HELP api_http_errors_total HTTP 5xx responses by route',
    '# TYPE api_http_errors_total counter',
    '# HELP api_http_request_duration_ms_avg Average HTTP request duration by route',
    '# TYPE api_http_request_duration_ms_avg gauge',
  ];
  for (const item of metricsSnapshot().routes) {
    const labels = labelRoute(item.route);
    lines.push(`api_http_requests_total{route="${labels}"} ${item.count}`);
    lines.push(`api_http_errors_total{route="${labels}"} ${item.errorCount}`);
    lines.push(`api_http_request_duration_ms_avg{route="${labels}"} ${item.averageDurationMs}`);
  }
  return `${lines.join('\n')}\n`;
}

function normalizePath(path: string) {
  return path.split('?')[0].replace(/[0-9a-f]{8}-[0-9a-f-]{27,}/gi, ':id');
}

function labelRoute(route: string) {
  return route.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}
