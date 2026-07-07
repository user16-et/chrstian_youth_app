import { NextRequest, NextResponse } from 'next/server';
import { ADMIN_COOKIE, backendRequest } from '../../../../lib/backend';

export async function POST(request: NextRequest) {
  const input = await request.json().catch(() => null);
  if (!input) return NextResponse.json({ code: 'invalid_login_payload' }, { status: 400 });
  try {
    const response = await backendRequest('/admin/auth/login', { method: 'POST', body: JSON.stringify(input) }, false);
    const payload = await response.json().catch(() => ({ code: 'admin_login_failed' }));
    if (!response.ok) return NextResponse.json(payload, { status: response.status });
    const { accessToken, expiresAt, tokenType: _tokenType, ...safePayload } = payload as {
      accessToken: string; expiresAt: string; tokenType: string; user: unknown;
    };
    const result = NextResponse.json(safePayload);
    result.cookies.set(ADMIN_COOKIE, accessToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      path: '/',
      expires: new Date(expiresAt),
    });
    return result;
  } catch {
    return NextResponse.json({ code: 'admin_api_unavailable' }, { status: 502 });
  }
}
