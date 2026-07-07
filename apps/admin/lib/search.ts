export type PaginatedSearchInput = {
  query?: string;
  page: number;
  pageSize: number;
  extra?: Record<string, string | number | boolean | null | undefined>;
};

export function normalizeSearchQuery(value: string | null | undefined) {
  return (value ?? '').trim().replace(/\s+/g, ' ');
}

export function clampPageIndex(page: number) {
  return Number.isFinite(page) && page > 0 ? Math.floor(page) : 0;
}

export function pageCount(total: number, pageSize: number) {
  if (!Number.isFinite(total) || total <= 0) return 1;
  return Math.max(1, Math.ceil(total / Math.max(1, pageSize)));
}

export function hasNextPage(page: number, total: number, pageSize: number) {
  return (clampPageIndex(page) + 1) * Math.max(1, pageSize) < Math.max(0, total);
}

export function pageAfterRemovingLastItem(page: number, visibleItems: number) {
  const safePage = clampPageIndex(page);
  return visibleItems <= 1 && safePage > 0 ? safePage - 1 : safePage;
}

export function buildPaginatedSearchParams(input: PaginatedSearchInput) {
  const safePage = clampPageIndex(input.page);
  const safePageSize = Math.min(Math.max(Math.floor(input.pageSize), 1), 100);
  const params = new URLSearchParams({
    limit: String(safePageSize),
    offset: String(safePage * safePageSize),
    paginated: 'true',
  });
  const query = normalizeSearchQuery(input.query);
  if (query) params.set('q', query);
  for (const [key, value] of Object.entries(input.extra ?? {})) {
    if (value !== null && value !== undefined && value !== '') params.set(key, String(value));
  }
  return { params, page: safePage, pageSize: safePageSize, query };
}
