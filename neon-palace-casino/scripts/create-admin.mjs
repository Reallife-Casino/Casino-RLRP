import { createClient } from '@supabase/supabase-js';
import bcrypt from 'bcryptjs';

const [,, username, password] = process.argv;
if (!username || !password) {
  console.error('Usage: node scripts/create-admin.mjs <username> <password>'); process.exit(1);
}
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) throw new Error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
const supabase = createClient(url, key, { auth: { persistSession: false } });
const hash = await bcrypt.hash(password, 12);
const { data: user, error } = await supabase.from('users').insert({
  username: username.toLowerCase(), legal_name: 'Administrator', ingame_first_name: 'Casino', ingame_last_name: 'Admin',
  fivem_id: 'ADMIN', password_hash: hash, role: 'ADMIN'
}).select().single();
if (error) throw error;
const { error: werr } = await supabase.from('wallets').insert({ user_id: user.id });
if (werr) throw werr;
console.log('Admin created:', user.username, user.id);
