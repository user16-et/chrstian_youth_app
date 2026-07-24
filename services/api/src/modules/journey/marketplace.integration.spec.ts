import type { Pool } from 'pg';
import { JourneyRepository } from './journey.repository';
import { createUser, deleteUsers, testPool, closeTestPool, TestUser } from '../../../test/factories';

/**
 * Integration coverage for the marketplace repository: listing creation,
 * save/unsave favorites, and ordering. Includes the duplicate-title regression
 * from commit 5c08926 (titles must not be globally unique).
 */
describe('JourneyRepository marketplace (integration)', () => {
  let repo: JourneyRepository;
  let seller: TestUser;
  let buyer: TestUser;
  const listingIds: string[] = [];

  const listingInput = (title: string) => ({
    title,
    category: 'electronics',
    priceCents: 50000,
    description: 'A good item',
    condition: 'new',
    location: 'Addis Ababa',
    phoneNumber: '+251900000000',
    images: ['https://example.test/a.jpg', 'https://example.test/b.jpg'],
  });

  beforeAll(() => {
    repo = new JourneyRepository();
  });

  afterAll(async () => {
    await (repo as unknown as { pool: Pool }).pool.end();
    await closeTestPool();
  });

  beforeEach(async () => {
    seller = await createUser({ fullName: 'Seller Sam' });
    buyer = await createUser();
  });

  afterEach(async () => {
    if (listingIds.length) {
      const ids = listingIds.splice(0);
      await testPool.query('DELETE FROM marketplace_orders WHERE listing_id = ANY($1::uuid[])', [ids]);
      await testPool.query('DELETE FROM marketplace_listings WHERE id = ANY($1::uuid[])', [ids]);
    }
    await deleteUsers(seller.id, buyer.id);
  });

  it('creates a listing owned by the seller, stamped with their name and images', async () => {
    const listing = await repo.createListing(seller.id, listingInput('Vintage Radio'));
    listingIds.push(listing.id);
    expect(listing.seller_id).toBe(seller.id);
    expect(listing.seller_name).toBe('Seller Sam');
    expect(listing.image_url).toBe('https://example.test/a.jpg');

    const images = await testPool.query('SELECT url FROM marketplace_listing_images WHERE listing_id=$1 ORDER BY position', [listing.id]);
    expect(images.rows.map((r) => r.url)).toEqual(['https://example.test/a.jpg', 'https://example.test/b.jpg']);
  });

  it('allows two listings with the same title (titles are not globally unique)', async () => {
    const first = await repo.createListing(seller.id, listingInput('Same Title'));
    const second = await repo.createListing(buyer.id, listingInput('Same Title'));
    listingIds.push(first.id, second.id);
    expect(first.id).not.toBe(second.id);
  });

  it('saves and unsaves a listing idempotently', async () => {
    const listing = await repo.createListing(seller.id, listingInput('Saveable'));
    listingIds.push(listing.id);

    await repo.saveListing(buyer.id, listing.id);
    await repo.saveListing(buyer.id, listing.id); // ON CONFLICT DO NOTHING
    let count = await testPool.query('SELECT count(*)::int AS n FROM marketplace_favorites WHERE user_id=$1 AND listing_id=$2', [buyer.id, listing.id]);
    expect(count.rows[0].n).toBe(1);

    await repo.unsaveListing(buyer.id, listing.id);
    count = await testPool.query('SELECT count(*)::int AS n FROM marketplace_favorites WHERE user_id=$1 AND listing_id=$2', [buyer.id, listing.id]);
    expect(count.rows[0].n).toBe(0);
  });

  it('creates an order with a receipt number', async () => {
    const listing = await repo.createListing(seller.id, listingInput('Orderable'));
    listingIds.push(listing.id);
    const order = await repo.order(buyer.id, listing.id);
    expect(order.user_id).toBe(buyer.id);
    expect(order.listing_id).toBe(listing.id);
    expect(order.receipt_number).toMatch(/^RCP-/);
  });
});
