'use strict';

/**
 * Imports the full 66-book Amharic Bible (OT + NT) into the `amh` version from
 * WordProject (wordproject.org). WordProject distributes the Scriptures free for
 * personal, non-commercial use; the text is credited accordingly.
 *
 * The archive is per-chapter HTML: am_new/<book 01..66>/<chapter>.htm, with
 * verses marked by <span class="verse" id="N">. Verse 1's marker is commented
 * out, so it is the leading paragraph text.
 *
 * Usage:  DATABASE_URL=... node scripts/import-amharic-wordproject.js
 */

const { execSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { Pool } = require('pg');

const ZIP_URL = 'https://www.wordpocket.org/bibles/download_zip/am_new.zip';
const VERSION = {
  code: 'amh',
  name: 'Amharic Bible',
  language: 'am',
  copyright:
    'Amharic Holy Bible, courtesy of WordProject (wordproject.org). Free for personal, non-commercial use.',
  license: 'available',
};

function clean(s) {
  return s
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/[¶﻿]/g, ' ') // paragraph marker + BOM
    .replace(/\s+/g, ' ')
    .trim();
}

function parseChapter(html) {
  let start = html.indexOf('</h3>');
  const end = html.indexOf('/textBody');
  if (start < 0) start = html.indexOf('<span class="verse"');
  let region = html.slice(start >= 0 ? start : 0, end >= 0 ? end : html.length);
  region = region.replace(/<!--[\s\S]*?-->/g, '');
  const parts = region.split(/<span class="verse" id="(\d+)">.*?<\/span>/);
  const verses = [];
  const v1 = clean(parts[0]);
  if (v1) verses.push({ verse: 1, text: v1 });
  for (let i = 1; i < parts.length; i += 2) {
    const text = clean(parts[i + 1]);
    if (text) verses.push({ verse: Number(parts[i]), text });
  }
  return verses;
}

async function main() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }

  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'amh-'));
  const zip = path.join(tmp, 'am_new.zip');
  console.log('Downloading WordProject Amharic Bible…');
  execSync(`curl -sL --max-time 120 "${ZIP_URL}" -o "${zip}"`);
  execSync(`unzip -oq "${zip}" -d "${tmp}"`);
  const base = path.join(tmp, 'am_new');
  if (!fs.existsSync(base)) throw new Error('am_new folder not found in archive');

  const pool = new Pool({ connectionString: databaseUrl });
  try {
    const version = await pool.query(
      `INSERT INTO bible_versions (id, code, name, language, copyright_notice, license_status)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5)
       ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, language=EXCLUDED.language,
         copyright_notice=EXCLUDED.copyright_notice, license_status=EXCLUDED.license_status
       RETURNING id`,
      [VERSION.code, VERSION.name, VERSION.language, VERSION.copyright, VERSION.license],
    );
    const versionId = version.rows[0].id;

    const bookRows = await pool.query('SELECT id, book_order FROM bible_books');
    const bookIdByOrder = new Map(bookRows.rows.map((r) => [r.book_order, r.id]));

    await pool.query('DELETE FROM bible_verses WHERE version_id = $1', [versionId]);

    let totalVerses = 0;
    const folders = fs
      .readdirSync(base)
      .filter((f) => /^\d+$/.test(f))
      .sort((a, b) => Number(a) - Number(b));

    for (const folder of folders) {
      const order = Number(folder);
      const bookId = bookIdByOrder.get(order);
      if (!bookId) {
        console.warn(`  no book for order ${order}, skipping`);
        continue;
      }
      const chapters = fs
        .readdirSync(path.join(base, folder))
        .filter((f) => /^\d+\.htm$/.test(f))
        .map((f) => Number(f.replace('.htm', '')))
        .sort((a, b) => a - b);

      const values = [];
      const params = [];
      const seen = new Set(); // guard against mislabeled duplicate verse markers (e.g. footnotes)
      for (const chapter of chapters) {
        const html = fs.readFileSync(path.join(base, folder, `${chapter}.htm`), 'utf8');
        for (const v of parseChapter(html)) {
          const key = `${chapter}:${v.verse}`;
          if (seen.has(key)) continue;
          seen.add(key);
          params.push(versionId, bookId, chapter, v.verse, v.text);
          const n = params.length;
          values.push(`($${n - 4},$${n - 3},$${n - 2},$${n - 1},$${n})`);
        }
      }
      // A whole book is well under the 65k bind-parameter limit.
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
      process.stdout.write(`  book ${folder}:${values.length}  `);
    }
    console.log(`\nAmharic: ${totalVerses} verses across ${folders.length} books.`);
  } finally {
    await pool.end();
    fs.rmSync(tmp, { recursive: true, force: true });
  }
  console.log('Done.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
