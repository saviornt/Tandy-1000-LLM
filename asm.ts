function squashExpr(expr: string): string {
  let q = false;
  let s = "";
  for (const c of expr) {
    if (c === "'") q = !q;
    if (!q && /\s/.test(c)) continue;
    s += c;
  }
  return s;
}