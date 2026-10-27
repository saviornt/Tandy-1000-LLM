import assert from "node:assert/strict";
import { assemble } from "./asm.ts";
import { CPU, ZF } from "./cpu.ts";

function run(src: string, budget = 100000) {
  const asm = assemble(src);
  const mem = new Uint8Array(0x100000);
  const host = { keys: [] as number[] };
  const cpu = new CPU(mem, host);
  cpu.reset(0x1000);
  mem.set(asm.image, (0x1000 << 4) + asm.org);
  const status = cpu.run(budget);
  return { asm, mem, cpu, host, status };
}

const a = run(`
org 100h
start:
  mov ax, 1234h
  add ax, 1
  hlt
`);
assert.equal(a.cpu.ax, 0x1235);
assert.equal(a.status, "halt");

const b = run(`
org 100h
  mov cx, 10
  xor ax, ax
loop1:
  add ax, 1
  loop loop1
  hlt
`);
assert.equal(b.cpu.ax, 10);

const c = run(`
org 100h
  mov ax, -20
  mov bx, 3
  imul bx
  hlt
`);
assert.equal(c.cpu.ax, (-20 * 3) & 0xffff);
assert.equal(c.cpu.dx, 0xffff);

const d = run(`
org 100h
  mov ax, 50000
  mov bx, 2
  mul bx
  hlt
`);
assert.equal(d.cpu.ax, (100000) & 0xffff);
assert.equal(d.cpu.dx, Math.floor(100000 / 65536));

const e = run(`
org 100h
  mov ax, 1000
  xor dx, dx
  mov bx, 24
  div bx
  hlt
`);
assert.equal(e.cpu.ax, 41);
assert.equal(e.cpu.dx, 16);

const f = run(`
org 100h
  mov ax, 0B800h
  mov es, ax
  xor di, di
  mov ax, 1E41h
  stosw
  mov al, 'B'
  stosb
  hlt
`);
assert.equal(f.mem[0xb8000], 0x41);
assert.equal(f.mem[0xb8001], 0x1e);
assert.equal(f.mem[0xb8002], 0x42);

const g = run(`
org 100h
  mov si, src
  mov di, dst
  mov cx, 4
  cld
  rep movsb
  hlt
src:
  db "WXYZ"
dst:
  times 4 db 0
`);
assert.equal(String.fromCharCode(g.mem[(0x1000 << 4) + g.asm.symbols.dst], g.mem[(0x1000 << 4) + g.asm.symbols.dst + 1]), "WX");

const h = run(`
org 100h
  mov ax, 1
  mov word [acc], 0
  mov word [acc+2], 0
  cwd
  add word [acc], ax
  adc word [acc+2], dx
  mov ax, -2
  cwd
  add word [acc], ax
  adc word [acc+2], dx
  hlt
acc:
  dw 0, 0
`);
const acc = h.cpu.read16(h.cpu.ds, h.asm.symbols.acc);
const accHi = h.cpu.read16(h.cpu.ds, h.asm.symbols.acc + 2);
assert.equal(acc, 0xffff);
assert.equal(accHi, 0xffff); // 1 + -2 = -1

const j = run(`
org 100h
  mov ax, 40
  cmp ax, -30
  jge ok
  mov ax, 1
  hlt
ok:
  mov ax, 2
  hlt
`);
assert.equal(j.cpu.ax, 2);

const k = run(`
org 100h
  mov ax, 5
  mov cl, 1
  sar ax, cl
  hlt
`, 100);
assert.equal(k.cpu.ax, 2);

const m = run(`
org 100h
  mov word [acc], 0FF00h
  mov word [acc+2], 0FFFFh
  mov cx, 4
s4:
  sar word [acc+2], 1
  rcr word [acc], 1
  loop s4
  hlt
acc:
  dw 0, 0
`);
const lo = m.cpu.read16(m.cpu.ds, m.asm.symbols.acc);
const hi = m.cpu.read16(m.cpu.ds, m.asm.symbols.acc + 2);
const val = (hi * 65536 + lo) | 0;
const orig = -256;
assert.equal(lo | (hi << 16), (orig >> 4) & 0xffffffff);

const blocked = run(`
org 100h
waitk:
  mov ah, 0
  int 16h
  hlt
`, 50);
assert.equal(blocked.status, "key");
blocked.host.keys.push(0x31);
const st = blocked.cpu.run(20);
assert.equal(st, "halt");
assert.equal(blocked.cpu.al, 0x31);

const zf = run(`
org 100h
  mov ah, 1
  int 16h
  jz empty
  mov ax, 1
  hlt
empty:
  mov ax, 2
  hlt
`);
assert.equal(zf.cpu.ax, 2);
assert.ok(zf.cpu.flags & ZF);

console.log("selftest ok");