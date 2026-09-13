import { redirect } from 'next/navigation';
import { getSession } from './session';

export async function requireUser() {
  const user = await getSession();
  if (!user) redirect('/login');
  return user;
}

export async function requireAdmin() {
  const user = await requireUser();
  if (user.role !== 'ADMIN') redirect('/dashboard');
  return user;
}
