import { randomInt } from 'crypto';
export function secureInt(maxExclusive: number) { return randomInt(0, maxExclusive); }
