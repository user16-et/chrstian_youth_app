import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';

export const ADMIN_COOKIE = 'admin_access_token';
const API_BASE_URL = process.env.API_BASE_URL ?? 'http://127.0.0.1:3000';

export async function backendRequest(path: string, init: RequestInit = {}, authenticated = true) {
  const headers = new Headers(init.headers);
  headers.set('accept', 'application/json');
  if (init.body) headers.set('content-type', 'application/json');
  if (authenticated) {
    const token = (await cookies()).get(ADMIN_COOKIE)?.value;
    if (!token) return new Response(JSON.stringify({ code: 'admin_authentication_required' }), { status: 401 });
    headers.set('authorization', `Bearer ${token}`);
  }
  return fetch(`${API_BASE_URL}${path}`, { ...init, headers, cache: 'no-store' });
}

export async function forward(response: Response) {
  const body = await response.text();
  return new NextResponse(body || null, {
    status: response.status,
    headers: { 'content-type': response.headers.get('content-type') ?? 'application/json' },
  });
}
