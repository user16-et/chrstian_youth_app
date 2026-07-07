import { Controller, Get } from '@nestjs/common';

import { AppStore } from './app.store';

@Controller('/app')
export class AppBootstrapController {
  constructor(private readonly appStore: AppStore) {}

  @Get('/bootstrap')
  bootstrap() {
    return this.appStore.bootstrap();
  }

  @Get('/summary')
  summary() {
    return this.appStore.summary();
  }
}
