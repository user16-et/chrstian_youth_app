import { NextRequest } from 'next/server';
import { backendRequest, forward } from '../../../../../lib/backend';

export async function PATCH(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  const input = await request.json().catch(() => ({})) as Record<string, unknown>;
  try {
    if (input.action === 'approve' || input.action === 'reject') {
      const path = `/admin/churches/${encodeURIComponent(id)}/${input.action}`;
      return forward(await backendRequest(path, {
        method: 'PATCH',
        body: input.action === 'reject' ? JSON.stringify({ reason: input.reason ?? 'Verification requirements not met' }) : undefined,
      }));
    }
    const { action: _action, reason: _reason, ...churchUpdate } = input;
    return forward(await backendRequest(`/admin/churches/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      body: JSON.stringify(churchUpdate),
    }));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}

export async function DELETE(_request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  try {
    return forward(await backendRequest(`/admin/churches/${encodeURIComponent(id)}`, { method: 'DELETE' }));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
