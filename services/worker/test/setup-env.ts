// Point any DB-using code at the isolated test DB before modules load.
import { TEST_DATABASE_URL } from './test-db';

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.DATABASE_READ_URL = TEST_DATABASE_URL;
