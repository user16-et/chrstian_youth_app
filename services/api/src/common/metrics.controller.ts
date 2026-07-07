import { Controller, Get, Header } from '@nestjs/common';

import { metricsSnapshot, prometheusMetrics } from './metrics';

@Controller()
export class MetricsController {
  @Get('/metrics.json')
  json() {
    return metricsSnapshot();
  }

  @Get('/metrics')
  @Header('content-type', 'text/plain; version=0.0.4')
  text() {
    return prometheusMetrics();
  }
}
