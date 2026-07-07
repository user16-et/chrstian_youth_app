import { NextRequest } from 'next/server';
import { backendRequest, forward } from '../../../../../lib/backend';

export async function PATCH(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const body = await request.text();
  try {
    return forward(await backendRequest(`/moderation/reports/${encodeURIComponent(id)}`, { method: 'PATCH', body }));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
