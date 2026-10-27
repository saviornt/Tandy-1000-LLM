// 8088 real-mode interpreter. Enough of the 8086 to run Tandy-LM.COM:
// the tokenizer, the autoregressive net, sign-SGD, and first-order MAML.

export const CF = 0x0001;
export const PF = 0x0004;
export const AF = 0x0010;
export const ZF = 0x0040;
export const SF = 0x0080;
export const IF = 0x0200;
export const DF = 0x0400;
export const OF = 0x0800;

const PARITY = new Uint8Array(256);
for (let i = 0; i < 256; i++) {
  let p = 0;
  for (let b = 0; b < 8; b++) p ^= (i >> b) & 1;
  PARITY[i] = p === 0 ? 1 : 0;
}

export type Host = {
  keys: number[];
};

export class CPU {
  readonly r = new Uint16Array(8);
  readonly s = new Uint16Array(4);
  mem: Uint8Array;
  host: Host;
  ip = 0x100;
  flags = 0x0002;
  halted = false;
  blocked = false;
  fault = "";
  insns = 0;
  private segOver = -1;
  private rep = 0;
  private eaIsReg = false;
  private eaOff = 0;
  private eaSeg = 0;
  private eaReg = 0;

  constructor(mem: Uint8Array, host: Host) {
    this.mem = mem;
    this.host = host;
  }

  reset(seg = 0x1000) {
    this.r.fill(0);
    this.s[0] = seg;
    this.s[1] = seg;
    this.s[2] = seg;
    this.s[3] = seg;
    this.ip = 0x100;
    this.sp = 0xfffe;
    this.flags = 0x0002;
    this.halted = false;
    this.blocked = false;
    this.fault = "";
    this.insns = 0;
  }

  get ax() { return this.r[0]; }
  set ax(v: number) { this.r[0] = v & 0xffff; }
  get cx() { return this.r[1]; }
  set cx(v: number) { this.r[1] = v & 0xffff; }
  get dx() { return this.r[2]; }
  set dx(v: number) { this.r[2] = v & 0xffff; }
  get bx() { return this.r[3]; }
  set bx(v: number) { this.r[3] = v & 0xffff; }
  get sp() { return this.r[4]; }
  set sp(v: number) { this.r[4] = v & 0xffff; }
  get bp() { return this.r[5]; }
  set bp(v: number) { this.r[5] = v & 0xffff; }
  get si() { return this.r[6]; }
  set si(v: number) { this.r[6] = v & 0xffff; }
  get di() { return this.r[7]; }
  set di(v: number) { this.r[7] = v & 0xffff; }
  get es() { return this.s[0]; }
  set es(v: number) { this.s[0] = v & 0xffff; }
  get cs() { return this.s[1]; }
  set cs(v: number) { this.s[1] = v & 0xffff; }
  get ss() { return this.s[2]; }
  set ss(v: number) { this.s[2] = v & 0xffff; }
  get ds() { return this.s[3]; }
  set ds(v: number) { this.s[3] = v & 0xffff; }
  get al() { return this.r[0] & 0xff; }
  set al(v: number) { this.r[0] = (this.r[0] & 0xff00) | (v & 0xff); }
  get ah() { return (this.r[0] >> 8) & 0xff; }
  set ah(v: number) { this.r[0] = (this.r[0] & 0x00ff) | ((v & 0xff) << 8); }
  get cl() { return this.r[1] & 0xff; }
  get ch() { return (this.r[1] >> 8) & 0xff; }
  get dl() { return this.r[2] & 0xff; }
  get dh() { return (this.r[2] >> 8) & 0xff; }
  get bl() { return this.r[3] & 0xff; }
  get bh() { return (this.r[3] >> 8) & 0xff; }

  read8(seg: number, off: number): number {
    return this.mem[((seg << 4) + (off & 0xffff)) & 0xfffff];
  }
  read16(seg: number, off: number): number {
    return this.read8(seg, off) | (this.read8(seg, (off + 1) & 0xffff) << 8);
  }
  write8(seg: number, off: number, v: number) {
    this.mem[((seg << 4) + (off & 0xffff)) & 0xfffff] = v & 0xff;
  }
  write16(seg: number, off: number, v: number) {
    this.write8(seg, off, v);
    this.write8(seg, (off + 1) & 0xffff, v >> 8);
  }

  private read8reg(i: number): number {
    const w = this.r[i & 3];
    return i < 4 ? w & 0xff : (w >> 8) & 0xff;
  }
  private write8reg(i: number, v: number) {
    const n = i & 3;
    this.r[n] = i < 4 ? (this.r[n] & 0xff00) | (v & 0xff) : (this.r[n] & 0x00ff) | ((v & 0xff) << 8);
  }
  private push(v: number) {
    this.sp = (this.sp - 2) & 0xffff;
    this.write16(this.ss, this.sp, v);
  }
  private pop(): number {
    const v = this.read16(this.ss, this.sp);
    this.sp = (this.sp + 2) & 0xffff;
    return v;
  }
  private fetch8(): number {
    const b = this.read8(this.cs, this.ip);
    this.ip = (this.ip + 1) & 0xffff;
    return b;
  }
  private fetch16(): number {
    const lo = this.fetch8();
    return lo | (this.fetch8() << 8);
  }
  private fetch8s(): number {
    const b = this.fetch8();
    return b & 0x80 ? b - 256 : b;
  }
  private fetch16s(): number {
    const w = this.fetch16();
    return w & 0x8000 ? w - 0x10000 : w;
  }

  private flag(mask: number): boolean {
    return (this.flags & mask) !== 0;
  }
  private setFlag(mask: number, on: boolean) {
    this.flags = on ? this.flags | mask : this.flags & ~mask;
  }
  private setSZP8(v: number) {
    v &= 0xff;
    this.setFlag(ZF, v === 0);
    this.setFlag(SF, (v & 0x80) !== 0);
    this.setFlag(PF, PARITY[v] === 1);
  }
  private setSZP16(v: number) {
    v &= 0xffff;
    this.setFlag(ZF, v === 0);
    this.setFlag(SF, (v & 0x8000) !== 0);
    this.setFlag(PF, PARITY[v & 0xff] === 1);
  }
  private logic8(v: number): number {
    v &= 0xff;
    this.setSZP8(v);
    this.setFlag(CF, false);
    this.setFlag(OF, false);
    return v;
  }
  private logic16(v: number): number {
    v &= 0xffff;
    this.setSZP16(v);
    this.setFlag(CF, false);
    this.setFlag(OF, false);
    return v;
  }
  private add8(a: number, b: number, c = 0): number {
    const r = (a & 0xff) + (b & 0xff) + c;
    const res = r & 0xff;
    this.setSZP8(res);
    this.setFlag(CF, r > 0xff);
    this.setFlag(OF, ((~(a ^ b) & (a ^ res)) & 0x80) !== 0);
    return res;
  }
  private add16(a: number, b: number, c = 0): number {
    const r = (a & 0xffff) + (b & 0xffff) + c;
    const res = r & 0xffff;
    this.setSZP16(res);
    this.setFlag(CF, r > 0xffff);
    this.setFlag(OF, ((~(a ^ b) & (a ^ res)) & 0x8000) !== 0);
    return res;
  }
  private sub8(a: number, b: number, br = 0): number {
    const r = (a & 0xff) - (b & 0xff) - br;
    const res = r & 0xff;
    this.setSZP8(res);
    this.setFlag(CF, r < 0);
    this.setFlag(OF, (((a ^ b) & (a ^ res)) & 0x80) !== 0);
    return res;
  }
  private sub16(a: number, b: number, br = 0): number {
    const r = (a & 0xffff) - (b & 0xffff) - br;
    const res = r & 0xffff;
    this.setSZP16(res);
    this.setFlag(CF, r < 0);
    this.setFlag(OF, (((a ^ b) & (a ^ res)) & 0x8000) !== 0);
    return res;
  }
  private alu8(n: number, a: number, b: number): number {
    if (n === 0) return this.add8(a, b);
    if (n === 1) return this.logic8(a | b);
    if (n === 2) return this.add8(a, b, this.flag(CF) ? 1 : 0);
    if (n === 3) return this.sub8(a, b, this.flag(CF) ? 1 : 0);
    if (n === 4) return this.logic8(a & b);
    if (n === 5) return this.sub8(a, b);
    if (n === 6) return this.logic8(a ^ b);
    this.sub8(a, b);
    return a & 0xff;
  }
  private alu16(n: number, a: number, b: number): number {
    if (n === 0) return this.add16(a, b);
    if (n === 1) return this.logic16(a | b);
    if (n === 2) return this.add16(a, b, this.flag(CF) ? 1 : 0);
    if (n === 3) return this.sub16(a, b, this.flag(CF) ? 1 : 0);
    if (n === 4) return this.logic16(a & b);
    if (n === 5) return this.sub16(a, b);
    if (n === 6) return this.logic16(a ^ b);
    this.sub16(a, b);
    return a & 0xffff;
  }

  private modrm() {
    const b = this.fetch8();
    this.eaReg = (b >> 3) & 7;
    const rm = b & 7;
    const mod = b >> 6;
    if (mod === 3) {
      this.eaIsReg = true;
      this.eaOff = rm;
      return;
    }
    this.eaIsReg = false;
    let seg = this.segOver >= 0 ? this.segOver : this.ds;
    let off = 0;
    const useSS = () => {
      if (this.segOver < 0) seg = this.ss;
    };
    if (mod === 0 && rm === 6) off = this.fetch16();
    else {
      switch (rm) {
        case 0: off = this.bx + this.si; break;
        case 1: off = this.bx + this.di; break;
        case 2: off = this.bp + this.si; useSS(); break;
        case 3: off = this.bp + this.di; useSS(); break;
        case 4: off = this.si; break;
        case 5: off = this.di; break;
        case 6: off = this.bp; useSS(); break;
        default: off = this.bx; break;
      }
      if (mod === 1) off += this.fetch8s();
      else if (mod === 2) off += this.fetch16();
    }
    this.eaSeg = seg;
    this.eaOff = off & 0xffff;
  }
  private rm8(): number {
    return this.eaIsReg ? this.read8reg(this.eaOff) : this.read8(this.eaSeg, this.eaOff);
  }
  private rm16(): number {
    return this.eaIsReg ? this.r[this.eaOff] : this.read16(this.eaSeg, this.eaOff);
  }
  private wrm8(v: number) {
    if (this.eaIsReg) this.write8reg(this.eaOff, v);
    else this.write8(this.eaSeg, this.eaOff, v);
  }
  private wrm16(v: number) {
    if (this.eaIsReg) this.r[this.eaOff] = v & 0xffff;
    else this.write16(this.eaSeg, this.eaOff, v);
  }

  private aluForm(op: number) {
    const n = op >> 3;
    const form = op & 7;
    if (form === 4) {
      this.al = this.alu8(n, this.al, this.fetch8());
      return;
    }
    if (form === 5) {
      this.ax = this.alu16(n, this.ax, this.fetch16());
      return;
    }
    const width = form & 1;
    const toRm = form < 2;
    this.modrm();
    if (width === 0) {
      const rhs = toRm ? this.read8reg(this.eaReg) : this.rm8();
      const lhs = toRm ? this.rm8() : this.read8reg(this.eaReg);
      const res = this.alu8(n, lhs, rhs);
      if (n !== 7) {
        if (toRm) this.wrm8(res);
        else this.write8reg(this.eaReg, res);
      }
    } else {
      const rhs = toRm ? this.r[this.eaReg] : this.rm16();
      const lhs = toRm ? this.rm16() : this.r[this.eaReg];
      const res = this.alu16(n, lhs, rhs);
      if (n !== 7) {
        if (toRm) this.wrm16(res);
        else this.r[this.eaReg] = res;
      }
    }
  }

  private groupImm(op: number) {
    this.modrm();
    const n = this.eaReg;
    const word = op === 0x81 || op === 0x83;
    let imm: number;
    if (op === 0x81) imm = this.fetch16();
    else {
      imm = this.fetch8();
      if (op === 0x83 && imm & 0x80) imm -= 256;
    }
    if (!word) {
      const res = this.alu8(n, this.rm8(), imm & 0xff);
      if (n !== 7) this.wrm8(res);
    } else {
      const res = this.alu16(n, this.rm16(), imm & 0xffff);
      if (n !== 7) this.wrm16(res);
    }
  }

  private shift(width: 0 | 1, byCl: boolean) {
    this.modrm();
    const kind = this.eaReg;
    let count = byCl ? this.cl & 31 : 1;
    if (byCl && this.cl === 0) count = 0;
    const once = (v: number, bits: number) => {
      const sign = bits === 16 ? 0x8000 : 0x80;
      const mask = bits === 16 ? 0xffff : 0xff;
      if (kind === 0) {
        this.setFlag(CF, (v & sign) !== 0);
        v = (v << 1) & mask;
        if (v & 1) {
          /* rol fills bit 0 from old top, which is now CF */
        }
        v = (v & ~1) | (this.flag(CF) ? 1 : 0);
      } else if (kind === 1) {
        this.setFlag(CF, (v & 1) !== 0);
        v = (v >> 1) | (this.flag(CF) ? sign : 0);
      } else if (kind === 2) {
        const nc = (v & sign) !== 0;
        v = ((v << 1) & mask) | (this.flag(CF) ? 1 : 0);
        this.setFlag(CF, nc);
      } else if (kind === 3) {
        const nc = (v & 1) !== 0;
        v = (v >> 1) | (this.flag(CF) ? sign : 0);
        this.setFlag(CF, nc);
      } else if (kind === 4 || kind === 6) {
        this.setFlag(CF, (v & sign) !== 0);
        v = (v << 1) & mask;
      } else if (kind === 5) {
        this.setFlag(CF, (v & 1) !== 0);
        v = (v >> 1) & mask;
      } else {
        this.setFlag(CF, (v & 1) !== 0);
        v = (v >> 1) | (v & sign);
      }
      if (kind >= 4) {
        if (bits === 16) this.setSZP16(v);
        else this.setSZP8(v);
      }
      return v & mask;
    };
    let v = width ? this.rm16() : this.rm8();
    for (let i = 0; i < count; i++) v = once(v, width ? 16 : 8);
    if (width) this.wrm16(v);
    else this.wrm8(v);
  }

  private stringDelta(word: boolean): number {
    const n = word ? 2 : 1;
    return this.flag(DF) ? -n : n;
  }
  private doString(op: number) {
    const word = op === 0xa5 || op === 0xab;
    const n = this.rep ? this.cx : 1;
    for (let i = 0; i < n; i++) {
      if (op === 0xa4 || op === 0xa5) {
        const src = this.segOver >= 0 ? this.segOver : this.ds;
        if (word) this.write16(this.es, this.di, this.read16(src, this.si));
        else this.write8(this.es, this.di, this.read8(src, this.si));
        const d = this.stringDelta(word);
        this.si = (this.si + d) & 0xffff;
        this.di = (this.di + d) & 0xffff;
      } else if (op === 0xaa || op === 0xab) {
        if (word) this.write16(this.es, this.di, this.ax);
        else this.write8(this.es, this.di, this.al);
        this.di = (this.di + this.stringDelta(word)) & 0xffff;
      } else if (op === 0xac) {
        const src = this.segOver >= 0 ? this.segOver : this.ds;
        this.al = this.read8(src, this.si);
        this.si = (this.si + this.stringDelta(false)) & 0xffff;
      }
      if (this.rep) this.cx = (this.cx - 1) & 0xffff;
    }
  }

  private int16() {
    if (this.ah === 1) {
      if (this.host.keys.length === 0) this.setFlag(ZF, true);
      else {
        this.setFlag(ZF, false);
        this.ax = this.host.keys[0];
      }
      return;
    }
    if (this.ah !== 0) {
      this.fault = `int16 ah=${this.ah.toString(16)}`;
      return;
    }
    if (this.host.keys.length === 0) {
      this.ip = (this.ip - 2) & 0xffff;
      this.blocked = true;
      return;
    }
    this.ax = this.host.keys.shift() ?? 0;
  }

  private exec(op: number) {
    if (op < 0x40) {
      this.aluForm(op);
      return;
    }
    if (op >= 0x40 && op <= 0x47) {
      const i = op & 7;
      const c = this.flag(CF);
      this.r[i] = this.add16(this.r[i], 1);
      this.setFlag(CF, c);
      return;
    }
    if (op >= 0x48 && op <= 0x4f) {
      const i = op & 7;
      const c = this.flag(CF);
      this.r[i] = this.sub16(this.r[i], 1);
      this.setFlag(CF, c);
      return;
    }
    if (op >= 0x50 && op <= 0x57) return this.push(this.r[op & 7]);
    if (op >= 0x58 && op <= 0x5f) {
      this.r[op & 7] = this.pop();
      return;
    }
    if (op >= 0x70 && op <= 0x7f) {
      const cc = op & 15;
      const z = this.flag(ZF);
      const c = this.flag(CF);
      const s = this.flag(SF);
      const o = this.flag(OF);
      const cond = [
        o, !o, c, !c, z, !z, c || z, !c && !z, s, !s, this.flag(PF), !this.flag(PF),
        s !== o, s === o, z || s !== o, !z && s === o,
      ][cc];
      this.jshort(cond);
      return;
    }
    if (op >= 0x90 && op <= 0x97) {
      const i = op & 7;
      const t = this.ax;
      this.ax = this.r[i];
      this.r[i] = t;
      return;
    }
    if (op >= 0xb0 && op <= 0xb7) {
      this.write8reg(op & 7, this.fetch8());
      return;
    }
    if (op >= 0xb8 && op <= 0xbf) {
      this.r[op & 7] = this.fetch16();
      return;
    }
    switch (op) {
      case 0x80:
      case 0x81:
      case 0x82:
      case 0x83:
        this.groupImm(op);
        return;
      case 0x84:
      case 0x85: {
        const word = op === 0x85;
        this.modrm();
        if (word) this.logic16(this.rm16() & this.r[this.eaReg]);
        else this.logic8(this.rm8() & this.read8reg(this.eaReg));
        return;
      }
      case 0x86:
      case 0x87: {
        const word = op === 0x87;
        this.modrm();
        if (word) {
          const t = this.r[this.eaReg];
          this.r[this.eaReg] = this.rm16();
          this.wrm16(t);
        } else {
          const t = this.read8reg(this.eaReg);
          this.write8reg(this.eaReg, this.rm8());
          this.wrm8(t);
        }
        return;
      }
      case 0x88:
      case 0x89:
      case 0x8a:
      case 0x8b: {
        const word = (op & 1) === 1;
        const toRm = op < 0x8a;
        this.modrm();
        if (word) {
          if (toRm) this.wrm16(this.r[this.eaReg]);
          else this.r[this.eaReg] = this.rm16();
        } else if (toRm) this.wrm8(this.read8reg(this.eaReg));
        else this.write8reg(this.eaReg, this.rm8());
        return;
      }
      case 0x8c:
        this.modrm();
        this.wrm16(this.s[this.eaReg & 3]);
        return;
      case 0x8d:
        this.modrm();
        if (this.eaIsReg) {
          this.fault = "lea reg";
          return;
        }
        this.r[this.eaReg] = this.eaOff;
        return;
      case 0x8e:
        this.modrm();
        this.s[this.eaReg & 3] = this.rm16();
        return;
      case 0x98:
        this.ax = this.al & 0x80 ? this.al | 0xff00 : this.al;
        return;
      case 0x99:
        this.dx = this.ax & 0x8000 ? 0xffff : 0;
        return;
      case 0xa4:
      case 0xa5:
      case 0xaa:
      case 0xab:
      case 0xac:
        this.doString(op);
        return;
      case 0xc3:
        this.ip = this.pop();
        return;
      case 0xc6:
      case 0xc7: {
        const word = op === 0xc7;
        this.modrm();
        if (word) this.wrm16(this.fetch16());
        else this.wrm8(this.fetch8());
        return;
      }
      case 0xcd: {
        const n = this.fetch8();
        if (n === 0x16) this.int16();
        else this.fault = `int ${n.toString(16)}`;
        return;
      }
      case 0xd0:
      case 0xd1:
      case 0xd2:
      case 0xd3:
        this.shift(op & 1 ? 1 : 0, op >= 0xd2);
        return;
      case 0xe2: {
        this.cx = (this.cx - 1) & 0xffff;
        this.jshort(this.cx !== 0);
        return;
      }
      case 0xe8: {
        const rel = this.fetch16s();
        this.push(this.ip);
        this.ip = (this.ip + rel) & 0xffff;
        return;
      }
      case 0xe9: {
        const rel = this.fetch16s();
        this.ip = (this.ip + rel) & 0xffff;
        return;
      }
      case 0xeb:
        this.jshort(true);
        return;
      case 0xf4:
        this.halted = true;
        return;
      case 0xf5:
        this.setFlag(CF, !this.flag(CF));
        return;
      case 0xf6:
      case 0xf7:
        this.groupF(op === 0xf7);
        return;
      case 0xf8:
        this.setFlag(CF, false);
        return;
      case 0xf9:
        this.setFlag(CF, true);
        return;
      case 0xfc:
        this.setFlag(DF, false);
        return;
      case 0xfd:
        this.setFlag(DF, true);
        return;
      case 0xfe:
      case 0xff:
        this.groupInc(op === 0xff);
        return;
      default:
        this.fault = `opcode ${op.toString(16)} at ${(this.ip - 1).toString(16)}`;
    }
  }

  private jshort(cond: boolean) {
    const rel = this.fetch8s();
    if (cond) this.ip = (this.ip + rel) & 0xffff;
  }

  private groupInc(word: boolean) {
    this.modrm();
    const sub = this.eaReg;
    const c = this.flag(CF);
    if (sub === 0) {
      if (word) this.wrm16(this.add16(this.rm16(), 1));
      else this.wrm8(this.add8(this.rm8(), 1));
      this.setFlag(CF, c);
      return;
    }
    if (sub === 1) {
      if (word) this.wrm16(this.sub16(this.rm16(), 1));
      else this.wrm8(this.sub8(this.rm8(), 1));
      this.setFlag(CF, c);
      return;
    }
    this.fault = `ff/${sub}`;
  }

  private groupF(word: boolean) {
    this.modrm();
    const sub = this.eaReg;
    if (sub === 0) {
      const imm = word ? this.fetch16() : this.fetch8();
      if (word) this.logic16(this.rm16() & imm);
      else this.logic8(this.rm8() & imm);
      return;
    }
    if (sub === 2) {
      if (word) this.wrm16(this.rm16() ^ 0xffff);
      else this.wrm8(this.rm8() ^ 0xff);
      return;
    }
    if (sub === 3) {
      if (word) this.wrm16(this.sub16(0, this.rm16()));
      else this.wrm8(this.sub8(0, this.rm8()));
      return;
    }
    if (sub === 4 || sub === 5) {
      if (!word) {
        const a = this.al;
        const b = this.rm8();
        const p = sub === 5 ? (a << 24 >> 24) * (b << 24 >> 24) : a * b;
        this.ax = p & 0xffff;
        return;
      }
      const a = this.ax;
      const b = this.rm16();
      const p = sub === 5 ? (a << 16 >> 16) * (b << 16 >> 16) : a * b;
      const bits = p < 0 ? p + 0x100000000 : p;
      this.ax = bits & 0xffff;
      this.dx = Math.floor(bits / 65536) & 0xffff;
      return;
    }
    if (sub === 6) {
      if (!word) {
        const src = this.rm8();
        if (src === 0) {
          this.fault = "div0";
          return;
        }
        const q = Math.floor(this.ax / src);
        if (q > 0xff) {
          this.fault = "divo";
          return;
        }
        this.ah = this.ax % src;
        this.al = q;
        return;
      }
      const src = this.rm16();
      if (src === 0) {
        this.fault = "div0";
        return;
      }
      const dividend = this.dx * 0x10000 + this.ax;
      const q = Math.floor(dividend / src);
      if (q > 0xffff) {
        this.fault = "divo";
        return;
      }
      this.ax = q;
      this.dx = dividend % src;
      return;
    }
    this.fault = `f7/${sub}`;
  }

  step() {
    if (this.halted || this.fault) return;
    this.blocked = false;
    this.segOver = -1;
    this.rep = 0;
    for (;;) {
      const op = this.fetch8();
      if (op === 0x26) {
        this.segOver = this.es;
        continue;
      }
      if (op === 0x2e) {
        this.segOver = this.cs;
        continue;
      }
      if (op === 0x36) {
        this.segOver = this.ss;
        continue;
      }
      if (op === 0x3e) {
        this.segOver = this.ds;
        continue;
      }
      if (op === 0xf3) {
        this.rep = 1;
        continue;
      }
      if (op === 0xf2) {
        this.rep = 2;
        continue;
      }
      this.exec(op);
      break;
    }
    this.insns++;
  }

  run(budget: number): "ok" | "key" | "halt" | "fault" {
    let n = 0;
    while (n < budget) {
      if (this.halted) return "halt";
      if (this.fault) return "fault";
      this.step();
      n++;
      if (this.blocked) return "key";
      if (this.fault) return "fault";
      if (this.halted) return "halt";
    }
    return "ok";
  }
}