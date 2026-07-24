/**
 * Jest config for the worker. Uses the same isolated Postgres database as the
 * API tests (christian_super_app_test); globalSetup ensures it exists and is
 * migrated (migrations live in services/api).
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
  maxWorkers: 1,
  testTimeout: 30000,
  clearMocks: true,
};
