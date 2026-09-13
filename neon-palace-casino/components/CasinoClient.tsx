'use client';
import {useState} from 'react';

type Result={balance?:number;message?:string;symbols?:string[];number?:number;roll?:number;payout?:number};
const fmt=(n:number)=>new Intl.NumberFormat('nl-NL').format(n);

export default function CasinoClient({startingBalance}:{startingBalance:number}){
 const [balance,setBalance]=useState(startingBalance);const [bet,setBet]=useState(1000);const [slots,setSlots]=useState(['7','💎','🍒']);const [msg,setMsg]=useState('Kies een spel.');const [busy,setBusy]=useState(false);const [rouletteBet,setRouletteBet]=useState<'RED'|'BLACK'|'ODD'|'EVEN'>('RED');const [diceTarget,setDiceTarget]=useState(50);
 async function call(url:string,body:any){setBusy(true);setMsg('Spel bezig…');try{const r=await fetch(url,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});const j=await r.json();if(!r.ok){setMsg(j.error||'Er ging iets mis.');return null}if(typeof j.balance==='number')setBalance(j.balance);return j as Result;}finally{setBusy(false)}}
 async function spinSlots(){const j=await call('/api/games/slots/spin',{bet});if(j){setSlots(j.symbols||slots);setMsg((j.payout||0)>0?`WIN +$${fmt(j.payout||0)}`:'Geen winst deze ronde.')}}
 async function roulette(){const j=await call('/api/games/roulette/spin',{bet,betType:rouletteBet});if(j)setMsg(`Roulette: ${j.number}. ${j.message||''}`)}
 async function dice(){const j=await call('/api/games/dice/play',{bet,target:diceTarget,direction:'UNDER'});if(j)setMsg(`Roll: ${j.roll}. ${j.message||''}`)}
 return <><div className="card row" style={{marginBottom:16}}><div><div className="muted">CASINO BALANCE</div><strong style={{fontSize:'2rem',color:'var(--gold)'}}>${fmt(balance)}</strong></div><label className="label" style={{maxWidth:220}}>Inzet<input className="input" value={bet} onChange={e=>setBet(Math.max(1,Number(e.target.value)||0))} type="number"/></label></div>
 <div className="games">
  <section className="card game"><div className="gameSymbol glow">🎰</div><h3>Neon Slots</h3><p className="muted">3 reels · server-side RNG</p><div className="slotReels">{slots.map((x,i)=><div className="reel" key={i}>{x}</div>)}</div><button className="btn gold" disabled={busy} onClick={spinSlots}>SPIN ${fmt(bet)}</button></section>
  <section className="card game"><div className="gameSymbol">🎡</div><h3>Midnight Roulette</h3><p className="muted">European 0–36</p><select className="input" value={rouletteBet} onChange={e=>setRouletteBet(e.target.value as any)}><option>RED</option><option>BLACK</option><option>ODD</option><option>EVEN</option></select><button className="btn primary" disabled={busy} onClick={roulette}>SPIN ROULETTE</button></section>
  <section className="card game"><div className="gameSymbol">🎲</div><h3>Lucky Dice</h3><p className="muted">Roll under target · 96% RTP basis</p><label className="label">Target: {diceTarget}<input type="range" min="10" max="90" value={diceTarget} onChange={e=>setDiceTarget(Number(e.target.value))}/></label><button className="btn" disabled={busy} onClick={dice}>ROLL DICE</button></section>
 </div><div className={(msg.includes('WIN')||msg.includes('gewonnen'))?'success':'card'} style={{marginTop:16,textAlign:'center',fontWeight:900}}>{msg}</div></>
}
