import { backendRequest, forward } from '../../../../../../lib/backend';

export async function POST(_request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  try {
    return forward(await backendRequest(`/admin/users/${encodeURIComponent(id)}/revoke-sessions`, { method: 'POST' }));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
