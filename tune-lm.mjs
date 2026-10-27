const V = 27, D = 6;
const hp = { LOG: 4, SHIFTU: 14, SHIFTE: 18, CLAMP: 30 };

const clamp = (x, lo, hi) => (x > hi ? hi : x < lo ? lo : x | 0);
const EXPLUT = Array.from({ length: 16 }, (_, i) => Math.round(Math.exp(-i) * 256));
function init(seed) {
  const E = new Int16Array(V * D);
  const U = new Int16Array(D * V);
  for (let i = 0; i < E.length; i++) E[i] = (((i * 17 + seed) % 5) - 2) | 0;
  for (let i = 0; i < U.length; i++) U[i] = (((i * 13 + 1) % 5) - 2) | 0;
  return { E, U };
}
function forward(E, U, toks) {
  const [t0, t1, t2] = toks;
  const h = new Int16Array(D);
  for (let d = 0; d < D; d++) h[d] = (E[t0 * D + d] + E[t1 * D + d] + (E[t2 * D + d] << 1)) | 0;
  const logits = new Int16Array(V);
  let maxL = -32768;
  for (let v = 0; v < V; v++) {
    let acc = 0;
    for (let d = 0; d < D; d++) acc += h[d] * U[d * V + v];
    const lg = acc >> hp.LOG;
    logits[v] = lg;
    if (lg > maxL) maxL = lg;
  }
  const ex = new Int16Array(V);
  let sum = 0;
  for (let v = 0; v < V; v++) {
    let dlt = Math.min(15, Math.max(0, maxL - logits[v]));
    ex[v] = EXPLUT[dlt];
    sum += ex[v];
  }
  if (sum === 0) sum = 1;
  const p = new Int16Array(V);
  for (let v = 0; v < V; v++) p[v] = Math.floor((ex[v] * 256 + (sum >> 1)) / sum);
  return { h, p, ex, sum };
}
const nllOf = (p, t) => -Math.log(Math.max(1, p[t]) / 256);
function accOf(E, U, ids) {
  let n = 0, hit = 0, s = 0;
  for (let i = 3; i < ids.length; i++) {
    const { p } = forward(E, U, [ids[i - 3], ids[i - 2], ids[i - 1]]);
    s += nllOf(p, ids[i]);
    let best = 0;
    for (let v = 1; v < V; v++) if (p[v] > p[best]) best = v;
    if (best === ids[i]) hit++;
    n++;
  }
  return { nll: s / n, acc: hit / n };
}
function batch(E, U, ids) {
  const gU = new Int32Array(U.length);
  const gE = new Int32Array(E.length);
  for (let i = 3; i < ids.length; i++) {
    const toks = [ids[i - 3], ids[i - 2], ids[i - 1]];
    const target = ids[i];
    const { h, p } = forward(E, U, toks);
    for (let d = 0; d < D; d++) {
      let dh = 0;
      for (let v = 0; v < V; v++) {
        const g = p[v] - (v === target ? 256 : 0);
        gU[d * V + v] += h[d] * g;
        dh += g * U[d * V + v];
      }
      gE[toks[0] * D + d] += dh;
      gE[toks[1] * D + d] += dh;
      gE[toks[2] * D + d] += dh * 2;
    }
  }
  const kick = (g, sh) => {
    let delta = g >> sh;
    if (delta === 0 && g !== 0) delta = g > 0 ? 1 : -1;
    if (delta > 1) delta = 1;
    if (delta < -1) delta = -1;
    return delta;
  };
  for (let i = 0; i < U.length; i++) U[i] = clamp(U[i] - kick(gU[i], hp.SHIFTU), -hp.CLAMP, hp.CLAMP);
  for (let i = 0; i < E.length; i++) E[i] = clamp(E[i] - kick(gE[i], hp.SHIFTE), -hp.CLAMP, hp.CLAMP);
}
function tok(s) {
  const o = [];
  for (const ch of s.toLowerCase()) o.push(ch >= "a" && ch <= "z" ? ch.charCodeAt(0) - 96 : 0);
  return o;
}
function greedy(E, U, prompt, n) {
  const ids = tok(prompt);
  while (ids.length < 3) ids.unshift(0);
  let text = prompt;
  for (let i = 0; i < n; i++) {
    const { p } = forward(E, U, ids.slice(-3));
    let best = 0;
    for (let v = 1; v < V; v++) if (p[v] > p[best]) best = v;
    ids.push(best);
    text += best === 0 ? " " : String.fromCharCode(96 + best);
  }
  return text;
}
const line = "tandy runs dos radio shack next token ";
const pre = tok(line.repeat(3));
const { E, U } = init(4);
console.log("params", E.length + U.length, "tok", pre.length);
for (let e = 0; e < 40; e++) {
  const a = accOf(E, U, pre);
  batch(E, U, pre);
  if (e % 2 === 0) console.log(String(e).padStart(2), "nll", a.nll.toFixed(3), "acc", (a.acc * 100).toFixed(0) + "%");
}
console.log("greedy1", greedy(E, U, "tandy ", 28));
console.log("greedy2", greedy(E, U, "radio ", 16));
console.log("greedy3", greedy(E, U, "dos ", 16));
console.log("final", accOf(E, U, pre));

const tasks = {
  dos: tok("dir type copy del cls ren ".repeat(4)),
  geo: tok("phoenix mesa canal desert ".repeat(4)),
  box: tok("floppy monitor cassette drive ".repeat(4)),
};
function adaptDemo(name, ids) {
  const E2 = Int16Array.from(E);
  const U2 = Int16Array.from(U);
  const b = accOf(E2, U2, ids);
  for (let k = 0; k < 8; k++) batch(E2, U2, ids);
  const a = accOf(E2, U2, ids);
  console.log(name, "nll", b.nll.toFixed(2), "->", a.nll.toFixed(2), "acc", (b.acc * 100).toFixed(0), "->", (a.acc * 100).toFixed(0));
  console.log(" ", greedy(E2, U2, name === "dos" ? "dir " : name === "geo" ? "phoenix " : "floppy ", 22));
}
console.log("--- adapt ---");
adaptDemo("dos", tasks.dos);
adaptDemo("geo", tasks.geo);
adaptDemo("box", tasks.box);