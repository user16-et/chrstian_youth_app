import type { AppConfig } from './config';

/**
 * Unit coverage for loadConfig's production guards — the boot-time safety net
 * that refuses to start with insecure/incomplete production configuration.
 * Each case runs in an isolated module so the module-level config cache resets.
 */
describe('loadConfig production guards', () => {
  // Env keys the guards care about; cleared before each case, restored after.
  const KEYS = [
    'NODE_ENV', 'DATABASE_URL', 'JWT_SECRET', 'MEDIA_STORAGE_PROVIDER', 'MEDIA_BUCKET',
    'REDIS_URL', 'VIRUS_SCAN_PROVIDER', 'CORS_ORIGINS', 'PAYMENT_PROVIDER', 'CHAPA_SECRET_KEY',
  ];

  const PROD_OK: Record<string, string | undefined> = {
    NODE_ENV: 'production',
    DATABASE_URL: 'postgres://user:pass@localhost:5432/app',
    JWT_SECRET: 'x'.repeat(32),
    MEDIA_STORAGE_PROVIDER: 's3',
    MEDIA_BUCKET: 'bucket',
    REDIS_URL: 'redis://localhost:6379',
    VIRUS_SCAN_PROVIDER: 'clamav',
    CORS_ORIGINS: 'https://app.example.com',
  };

  function inEnv(overrides: Record<string, string | undefined>, run: (loadConfig: () => AppConfig) => void) {
    const saved: Record<string, string | undefined> = {};
    for (const k of KEYS) { saved[k] = process.env[k]; delete process.env[k]; }
    for (const [k, v] of Object.entries(overrides)) if (v !== undefined) process.env[k] = v;
    try {
      jest.isolateModules(() => run((require('./config') as typeof import('./config')).loadConfig));
    } finally {
      for (const k of KEYS) { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }
    }
  }

  it('accepts a development config with defaults', () => {
    inEnv({ NODE_ENV: 'development', DATABASE_URL: PROD_OK.DATABASE_URL }, (loadConfig) => {
      const cfg = loadConfig();
      expect(cfg.nodeEnv).toBe('development');
      expect(cfg.paymentProvider).toBe('mock');
    });
  });

  it('accepts a fully-configured production config', () => {
    inEnv(PROD_OK, (loadConfig) => {
      expect(loadConfig().nodeEnv).toBe('production');
    });
  });

  it.each([
    ['JWT_SECRET too short', { ...PROD_OK, JWT_SECRET: 'short' }, /JWT_SECRET/],
    ['media storage disabled', { ...PROD_OK, MEDIA_STORAGE_PROVIDER: undefined }, /MEDIA_STORAGE_PROVIDER/],
    ['redis missing', { ...PROD_OK, REDIS_URL: undefined }, /REDIS_URL/],
    ['virus scan not clamav', { ...PROD_OK, VIRUS_SCAN_PROVIDER: undefined }, /VIRUS_SCAN_PROVIDER/],
    ['cors empty', { ...PROD_OK, CORS_ORIGINS: undefined }, /CORS_ORIGINS/],
    ['payment mock in prod', { ...PROD_OK, PAYMENT_PROVIDER: 'mock' }, /PAYMENT_PROVIDER/],
  ])('rejects production when %s', (_name, env, pattern) => {
    inEnv(env, (loadConfig) => expect(() => loadConfig()).toThrow(pattern));
  });

  it('requires a Chapa secret key when the provider is chapa (any env)', () => {
    inEnv({ NODE_ENV: 'development', DATABASE_URL: PROD_OK.DATABASE_URL, PAYMENT_PROVIDER: 'chapa' }, (loadConfig) => {
      expect(() => loadConfig()).toThrow(/CHAPA_SECRET_KEY/);
    });
  });

  it('does not cache an invalid config: a second call still throws', () => {
    inEnv({ ...PROD_OK, MEDIA_STORAGE_PROVIDER: undefined }, (loadConfig) => {
      expect(() => loadConfig()).toThrow(/MEDIA_STORAGE_PROVIDER/);
      // Before the fix, the invalid config was cached and this second call
      // returned it without re-validating.
      expect(() => loadConfig()).toThrow(/MEDIA_STORAGE_PROVIDER/);
    });
  });
});
