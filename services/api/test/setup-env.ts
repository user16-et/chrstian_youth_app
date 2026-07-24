// Point the app at the isolated test DB before any application module loads and
// caches its config. Runs (via setupFiles) before the test framework and the
// test file itself.
import { TEST_DATABASE_URL } from './test-db';

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.DATABASE_READ_URL = TEST_DATABASE_URL;
