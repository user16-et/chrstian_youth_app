import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Pool } from 'pg';
import { postgresPoolConfig } from '../../common/postgres';

@Injectable()
export class JourneyRepository {
  private readonly pool = new Pool(postgresPoolConfig('api-journey-repository'));

  async dashboard(userId: string) {
    const [profile, plans, courses, badges, orders, friends, savedPosts] = await Promise.all([
      this.pool.query('SELECT * FROM user_profiles WHERE user_id = $1', [userId]),
      this.pool.query(`SELECT p.*, COALESCE(e.completed_days, 0) AS completed_days, COALESCE(e.streak, 0) AS streak,
        e.started_at, e.completed_at FROM bible_reading_plans p LEFT JOIN reading_plan_enrollments e
        ON e.plan_id = p.id AND e.user_id = $1 ORDER BY p.created_at`, [userId]),
      this.pool.query(`SELECT c.*, COALESCE(e.completed_lessons, 0) AS completed_lessons, e.enrolled_at, e.completed_at,
        cert.certificate_code FROM courses c LEFT JOIN course_enrollments e ON e.course_id = c.id AND e.user_id = $1
        LEFT JOIN certificates cert ON cert.course_id = c.id AND cert.user_id = $1 ORDER BY c.created_at`, [userId]),
      this.pool.query('SELECT * FROM badges WHERE user_id = $1 ORDER BY awarded_at DESC', [userId]),
      this.pool.query(`SELECT o.*, l.title, l.category, l.price_cents FROM marketplace_orders o
        JOIN marketplace_listings l ON l.id = o.listing_id WHERE o.user_id = $1 ORDER BY o.created_at DESC`, [userId]),
      this.pool.query(`SELECT fr.*, sender.full_name AS sender_name, receiver.full_name AS receiver_name
        FROM friend_requests fr JOIN users sender ON sender.id = fr.sender_id JOIN users receiver ON receiver.id = fr.receiver_id
        WHERE fr.sender_id = $1 OR fr.receiver_id = $1 ORDER BY fr.created_at DESC`, [userId]),
      this.pool.query('SELECT post_id FROM post_saves WHERE user_id = $1', [userId]),
    ]);
    return { profile: profile.rows[0] ?? null, plans: plans.rows, courses: courses.rows, badges: badges.rows, orders: orders.rows, friends: friends.rows, savedPostIds: savedPosts.rows.map((row) => row.post_id) };
  }

  requestOtp(phoneNumber: string, code: string) {
    return this.pool.query(`INSERT INTO otp_challenges (phone_number, code, expires_at)
      VALUES ($1, $2, now() + interval '10 minutes') RETURNING id, phone_number, code, expires_at`, [phoneNumber, code]).then((r) => ({ id: r.rows[0].id, phoneNumber: r.rows[0].phone_number, code: r.rows[0].code, expiresAt: r.rows[0].expires_at }));
  }

  async verifyOtp(phoneNumber: string, code: string) {
    const result = await this.pool.query(`UPDATE otp_challenges SET verified_at = now() WHERE id = (
      SELECT id FROM otp_challenges WHERE phone_number = $1 AND code = $2 AND expires_at > now()
      ORDER BY created_at DESC LIMIT 1) RETURNING id`, [phoneNumber, code]);
    return result.rowCount === 1;
  }

  async isPhoneVerified(phoneNumber: string) {
    const result = await this.pool.query(`SELECT 1 FROM otp_challenges WHERE phone_number=$1
      AND verified_at IS NOT NULL AND expires_at > now() ORDER BY created_at DESC LIMIT 1`, [phoneNumber]);
    return result.rowCount === 1;
  }

  async completeOnboarding(userId: string, input: any) {
    await this.pool.query(`INSERT INTO user_profiles
      (user_id, photo_url, city, occupation, relationship_status, testimony, interests, birth_date, onboarding_complete, updated_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true,now()) ON CONFLICT (user_id) DO UPDATE SET
      photo_url=EXCLUDED.photo_url, city=EXCLUDED.city, occupation=EXCLUDED.occupation,
      relationship_status=EXCLUDED.relationship_status, testimony=EXCLUDED.testimony, interests=EXCLUDED.interests,
      birth_date=EXCLUDED.birth_date, onboarding_complete=true, updated_at=now()`,
      [userId, input.photoUrl ?? '', input.city ?? '', input.occupation ?? '', input.relationshipStatus ?? '', input.testimony ?? '', input.interests ?? [], input.birthDate || null]);
    if (input.churchId) await this.pool.query(`INSERT INTO church_memberships (church_id,user_id,role,status)
      SELECT $1,$2,'member','pending'
      WHERE NOT EXISTS(SELECT 1 FROM church_memberships existing WHERE existing.user_id=$2 AND existing.church_id<>$1 AND existing.status IN ('active','approved','requested','pending'))
      ON CONFLICT (church_id,user_id) DO UPDATE SET status='pending'`, [input.churchId, userId]);
    for (const ministryId of input.ministryIds ?? []) await this.pool.query(`INSERT INTO ministry_memberships (ministry_id,user_id,role)
      VALUES ($1,$2,'member') ON CONFLICT (ministry_id,user_id) DO NOTHING`, [ministryId, userId]);
    return this.dashboard(userId);
  }

  toggleSave(userId: string, postId: string) {
    return this.pool.query(`WITH deleted AS (DELETE FROM post_saves WHERE user_id=$1 AND post_id=$2 RETURNING post_id)
      INSERT INTO post_saves (user_id,post_id) SELECT $1,$2 WHERE NOT EXISTS (SELECT 1 FROM deleted)
      ON CONFLICT DO NOTHING RETURNING post_id`, [userId, postId]).then((r) => ({ saved: r.rowCount === 1 }));
  }

  pray(userId: string, requestId: string) {
    return this.pool.query(`INSERT INTO prayer_commitments (user_id,prayer_request_id) VALUES ($1,$2)
      ON CONFLICT DO NOTHING RETURNING prayer_request_id`, [userId, requestId]).then((r) => ({ prayed: true, created: r.rowCount === 1 }));
  }

  enrollPlan(userId: string, planId: string) {
    return this.pool.query(`INSERT INTO reading_plan_enrollments (user_id,plan_id) VALUES ($1,$2)
      ON CONFLICT DO NOTHING RETURNING *`, [userId, planId]).then(() => this.dashboard(userId));
  }

  async checkinPlan(userId: string, planId: string) {
    await this.pool.query(`UPDATE reading_plan_enrollments e SET completed_days = LEAST(e.completed_days + 1, p.duration_days),
      streak = CASE WHEN e.last_checkin = current_date - 1 THEN e.streak + 1 WHEN e.last_checkin = current_date THEN e.streak ELSE 1 END,
      last_checkin = current_date, completed_at = CASE WHEN e.completed_days + 1 >= p.duration_days THEN now() ELSE e.completed_at END
      FROM bible_reading_plans p WHERE e.user_id=$1 AND e.plan_id=$2 AND p.id=e.plan_id`, [userId, planId]);
    return this.dashboard(userId);
  }

  friendRequest(userId: string, receiverId: string) {
    if (userId === receiverId) return Promise.resolve(null);
    return this.pool.query(`INSERT INTO friend_requests (sender_id,receiver_id) VALUES ($1,$2)
      ON CONFLICT (sender_id,receiver_id) DO UPDATE SET status='pending' RETURNING *`, [userId, receiverId]).then((r) => r.rows[0] ?? null);
  }

  updateFriendRequest(userId: string, id: string, status: string) {
    return this.pool.query(`UPDATE friend_requests SET status=$3 WHERE id=$1 AND receiver_id=$2 RETURNING *`, [id, userId, status]).then((r) => r.rows[0] ?? null);
  }

  withdrawFriendRequest(userId: string, id: string) {
    return this.pool.query(`DELETE FROM friend_requests WHERE id=$1 AND sender_id=$2 AND status='pending' RETURNING *`, [id, userId]).then((r) => r.rows[0] ?? null);
  }

  // Remove an accepted friendship (either direction).
  unfriend(userId: string, otherId: string) {
    return this.pool
      .query(
        `DELETE FROM friend_requests WHERE status='accepted' AND ((sender_id=$1 AND receiver_id=$2) OR (sender_id=$2 AND receiver_id=$1)) RETURNING id`,
        [userId, otherId],
      )
      .then((r) => (r.rowCount ?? 0) > 0);
  }

  // Pending friend requests — both incoming (to accept) and outgoing (sent).
  listFriendRequests(userId: string) {
    return this.pool
      .query(
        `SELECT fr.id, fr.status, fr.created_at AS "createdAt",
                CASE WHEN fr.sender_id=$1 THEN 'outgoing' ELSE 'incoming' END AS direction,
                u.id AS "userId", u.full_name AS "fullName", u.username,
                COALESCE(NULLIF(u.profile_image,''),'') AS "profileImage"
         FROM friend_requests fr
         JOIN users u ON u.id = CASE WHEN fr.sender_id=$1 THEN fr.receiver_id ELSE fr.sender_id END
         WHERE fr.status='pending' AND (fr.sender_id=$1 OR fr.receiver_id=$1)
         ORDER BY fr.created_at DESC`,
        [userId],
      )
      .then((r) => r.rows);
  }

  // Accepted friends.
  listFriends(userId: string) {
    return this.pool
      .query(
        `SELECT u.id AS "userId", u.full_name AS "fullName", u.username,
                COALESCE(NULLIF(u.profile_image,''),'') AS "profileImage",
                fr.created_at AS "since"
         FROM friend_requests fr
         JOIN users u ON u.id = CASE WHEN fr.sender_id=$1 THEN fr.receiver_id ELSE fr.sender_id END
         WHERE fr.status='accepted' AND (fr.sender_id=$1 OR fr.receiver_id=$1)
         ORDER BY u.full_name`,
        [userId],
      )
      .then((r) => r.rows);
  }

  replyStory(userId: string, storyId: string, body: string) {
    return this.pool.query(`INSERT INTO story_replies (story_id,author_id,body) VALUES ($1,$2,$3) RETURNING *`, [storyId, userId, body]).then((r) => r.rows[0]);
  }

  // Browse listings with search + filters. viewerId (optional) marks favourites.
  listings(filters: Record<string, unknown>, viewerId?: string | null) {
    const q = String(filters.q ?? '').trim();
    return this.pool
      .query(
        `SELECT l.id, l.title, l.category, l.price_cents AS "priceCents", l.condition, l.location,
                l.description, l.image_url AS "imageUrl", l.seller_id AS "sellerId", l.sold,
                COALESCE(u.full_name, l.seller_name) AS "sellerName", l.created_at AS "createdAt",
                (SELECT count(*)::int FROM marketplace_listing_images mi WHERE mi.listing_id=l.id) AS "photoCount",
                ($8::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM marketplace_favorites f WHERE f.listing_id=l.id AND f.user_id=$8)) AS "saved"
         FROM marketplace_listings l
         LEFT JOIN users u ON u.id = l.seller_id
         WHERE l.active=true AND l.sold=false
           AND ($1='' OR l.title ILIKE '%'||$1||'%' OR l.description ILIKE '%'||$1||'%')
           AND ($2='' OR lower(l.category)=lower($2))
           AND ($3='' OR l.condition=$3)
           AND ($4='' OR l.location ILIKE '%'||$4||'%')
           AND ($5::int IS NULL OR l.price_cents >= $5)
           AND ($6::int IS NULL OR l.price_cents <= $6)
         ORDER BY (CASE WHEN $7='price_asc' THEN l.price_cents END) ASC NULLS LAST,
                  (CASE WHEN $7='price_desc' THEN l.price_cents END) DESC NULLS LAST,
                  l.created_at DESC
         LIMIT 120`,
        [q, String(filters.category ?? ''), String(filters.condition ?? ''), String(filters.location ?? ''),
         intOrNull(filters.minPrice), intOrNull(filters.maxPrice), String(filters.sort ?? ''), viewerId ?? null],
      )
      .then((r) => r.rows);
  }

  async listingDetail(id: string, viewerId?: string | null) {
    const row = await this.pool
      .query(
        `SELECT l.id, l.title, l.category, l.price_cents AS "priceCents", l.condition, l.location,
                l.description, l.image_url AS "imageUrl", l.phone_number AS "phoneNumber",
                l.seller_id AS "sellerId", l.sold, COALESCE(u.full_name, l.seller_name) AS "sellerName",
                COALESCE(NULLIF(u.profile_image,''),'') AS "sellerPhoto", l.created_at AS "createdAt",
                ($2::uuid IS NOT NULL AND EXISTS(SELECT 1 FROM marketplace_favorites f WHERE f.listing_id=l.id AND f.user_id=$2)) AS "saved"
         FROM marketplace_listings l
         LEFT JOIN users u ON u.id = l.seller_id
         WHERE l.id=$1 AND l.active=true`,
        [id, viewerId ?? null],
      )
      .then((r) => r.rows[0] ?? null);
    if (!row) return null;
    const images = await this.pool
      .query('SELECT url FROM marketplace_listing_images WHERE listing_id=$1 ORDER BY position, created_at', [id])
      .then((r) => r.rows.map((x) => x.url as string));
    return { ...row, images: images.length ? images : (row.imageUrl ? [row.imageUrl] : []) };
  }

  myListings(userId: string) {
    return this.pool
      .query(
        `SELECT l.id, l.title, l.category, l.price_cents AS "priceCents", l.condition, l.location,
                l.image_url AS "imageUrl", l.sold, l.active, l.created_at AS "createdAt"
         FROM marketplace_listings l WHERE l.seller_id=$1 ORDER BY l.created_at DESC`,
        [userId],
      )
      .then((r) => r.rows);
  }

  savedListings(userId: string) {
    return this.pool
      .query(
        `SELECT l.id, l.title, l.category, l.price_cents AS "priceCents", l.condition, l.location,
                l.image_url AS "imageUrl", l.sold, COALESCE(u.full_name, l.seller_name) AS "sellerName",
                l.created_at AS "createdAt", true AS "saved"
         FROM marketplace_favorites f
         JOIN marketplace_listings l ON l.id=f.listing_id AND l.active=true
         LEFT JOIN users u ON u.id=l.seller_id
         WHERE f.user_id=$1 ORDER BY f.created_at DESC`,
        [userId],
      )
      .then((r) => r.rows);
  }

  async createListing(userId: string, input: {
    title: string;
    category: string;
    priceCents: number;
    description: string;
    condition: string;
    location: string;
    phoneNumber: string;
    images: string[];
  }) {
    const cover = input.images[0] ?? '';
    const listing = await this.pool
      .query(
        `INSERT INTO marketplace_listings
          (seller_id, title, category, price_cents, seller_name, description, condition, location, phone_number, image_url, listing_type)
         SELECT $1, $2, $3, $4, u.full_name, $5, $6, $7, $8, $9, 'user_post'
         FROM users u WHERE u.id=$1
         RETURNING *`,
        [userId, input.title, input.category, input.priceCents, input.description, input.condition, input.location, input.phoneNumber, cover],
      )
      .then((r) => r.rows[0]);
    for (let i = 0; i < input.images.length && i < 10; i += 1) {
      await this.pool.query('INSERT INTO marketplace_listing_images (listing_id, url, position) VALUES ($1,$2,$3)', [listing.id, input.images[i], i]);
    }
    return listing;
  }

  async updateListing(
    userId: string,
    id: string,
    fields: {
      sold?: boolean; priceCents?: number; description?: string; active?: boolean;
      title?: string; category?: string; condition?: string; location?: string;
      phoneNumber?: string; images?: string[];
    },
  ) {
    const listing = await this.pool
      .query(
        `UPDATE marketplace_listings SET
           sold = COALESCE($3, sold),
           price_cents = COALESCE($4, price_cents),
           description = COALESCE($5, description),
           active = COALESCE($6, active),
           title = COALESCE(NULLIF($7,''), title),
           category = COALESCE(NULLIF($8,''), category),
           condition = COALESCE(NULLIF($9,''), condition),
           location = COALESCE($10, location),
           phone_number = COALESCE($11, phone_number),
           image_url = COALESCE($12, image_url)
         WHERE id=$1 AND seller_id=$2
         RETURNING id, sold, price_cents AS "priceCents", active, title, category, condition, location, image_url AS "imageUrl"`,
        [
          id, userId, fields.sold ?? null, fields.priceCents ?? null, fields.description ?? null, fields.active ?? null,
          fields.title ?? '', fields.category ?? '', fields.condition ?? '', fields.location ?? null,
          fields.phoneNumber ?? null, fields.images?.length ? fields.images[0] : null,
        ],
      )
      .then((r) => r.rows[0] ?? null);
    if (listing && fields.images?.length) {
      await this.pool.query('DELETE FROM marketplace_listing_images WHERE listing_id=$1', [id]);
      for (let i = 0; i < fields.images.length && i < 10; i += 1) {
        await this.pool.query('INSERT INTO marketplace_listing_images (listing_id, url, position) VALUES ($1,$2,$3)', [id, fields.images[i], i]);
      }
    }
    return listing;
  }

  deleteListing(userId: string, id: string) {
    return this.pool
      .query('DELETE FROM marketplace_listings WHERE id=$1 AND seller_id=$2 RETURNING id', [id, userId])
      .then((r) => (r.rowCount ?? 0) > 0);
  }

  saveListing(userId: string, id: string) {
    return this.pool
      .query('INSERT INTO marketplace_favorites (user_id, listing_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [userId, id])
      .then(() => ({ saved: true }));
  }

  unsaveListing(userId: string, id: string) {
    return this.pool
      .query('DELETE FROM marketplace_favorites WHERE user_id=$1 AND listing_id=$2', [userId, id])
      .then(() => ({ saved: false }));
  }

  enrollCourse(userId: string, courseId: string) {
    return this.pool.query(`INSERT INTO course_enrollments (user_id,course_id) VALUES ($1,$2) ON CONFLICT DO NOTHING RETURNING *`, [userId, courseId]).then(() => this.dashboard(userId));
  }

  async progressCourse(userId: string, courseId: string) {
    const result = await this.pool.query(`UPDATE course_enrollments e SET completed_lessons=LEAST(e.completed_lessons+1,c.lesson_count),
      completed_at=CASE WHEN e.completed_lessons+1>=c.lesson_count THEN now() ELSE e.completed_at END
      FROM courses c WHERE e.user_id=$1 AND e.course_id=$2 AND c.id=e.course_id RETURNING e.completed_lessons,c.lesson_count`, [userId, courseId]);
    const row = result.rows[0];
    if (row && row.completed_lessons >= row.lesson_count) {
      await this.pool.query(`INSERT INTO certificates (user_id,course_id,certificate_code) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`, [userId, courseId, `CERT-${randomUUID().slice(0, 8).toUpperCase()}`]);
    }
    return this.dashboard(userId);
  }

  order(userId: string, listingId: string) {
    return this.pool.query(`INSERT INTO marketplace_orders (user_id,listing_id,receipt_number) VALUES ($1,$2,$3) RETURNING *`, [userId, listingId, `RCP-${randomUUID().slice(0, 10).toUpperCase()}`]).then((r) => r.rows[0]);
  }
}

function intOrNull(value: unknown): number | null {
  const n = typeof value === 'number' ? value : typeof value === 'string' && value.trim() ? Number(value) : NaN;
  return Number.isFinite(n) ? Math.trunc(n) : null;
}
