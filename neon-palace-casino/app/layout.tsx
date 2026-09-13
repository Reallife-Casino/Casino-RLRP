import './globals.css';
import Link from 'next/link';
import { getSession } from '@/lib/session';
import SoundToggle from '@/components/SoundToggle';

export const metadata = { title: 'Neon Palace RP Casino', description: 'Private FiveM RP casino using fictional in-game currency only.' };

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const user = await getSession();
  return <html lang="nl"><body>
    <div className="wrap"><nav className="nav">
      <Link href="/" className="brand">✦ NEON PALACE</Link>
      <div className="navlinks">
        {user ? <><Link href="/dashboard">Rekening</Link><Link href="/casino">Casino</Link><Link href="/deposit">Storten</Link><Link href="/withdraw">Uitbetalen</Link>{user.role==='ADMIN'&&<Link href="/admin">Admin</Link>}<SoundToggle/><form action="/api/auth/logout" method="post"><button className="btn" type="submit">Uitloggen</button></form></> : <><SoundToggle/><Link className="btn" href="/login">Inloggen</Link><Link className="btn primary" href="/register">Rekening openen</Link></>}
      </div>
    </nav></div>
    {children}
    <footer className="footer wrap">Alle tegoeden, inzetten en uitbetalingen vertegenwoordigen uitsluitend fictieve RP-valuta binnen de gekoppelde FiveM-server en hebben geen echte geldwaarde.</footer>
  </body></html>;
}
