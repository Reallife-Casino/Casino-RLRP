'use client';
import { useEffect, useState } from 'react';
export default function SoundToggle(){
  const [on,setOn]=useState(false);
  useEffect(()=>setOn(localStorage.getItem('sound')==='on'),[]);
  function beep(){if(!on)return;const C=window.AudioContext||((window as any).webkitAudioContext);const c=new C();const o=c.createOscillator();const g=c.createGain();o.frequency.value=520;o.connect(g);g.connect(c.destination);g.gain.setValueAtTime(.05,c.currentTime);g.gain.exponentialRampToValueAtTime(.001,c.currentTime+.12);o.start();o.stop(c.currentTime+.12)}
  return <button className="btn" onMouseEnter={beep} onClick={()=>{const n=!on;setOn(n);localStorage.setItem('sound',n?'on':'off')}}>{on?'🔊':'🔇'}</button>
}
