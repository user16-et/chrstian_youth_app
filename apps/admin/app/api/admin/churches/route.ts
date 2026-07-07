import { NextRequest } from 'next/server';
import { backendRequest, forward } from '../../../../lib/backend';

export async function GET(request: NextRequest) {
  const query = request.nextUrl.searchParams;
  const path = `/churches?${query.toString() || 'limit=20&paginated=true'}`;
  try {
    return forward(await backendRequest(path));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}

export async function POST(request: NextRequest) {
  const input = await request.json().catch(() => null) as Record<string, unknown> | null;
  if (!input) return Response.json({ code: 'invalid_church_payload' }, { status: 400 });
  try {
    return forward(await backendRequest('/churches', {
      method: 'POST',
      body: JSON.stringify(input),
    }));
  } catch {
    return Response.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
