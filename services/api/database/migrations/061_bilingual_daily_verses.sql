-- Make the "verse of the day" bilingual (English + Amharic) and seed a pool
-- large enough to rotate. The endpoint selects today + the previous two days
-- deterministically from this pool, so it changes every day.

ALTER TABLE bible_daily_verses ADD COLUMN IF NOT EXISTS reference_am text;
ALTER TABLE bible_daily_verses ADD COLUMN IF NOT EXISTS verse_text_am text;

-- Replace the small placeholder set with a curated bilingual pool. Daily
-- verses are app content (not user data), so replacing them is safe. Distinct
-- created_at values give the rotation a stable order.
DELETE FROM bible_daily_verses;

INSERT INTO bible_daily_verses (reference, verse_text, reference_am, verse_text_am, language, theme, created_at) VALUES
  ('Psalm 23:1', 'The Lord is my shepherd; I shall not want.', 'መዝሙር 23፥1', 'እግዚአብሔር እረኛዬ ነው፤ የሚያሳጣኝ የለም።', 'en', 'Care', '2026-01-01T00:00:01Z'),
  ('Philippians 4:13', 'I can do all things through Christ who strengthens me.', 'ፊልጵስዩስ 4፥13', 'ኃይል በሚሰጠኝ በክርስቶስ ሁሉን እችላለሁ።', 'en', 'Strength', '2026-01-01T00:00:02Z'),
  ('Proverbs 3:5', 'Trust in the Lord with all your heart, and lean not on your own understanding.', 'ምሳሌ 3፥5', 'በፍጹም ልብህ በእግዚአብሔር ታመን፥ በራስህም ማስተዋል አትደገፍ።', 'en', 'Trust', '2026-01-01T00:00:03Z'),
  ('Joshua 1:9', 'Be strong and courageous; the Lord your God is with you wherever you go.', 'ኢያሱ 1፥9', 'ጽናና አይዞህ፤ አትፍራ አትደንግጥም፤ በምትሄድበት ሁሉ አምላክህ እግዚአብሔር ከአንተ ጋር ነውና።', 'en', 'Courage', '2026-01-01T00:00:04Z'),
  ('Isaiah 41:10', 'Fear not, for I am with you; I will strengthen you and help you.', 'ኢሳይያስ 41፥10', 'አትፍራ እኔ ከአንተ ጋር ነኝና፤ አጸናሃለሁ እረዳህማለሁ።', 'en', 'Comfort', '2026-01-01T00:00:05Z'),
  ('Jeremiah 29:11', 'For I know the plans I have for you, plans to give you a hope and a future.', 'ኤርምያስ 29፥11', 'እኔ ስለ እናንተ የማስበውን አሳብ አውቃለሁ፥ የተስፋንና የፍጻሜን አሳብ እንጂ የክፉን አይደለም ይላል እግዚአብሔር።', 'en', 'Hope', '2026-01-01T00:00:06Z'),
  ('Romans 8:28', 'All things work together for good to those who love God.', 'ሮሜ 8፥28', 'እግዚአብሔርንም ለሚወዱት ነገር ሁሉ ለበጎ እንዲደረግ እናውቃለን።', 'en', 'Providence', '2026-01-01T00:00:07Z'),
  ('Matthew 11:28', 'Come to me, all who are weary and burdened, and I will give you rest.', 'ማቴዎስ 11፥28', 'እናንተ ደካሞች ሸክማችሁ የከበደ ሁሉ፥ ወደ እኔ ኑ እኔም አሳርፋችኋለሁ።', 'en', 'Rest', '2026-01-01T00:00:08Z'),
  ('Psalm 46:1', 'God is our refuge and strength, an ever-present help in trouble.', 'መዝሙር 46፥1', 'እግዚአብሔር መጠጊያችንና ኃይላችን ነው፥ በመከራም ጊዜ የተገኘ ረዳት ነው።', 'en', 'Refuge', '2026-01-01T00:00:09Z'),
  ('Proverbs 18:10', 'The name of the Lord is a strong tower; the righteous run to it and are safe.', 'ምሳሌ 18፥10', 'የእግዚአብሔር ስም ጽኑ ግንብ ነው፤ ጻድቅ ወደ እርሱ ሮጦ ይጠበቃል።', 'en', 'Protection', '2026-01-01T00:00:10Z'),
  ('Psalm 119:105', 'Your word is a lamp to my feet and a light to my path.', 'መዝሙር 119፥105', 'ቃልህ ለእግሬ መብራት ለመንገዴም ብርሃን ነው።', 'en', 'Guidance', '2026-01-01T00:00:11Z'),
  ('1 Corinthians 13:4', 'Love is patient, love is kind. It does not envy, it does not boast.', '1 ቆሮንቶስ 13፥4', 'ፍቅር ይታገሣል፥ ቸርነትንም ያደርጋል፤ ፍቅር አይቀናም፥ ፍቅር አይመካም አይታበይምም።', 'en', 'Love', '2026-01-01T00:00:12Z'),
  ('John 14:27', 'Peace I leave with you; my peace I give you. Do not let your heart be troubled.', 'ዮሐንስ 14፥27', 'ሰላምን እተውላችኋለሁ፥ ሰላሜን እሰጣችኋለሁ፤ ልባችሁ አይታወክ አይፍራም።', 'en', 'Peace', '2026-01-01T00:00:13Z'),
  ('Lamentations 3:22-23', 'His mercies are new every morning; great is your faithfulness.', 'ሰቆቃወ ኤርምያስ 3፥22-23', 'ምሕረቱ ማለቂያ የለውምና፥ ማለዳ ማለዳ አዲስ ነው፤ ታማኝነትህ ብዙ ነው።', 'en', 'Mercy', '2026-01-01T00:00:14Z'),
  ('Psalm 118:24', 'This is the day the Lord has made; let us rejoice and be glad in it.', 'መዝሙር 118፥24', 'እግዚአብሔር የፈጠረው ቀን ይህ ነው፤ ደስ ይበለን በእርሱም ሐሤት እናድርግ።', 'en', 'Joy', '2026-01-01T00:00:15Z');
