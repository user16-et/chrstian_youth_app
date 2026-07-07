import { NextRequest } from 'next/server';
import { backendRequest, forward } from '../../../../lib/backend';

export async function GET(request: NextRequest) {
  const query = request.nextUrl.searchParams;
  const username = query.get('username')?.trim();
  try {
    if (username) {
      return forward(await backendRequest(`/users/username/${encodeURIComponent(username)}`));
    }
    const params = query.toString() || 'limit=25&paginated=true';
    return forward(await backendRequest(`/admin/users?${params}`));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
