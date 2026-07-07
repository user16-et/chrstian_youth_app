import { backendRequest, forward } from '../../../lib/backend';

export async function GET() {
  try { return forward(await backendRequest('/admin/auth/me')); }
  catch { return Response.json({ code: 'admin_api_unavailable' }, { status: 502 }); }
}
