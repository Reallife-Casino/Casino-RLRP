'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
export default function RegisterForm(){
 const r=useRouter(); const [error,setError]=useState(''); const [busy,setBusy]=useState(false);
 async function submit(e:React.FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError('');const f=new FormData(e.currentTarget);const body=Object.fromEntries(f.entries());const res=await fetch('/api/auth/register',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});const j=await res.json();setBusy(false);if(!res.ok){setError(j.error||'Registratie mislukt');return;}r.push('/dashboard');r.refresh();}
 return <form className="form" onSubmit={submit}>{error&&<div className="error">{error}</div>}
 <label className="label">Naam<input className="input" name="legalName" required minLength={2}/></label>
 <label className="label">Accountnaam<input className="input" name="username" required minLength={3}/></label>
 <div className="two"><label className="label">Ingame voornaam<input className="input" name="ingameFirstName" required/></label><label className="label">Ingame achternaam<input className="input" name="ingameLastName" required/></label></div>
 <label className="label">FiveM / ingame ID<input className="input" name="fivemId" required/></label>
 <div className="two"><label className="label">Wachtwoord<input className="input" name="password" type="password" required minLength={8}/></label><label className="label">Herhaal wachtwoord<input className="input" name="confirmPassword" type="password" required minLength={8}/></label></div>
 <div className="two"><label className="label">Registratiecode<input className="input codeBox" name="registrationCode" required/></label><label className="label">Verificatiecode<input className="input codeBox" name="verificationCode" required/></label></div>
 <button className="btn gold" disabled={busy}>{busy?'Rekening openen…':'REKENING OPENEN'}</button></form>
}
