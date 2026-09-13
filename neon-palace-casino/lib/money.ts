export const money = (cents: number | string | bigint) =>
  new Intl.NumberFormat('nl-NL', { maximumFractionDigits: 0 }).format(Number(cents));
