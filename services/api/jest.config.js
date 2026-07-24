/**
 * Jest config for the API. Tests run against an isolated Postgres database
 * (christian_super_app_test) so they never touch dev data on :3000/:5433's
 * primary DB. globalSetup creates the DB and runs migrations once per run.
 */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  transform: {
    '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.spec.json' }],
  },
  rootDir: '.',
  roots: ['<rootDir>/src', '<rootDir>/test'],
  testMatch: ['**/*.spec.ts', '**/*.e2e-spec.ts'],
  globalSetup: '<rootDir>/test/global-setup.ts',
  setupFiles: ['<rootDir>/test/setup-env.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  // Integration tests share one DB; run serially to keep fixtures deterministic.
  maxWorkers: 1,
  testTimeout: 30000,
  clearMocks: true,
};
