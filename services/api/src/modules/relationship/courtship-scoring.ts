// Pure scoring/geo helpers for courtship discovery. Kept free of I/O so they can
// be unit-tested and reused by the repository.

export function intOrNull(value: unknown): number | null {
  const n = typeof value === 'number' ? value : typeof value === 'string' && value.trim() ? Number(value) : NaN;
  return Number.isFinite(n) ? Math.trunc(n) : null;
}

export function numOrNull(value: unknown): number | null {
  const n = typeof value === 'number' ? value : typeof value === 'string' && value.trim() ? Number(value) : NaN;
  return Number.isFinite(n) ? n : null;
}

// Great-circle distance in kilometres between two lat/lng points.
export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export interface CompatibilityScore {
  faith: number;
  ministry: number;
  lifeGoals: number;
  familyVision: number;
  location: number;
  overall: number;
}

// Heuristic 0–100 compatibility between the viewer (`me`) and another profile.
// A null viewer yields a neutral baseline.
export function compatibility(me: any, other: any): CompatibilityScore {
  if (!me) return { faith: 70, ministry: 70, lifeGoals: 70, familyVision: 70, location: 70, overall: 70 };
  const overlap = (a = '', b = '') => {
    const target = String(b).toLowerCase();
    // Ignore fragments shorter than 3 chars ("a", "in") to avoid false matches.
    return String(a).toLowerCase().split(/[,\s]+/).filter((x) => x.length >= 3).some((x) => target.includes(x));
  };
  const faith = overlap(me.faithStatement, other.faithStatement) || overlap(me.favoritePassages, other.favoritePassages) ? 95 : 78;
  const ministry = overlap(me.ministryInvolvement, other.ministryInvolvement) || overlap(me.interests, other.interests) ? 90 : 74;
  const lifeGoals = overlap(me.lifeGoals, other.lifeGoals) || me.relationshipIntent === other.relationshipIntent ? 88 : 72;
  const familyVision = overlap(me.marriageVision, other.marriageVision) || overlap(me.familyGoals, other.familyGoals) ? 88 : 70;
  const location = me.city && me.city === other.city ? 94 : 68;
  return { faith, ministry, lifeGoals, familyVision, location, overall: Math.round((faith + ministry + lifeGoals + familyVision + location) / 5) };
}
