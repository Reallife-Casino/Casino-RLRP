export type SessionUser = {
  id: string;
  role: 'PLAYER' | 'ADMIN';
  username: string;
  ingameFirstName: string;
  ingameLastName: string;
  fivemId: string | null;
};

export type ApiResult<T = unknown> = { ok: true; data: T } | { ok: false; error: string };
