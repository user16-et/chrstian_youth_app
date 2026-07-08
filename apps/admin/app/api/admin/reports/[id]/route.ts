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

// Resolve with enforcement: remove_content / suspend_user / dismiss / resolve.
export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const body = await request.text();
  try {
    return forward(await backendRequest(`/moderation/reports/${encodeURIComponent(id)}/action`, { method: 'POST', body }));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
