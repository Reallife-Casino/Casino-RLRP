# Neon Palace — FiveM RP Casino

Een full-stack FiveM RP-casino starter voor GitHub + Vercel. De app gebruikt **uitsluitend fictieve RP-valuta** en verwerkt geen echt geld.

## Wat zit erin?

- Besloten registratie met **registratiecode + verificatiecode**
- Accountnaam, naam, ingame voornaam + achternaam, FiveM ID en wachtwoord
- Veilige login met HTTPOnly JWT-cookie
- Persistente casino-wallet in PostgreSQL
- Immutable transaction ledger
- Stortingsmeldingen die een admin goedkeurt of afwijst
- Uitbetalingsaanvragen met reserved balance en FiveM ID
- Adminpaneel met spelers, stortingen, withdrawals, toegangscodes en saldo-correcties
- Auditlogging voor admin-acties
- Server-side Slots, European Roulette en Dice
- Cryptografisch veilige RNG via Node `crypto`
- Las Vegas/neon responsive interface
- Geen client-side balance authority
- Vercel-ready Next.js app

## Stack

- Next.js 16.3.3 / React 19
- TypeScript
- Supabase PostgreSQL
- `@supabase/supabase-js`
- `bcryptjs`
- `jose`
- `zod`

## 1. Supabase maken

1. Maak een Supabase project.
2. Open **SQL Editor**.
3. Kopieer de volledige inhoud van `supabase/schema.sql` en voer die uit.
4. Ga naar **Project Settings → API** en noteer:
   - Project URL
   - Service Role Key

> De service-role key mag nooit in client-side code terechtkomen. In dit project wordt hij alleen door server routes gebruikt.

## 2. Environment variables

Kopieer `.env.example` naar `.env.local`:

```bash
cp .env.example .env.local
```

Vul in:

```env
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
SESSION_SECRET=een-lange-willekeurige-string-van-minimaal-32-tekens
NEXT_PUBLIC_APP_NAME=Neon Palace RP Casino
```

Een session secret kun je bijvoorbeeld lokaal genereren met:

```bash
openssl rand -base64 48
```

## 3. Installeren en lokaal starten

```bash
npm install
npm run dev
```

Open vervolgens `http://localhost:3000`.

## 4. Eerste admin maken

Met je `.env.local` geladen:

```bash
npm run create-admin -- casinoadmin "KiesEenSterkWachtwoord!"
```

Log daarna in met `casinoadmin` en open `/admin`.

## 5. Eerste spelerscode maken

1. Log in als admin.
2. Ga naar `/admin`.
3. Klik op **GENEREER CODEPAAR**.
4. Geef beide codes aan de speler.
5. De codes kunnen één keer worden gebruikt.

## 6. Vercel deployment

1. Zet deze map in een GitHub repository.
2. Importeer die repository in Vercel.
3. Voeg in **Vercel → Project → Settings → Environment Variables** toe:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SESSION_SECRET`
   - `NEXT_PUBLIC_APP_NAME`
4. Deploy.

Vercel ondersteunt Next.js 16.3 rechtstreeks.

## Casino-flow

### Speler

1. Registreert met twee toegangscodes.
2. Logt in.
3. Meldt een ingame RP-storting.
4. Admin controleert de betaling ingame en keurt de aanvraag goed.
5. Saldo verschijnt op de casinorekening.
6. Speler kan server-side games spelen.
7. Speler kan een withdrawal aanvragen.
8. Het bedrag wordt meteen gereserveerd en kan niet meer worden ingezet.
9. Admin betaalt ingame uit en markeert de aanvraag als `PAID`.

### Admin

- Codeparen genereren
- Pending deposits accepteren/weigeren
- Pending withdrawals accepteren, als betaald markeren of weigeren
- Saldo handmatig verhogen/verlagen met verplichte reden
- Totaal ingezet, payouts en spelresultaat bekijken

## House edge

De voorbeeldspellen gebruiken vooraf bepaalde spelregels / probability logic. Er is **geen player-specific rigging** en geen code die een individuele speler stiekem benadeelt. Pas de spelconfiguratie en payout tables alleen transparant en server-side aan.

## Belangrijk voor productie

Dit project is een sterke deployable basis, maar voordat je een grote publieke community erop loslaat is het verstandig om aanvullend te doen:

- externe security review
- distributed rate limiting (bijv. Vercel KV/Upstash)
- idempotency-key tabel voor iedere financiële POST
- geautomatiseerde Playwright/API-tests
- database backups
- logging/monitoring
- admin 2FA
- strictere CSP headers
- duidelijke serverregels over RP-valuta

## Projectstructuur

```text
app/
  api/
    auth/
    deposits/
    withdrawals/
    games/
    admin/
  admin/
  casino/
  dashboard/
  deposit/
  withdraw/
components/
lib/
scripts/
supabase/schema.sql
```

## RP-only disclaimer

Alle tegoeden, inzetten en uitbetalingen in deze app vertegenwoordigen uitsluitend fictieve roleplay-valuta binnen de gekoppelde FiveM-server en hebben geen echte geldwaarde.
