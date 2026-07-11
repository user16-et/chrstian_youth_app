import 'reflect-metadata';

import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

import { AppModule } from './app.module';
import { ApiExceptionFilter } from './common/api-exception.filter';
import { createAuditLogMiddleware } from './common/audit-log.middleware';
import { loadConfig } from './common/config';
import { metricsMiddleware } from './common/metrics.middleware';
import { rateLimitMiddleware } from './common/rate-limit.middleware';
import { requestContextMiddleware } from './common/request-context.middleware';
import { createSecurityMiddleware } from './common/security.middleware';

async function bootstrap() {
  const appConfig = loadConfig();
  // rawBody: capture the unparsed body so payment webhooks can verify HMAC
  // signatures over the exact bytes the gateway signed.
  const app = await NestFactory.create(AppModule, { rawBody: true });
  if (appConfig.trustProxy) {
    app.getHttpAdapter().getInstance().set('trust proxy', 1);
  }
  app.enableCors({
    origin: appConfig.corsOrigins.length > 0 ? appConfig.corsOrigins : true,
    credentials: true,
  });
  app.use(createSecurityMiddleware(appConfig));
  app.use(requestContextMiddleware);
  if (appConfig.metricsEnabled) {
    app.use(metricsMiddleware);
  }
  app.use(rateLimitMiddleware);
  app.use(createAuditLogMiddleware(appConfig));
  app.useGlobalFilters(new ApiExceptionFilter());
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const config = new DocumentBuilder()
    .setTitle('Christian Youth Super App API')
    .setDescription('NestJS API for the Ethiopia-focused Christian youth super app')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('/docs', app, document);

  // Bind all interfaces (0.0.0.0) so the API is reachable from devices on the
  // network / by public IP, not just localhost.
  await app.listen(appConfig.port, '0.0.0.0');
}

void bootstrap();
