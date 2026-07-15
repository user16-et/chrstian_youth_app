-- Distance-based matching: store an approximate location on the courtship
-- profile so discovery can show and filter by distance.
ALTER TABLE courtship_profiles ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE courtship_profiles ADD COLUMN IF NOT EXISTS longitude double precision;

-- Seed approximate city coordinates for existing/demo profiles that have a
-- known Ethiopian city, so distance appears immediately.
UPDATE courtship_profiles SET latitude=9.0300,  longitude=38.7400 WHERE latitude IS NULL AND lower(city) IN ('addis ababa','addis');
UPDATE courtship_profiles SET latitude=11.5936, longitude=37.3908 WHERE latitude IS NULL AND lower(city)='bahir dar';
UPDATE courtship_profiles SET latitude=8.5400,  longitude=39.2700 WHERE latitude IS NULL AND lower(city)='adama';
UPDATE courtship_profiles SET latitude=7.0622,  longitude=38.4777 WHERE latitude IS NULL AND lower(city)='hawassa';
UPDATE courtship_profiles SET latitude=12.6000, longitude=37.4667 WHERE latitude IS NULL AND lower(city)='gondar';
