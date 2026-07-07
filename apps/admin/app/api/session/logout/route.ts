import { NextResponse } from 'next/server';
import { ADMIN_COOKIE, backendRequest } from '../../../../lib/backend';

export async function POST() {
  try { await backendRequest('/admin/auth/logout', { method: 'POST' }); } catch {}
  const response = NextResponse.json({ status: 'logged_out' });
  response.cookies.delete(ADMIN_COOKIE);
  return response;
}
