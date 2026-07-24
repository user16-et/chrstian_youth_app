import { compatibility, haversineKm, intOrNull, numOrNull } from './courtship-scoring';

describe('intOrNull / numOrNull', () => {
  it('parses numbers and numeric strings, truncating for intOrNull', () => {
    expect(intOrNull(5)).toBe(5);
    expect(intOrNull('7')).toBe(7);
    expect(intOrNull(3.9)).toBe(3);
    expect(numOrNull('3.9')).toBeCloseTo(3.9);
  });

  it('returns null for blanks and non-numerics', () => {
    for (const bad of [undefined, null, '', '   ', 'abc', {}, NaN]) {
      expect(intOrNull(bad)).toBeNull();
      expect(numOrNull(bad)).toBeNull();
    }
  });
});

describe('haversineKm', () => {
  it('is zero for identical points', () => {
    expect(haversineKm(9.03, 38.74, 9.03, 38.74)).toBe(0);
  });

  it('is symmetric', () => {
    const a = haversineKm(9.03, 38.74, 8.98, 38.79);
    const b = haversineKm(8.98, 38.79, 9.03, 38.74);
    expect(a).toBeCloseTo(b, 6);
  });

  it('matches a known distance (Addis Ababa → Adama ≈ 100 km)', () => {
    // Addis Ababa (9.03, 38.74) to Adama (8.54, 39.27)
    expect(haversineKm(9.03, 38.74, 8.54, 39.27)).toBeGreaterThan(70);
    expect(haversineKm(9.03, 38.74, 8.54, 39.27)).toBeLessThan(90);
  });
});

describe('compatibility', () => {
  it('returns a neutral baseline for a null viewer', () => {
    expect(compatibility(null, {})).toEqual({ faith: 70, ministry: 70, lifeGoals: 70, familyVision: 70, location: 70, overall: 70 });
  });

  it('scores higher on overlap and same city', () => {
    const me = {
      faithStatement: 'Following Jesus faithfully',
      ministryInvolvement: 'worship team',
      lifeGoals: 'missions and service',
      marriageVision: 'Christ centered home',
      city: 'Addis Ababa',
      relationshipIntent: 'marriage',
    };
    const strong = compatibility(me, {
      faithStatement: 'faithfully serving',
      ministryInvolvement: 'worship leader',
      lifeGoals: 'service overseas',
      marriageVision: 'a centered home',
      city: 'Addis Ababa',
      relationshipIntent: 'marriage',
    });
    const weak = compatibility(me, { faithStatement: 'x', ministryInvolvement: 'y', city: 'Bahir Dar', relationshipIntent: 'friendship' });

    expect(strong.location).toBe(94);
    expect(weak.location).toBe(68);
    expect(strong.overall).toBeGreaterThan(weak.overall);
    // All sub-scores stay within 0..100.
    for (const v of Object.values(strong)) {
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThanOrEqual(100);
    }
  });

  it('ignores short (<3 char) fragments so stop-words do not create matches', () => {
    // "in" is the only shared token and it is too short to count.
    const score = compatibility({ interests: 'in it' }, { interests: 'in on' });
    expect(score.ministry).toBe(74); // no real overlap → baseline
  });
});
