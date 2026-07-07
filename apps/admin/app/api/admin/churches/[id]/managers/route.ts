import { NextRequest } from 'next/server';
import { backendRequest, forward } from '../../../../../../lib/backend';

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const input = await request.json().catch(() => null) as Record<string, unknown> | null;
  if (!input) return Response.json({ code: 'invalid_manager_payload' }, { status: 400 });
  try {
    return forward(await backendRequest(`/admin/churches/${encodeURIComponent(id)}/managers`, {
      method: 'POST',
      body: JSON.stringify(input),
    }));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
