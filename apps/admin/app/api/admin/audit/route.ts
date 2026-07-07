import { NextRequest } from 'next/server';
import { backendRequest, forward } from '../../../../lib/backend';

export async function GET(request: NextRequest) {
  const query = request.nextUrl.searchParams.toString() || 'limit=100';
  try {
    return forward(await backendRequest(`/admin/security/audit-logs?${query}`));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
