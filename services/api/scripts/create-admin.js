const { randomBytes, randomUUID, scrypt } = require('crypto');
const { readFileSync } = require('fs');
const { Pool } = require('pg');

const args = Object.fromEntries(process.argv.slice(2).map((item) => {
  const [key, ...value] = item.replace(/^--/, '').split('=');
  return [key, value.join('=')];
}));
const secret = (name) => {
  if (process.env[name]?.trim()) return process.env[name].trim();
  const path = process.env[`${name}_FILE`]?.trim() || `/run/secrets/${name.toLowerCase()}`;
  try { return readFileSync(path, 'utf8').trim(); } catch { return ''; }
};
const databaseUrl = secret('DATABASE_URL');
const fullName = (args.name || process.env.ADMIN_NAME || '').trim();
const phoneNumber = (args.phone || process.env.ADMIN_PHONE || '').trim();
const password = secret('ADMIN_PASSWORD');

if (!databaseUrl) throw new Error('DATABASE_URL is required');
if (fullName.length < 3) throw new Error('Provide --name="Full Name" or ADMIN_NAME');
if (!/^\+?[0-9]{9,15}$/.test(phoneNumber)) throw new Error('Provide a valid --phone=... or ADMIN_PHONE');
if (password.length < 12) throw new Error('ADMIN_PASSWORD must contain at least 12 characters');

const pool = new Pool({ connectionString: databaseUrl, application_name: 'create-first-admin' });

function derive(value, salt) {
  return new Promise((resolve, reject) => {
    scrypt(value, salt, 64, { N: 16_384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 }, (error, key) => error ? reject(error) : resolve(key));
  });
}

async function main() {
  const existing = await pool.query(`SELECT id,full_name,phone_number,role FROM users
    WHERE role IN ('admin','platform_admin','super_admin') ORDER BY created_at LIMIT 1`);
  if (existing.rows[0]) {
    throw new Error(`An administrator already exists: ${existing.rows[0].full_name} (${existing.rows[0].role}). Promote additional admins through audited admin operations.`);
  }

  const salt = randomBytes(16);
  const hash = await derive(password, salt);
  const passwordHash = ['scrypt', 'v1', '16384', '8', '1', salt.toString('base64'), hash.toString('base64')].join('$');
  const id = randomUUID();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO users(id,full_name,phone_number,password_hash,language,role)
       VALUES($1,$2,$3,$4,'en','super_admin')`,
      [id, fullName, phoneNumber, passwordHash],
    );
    await client.query(
      `INSERT INTO api_audit_logs(actor_id,action,target_type,target_id,outcome,metadata)
       VALUES($1::uuid,'first_admin_created','user',$1::text,'success',$2)`,
      [id, JSON.stringify({ source: 'cli', role: 'super_admin' })],
    );
    await client.query('COMMIT');
    console.log(JSON.stringify({ created: true, id, fullName, phoneNumber, role: 'super_admin' }));
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}).finally(() => pool.end());
