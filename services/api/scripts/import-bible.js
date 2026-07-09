'use strict';

/**
 * Imports Bible text into bible_versions / bible_books / bible_verses from the
 * Free Use Bible API (bible.helloao.org, sourced from eBible.org).
 *
 * Usage:  DATABASE_URL=... node scripts/import-bible.js [kjv] [amh]
 * With no args it imports every translation in TRANSLATIONS below.
 *
 * - KJV (eng_kjv) is public domain: full 66-book canon.
 * - Amharic (amh_amh) is, in the open sources, New Testament only; the full
 *   1962 Amharic Old Testament is under Bible Society of Ethiopia copyright and
 *   must be licensed before it can be added here.
 */

const { Pool } = require('pg');

const API = 'https://bible.helloao.org/api';

const TRANSLATIONS = {
  kjv: {
    source: 'eng_kjv',
    name: 'King James Version',
    language: 'en',
    copyright: 'Public domain.',
    license: 'available',
  },
  amh: {
    source: 'amh_amh',
    name: 'Amharic Bible',
    language: 'am',
    copyright:
      'Amharic Scriptures via eBible.org. New Testament only; full Old Testament requires a Bible Society of Ethiopia license.',
    license: 'partial_available',
  },
};

async function getJson(url, attempt = 1) {
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (error) {
    if (attempt < 4) {
      await new Promise((r) => setTimeout(r, 400 * attempt));
      return getJson(url, attempt + 1);
    }
    throw new Error(`Failed ${url}: ${error.message}`);
  }
}

// Run tasks with a small concurrency limit so we are gentle on the API.
async function pooled(items, limit, worker) {
  const queue = [...items.entries()];
  const results = [];
  async function run() {
    while (queue.length) {
      const [i, item] = queue.shift();
      results[i] = await worker(item, i);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, run));
  return results;
}

function versesFromChapter(chapter) {
  const out = [];
  for (const item of chapter.content || []) {
    if (item.type !== 'verse' || item.number == null) continue;
    const text = (item.content || [])
      .map((c) => (typeof c === 'string' ? c : c && typeof c.text === 'string' ? c.text : ''))
      .join(' ')
      .replace(/¶/g, ' ') // drop paragraph markers from the source
      .replace(/\s+/g, ' ')
      .trim();
    if (text) out.push({ verse: item.number, text });
  }
  return out;
}

async function seedBooks(pool) {
  // English canon (66 books, chapter counts) comes from the KJV book list;
  // Amharic display names come from the Amharic NT where available.
  const [engBooks, amhBooks] = await Promise.all([
    getJson(`${API}/eng_kjv/books.json`),
    getJson(`${API}/amh_amh/books.json`),
  ]);
  const eng = engBooks.books || engBooks;
  const amhName = new Map((amhBooks.books || amhBooks).map((b) => [b.id, b.commonName || b.name]));

  for (const b of eng) {
    const testament = b.order <= 39 ? 'Old Testament' : 'New Testament';
    await pool.query(
      `INSERT INTO bible_books (id, code, name, name_am, testament, book_order, chapters)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6)
       ON CONFLICT (code) WHERE code IS NOT NULL DO UPDATE SET
         name = EXCLUDED.name, name_am = COALESCE(EXCLUDED.name_am, bible_books.name_am),
         testament = EXCLUDED.testament, book_order = EXCLUDED.book_order, chapters = EXCLUDED.chapters`,
      [b.id, b.commonName || b.name, amhName.get(b.id) || null, testament, b.order, b.numberOfChapters],
    );
  }
  console.log(`Seeded ${eng.length} books.`);
}

async function importTranslation(pool, key, cfg) {
  console.log(`\n== ${key} (${cfg.source}) ==`);
  const version = await pool.query(
    `INSERT INTO bible_versions (id, code, name, language, copyright_notice, license_status)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5)
     ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, language=EXCLUDED.language,
       copyright_notice=EXCLUDED.copyright_notice, license_status=EXCLUDED.license_status
     RETURNING id`,
    [key, cfg.name, cfg.language, cfg.copyright, cfg.license],
  );
  const versionId = version.rows[0].id;

  const bookRows = await pool.query('SELECT id, code, chapters FROM bible_books');
  const bookIdByCode = new Map(bookRows.rows.map((r) => [r.code, r.id]));

  const list = await getJson(`${API}/${cfg.source}/books.json`);
  const books = (list.books || list).filter((b) => bookIdByCode.has(b.id));
  console.log(`  ${books.length} books available in source`);

  // Fresh load for this version so re-runs are idempotent.
  await pool.query('DELETE FROM bible_verses WHERE version_id = $1', [versionId]);

  let totalVerses = 0;
  for (const book of books) {
    const bookId = bookIdByCode.get(book.id);
    const chapters = Array.from({ length: book.numberOfChapters }, (_, i) => i + 1);
    const perChapter = await pooled(chapters, 6, async (chapter) => {
      const data = await getJson(`${API}/${cfg.source}/${book.id}/${chapter}.json`);
      return { chapter, verses: versesFromChapter(data.chapter || data) };
    });

    const values = [];
    const params = [];
    for (const { chapter, verses } of perChapter) {
      for (const v of verses) {
        params.push(versionId, bookId, chapter, v.verse, v.text);
        const n = params.length;
        values.push(`($${n - 4},$${n - 3},$${n - 2},$${n - 1},$${n})`);
      }
    }
    // One insert per book: the largest (Psalms) is ~12k params, well under the
    // 65k bind-parameter limit, and it keeps placeholder numbering simple.
    if (values.length) {
      await pool.query(
        `INSERT INTO bible_verses (id, version_id, book_id, chapter, verse, text)
         SELECT gen_random_uuid(), t.version_id::uuid, t.book_id::uuid, t.chapter::int, t.verse::int, t.text
         FROM (VALUES ${values.join(',')}) AS t(version_id, book_id, chapter, verse, text)
         ON CONFLICT (version_id, book_id, chapter, verse) DO UPDATE SET text = EXCLUDED.text`,
        params,
      );
    }
    totalVerses += values.length;
    process.stdout.write(`  ${book.id}:${values.length}  `);
  }
  console.log(`\n  ${key}: ${totalVerses} verses.`);
}

async function main() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }
  const requested = process.argv.slice(2).filter((a) => TRANSLATIONS[a]);
  const keys = requested.length ? requested : Object.keys(TRANSLATIONS);

  const pool = new Pool({ connectionString: databaseUrl });
  try {
    await seedBooks(pool);
    for (const key of keys) await importTranslation(pool, key, TRANSLATIONS[key]);
  } finally {
    await pool.end();
  }
  console.log('\nDone.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
