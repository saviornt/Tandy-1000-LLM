; TANDY-LM  --  all-in-one language machine for the 8088
; Every weight update below is real 8086. The web page is only the monitor.
;
; Model: 27 tokens (space + a-z), embedding dim 6, context of 3.
; h = E[t-3] + E[t-2] + 2*E[t-1]
; logits = (h * U) >> 4,  softmax by a 16-entry exp table.
; Train: one sign step on the batch gradient (cross entropy).
; Meta:  first-order MAML. Copy weights, inner sign-SGD on the support
;        set, then apply the query gradient to the untouched base weights.
;        No Hessian. An 8088 does not have the registers for one.

org 100h

V          equ 27
D          equ 6
EMBED_N    equ 162
CLAMP      equ 30
PRE_EPOCHS equ 8
INNER_STEPS equ 4
GEN_N      equ 28

jmp start

; ---------- text the machine was willing to keep ---------------------------

title_s   db " TANDY-LM  ALL-IN-ONE LANGUAGE MACHINE    8088   640KB   CGA", 0
rule_s    db "==============================================================================", 0
keys_s    db " 1 INGEST   2 TOKEN   3 TRAIN   4 MAML   5 INFER   6 ABOUT   R RESET", 0
spec_s    db " V27 D6 CTX3   INT16 SIGN-SGD   FIRST-ORDER MAML   NO 8087", 0
ready_s   db "READY", 0
ep_s      db " E", 0
tok_s     db " TOK ", 0
nll_s     db " NLL ", 0
acc_s     db " ACC ", 0

boot1 db "POST  8088 OK   RAM 640KB OK   NO 8087, FIXED POINT ONLY", 0
boot2 db "TANDY-LM 1.00   TOKENIZER + LM + FoMAML IN THIS ROM", 0
boot3 db "A 1200 BAUD MODEM IS WIRED TO COM1. IT WILL NOT FINISH.", 0
boot4 db "PRESS 1 TO INGEST, THEN 3 TO TRAIN, THEN 5 TO SPEAK.", 0

ing1 db "ATDT  THE PUBLIC NET", 0
ing2 db "CONNECT 1200   8N1   120 BYTES PER SECOND", 0
ing3 db "REMOTE OFFERS 250 TERABYTES OF INDEXED PUBLIC TEXT.", 0
ing4 db "THAT TRANSFER, AT THIS BAUD, RUNS", 0
ing5 db " YEARS.", 0
ing6 db "OR 200 ZETTABYTES, IF YOU MEAN EVERY STORED BYTE:", 0
ing7 db " YEARS. THE SUN DIES FIRST.", 0
ing8 db "CARRIER DROPPED. MOUNTED THE FLOPPY THAT FITS.", 0
ing9 db "CORPUS: TANDY JINGLE. TASKS: DOS, PHOENIX, HARDWARE.", 0

tok1 db "TOKENIZER  0=SPACE/OTHER  1=A ... 26=Z  CASE FOLDED", 0
tok2 db "RAW  ", 0
tok3 db "IDS  ", 0

trn1 db "PRETRAIN  AUTOREGRESSIVE SIGN-SGD. ESC ABORTS.", 0
trn2 db "PASS DONE.", 0
meta1 db "FoMAML  INNER STEPS ON SUPPORT, QUERY GRAD ON BASE.", 0
meta2 db "TASK ", 0
meta3 db "  QUERY NLL ", 0
meta4 db " -> ", 0
meta5 db "  ACC ", 0
meta6 db " OUTER SIGN STEP APPLIED.", 0

ask1 db "PROMPT, THEN ENTER. EMPTY MEANS TANDY.", 0
ask2 db "ADAPT INNER LOOP TO THAT PROMPT? Y/N", 0
ad1  db "ADAPTED. BASE WEIGHTS NOT TOUCHED.", 0
ad0  db "GENERATING FROM BASE WEIGHTS.", 0
g1   db "GREEDY ", 0
g2   db "SAMPLE ", 0
top1 db "TOP ", 0

ab1 db "THIS ROM IS THE MODEL. THE PAGE IS THE GLASS AND THE KEYS.", 0
ab2 db "IT CANNOT INGEST THE INTERNET. SEE THE BAUD MATH.", 0
ab3 db "324 INT16 WEIGHTS. CONTEXT THREE. RECENCY DOUBLES T-1.", 0
ab4 db "LOSS IS NEXT-TOKEN CROSS ENTROPY, IN NATS, FIXED POINT.", 0
ab5 db "FoMAML SKIPS THE HESSIAN. THAT IS THE 8088 VERSION.", 0
ab6 db "IF GREEDY SAYS RADIO SHACK, THE FLOPPY LEARNED.", 0
ab7 db "R REINITIALIZES WEIGHTS. TRAIN AGAIN FOR A LOWER NLL.", 0
rst db "WEIGHTS REINITIALIZED.", 0
abt db "ABORTED.", 0

pre_raw:
  times 3 db "tandy runs dos radio shack next token "
  db 0
dos_s_raw:
  times 4 db "dir type copy del cls ren "
  db 0
dos_q_raw:
  times 3 db "copy del cls dir type ren "
  db 0
geo_s_raw:
  times 4 db "phoenix mesa canal desert "
  db 0
geo_q_raw:
  times 3 db "mesa phoenix canal desert "
  db 0
hw_s_raw:
  times 3 db "floppy monitor cassette drive "
  db 0
hw_q_raw:
  times 2 db "monitor floppy cassette drive "
  db 0
name_dos db "DOS", 0
name_geo db "PHOENIX", 0
name_hw  db "HARDWARE", 0
demo_raw db "Tandy-LM", 0

explut dw 256, 94, 35, 13, 5, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0

nll_lut:
  dw 555,555,485,445,416,394,375,360,347,335,324,315,306,298,291,284
  dw 277,271,265,260,255,250,245,241,237,233,229,225,221,218,214,211
  dw 208,205,202,199,196,193,191,188,186,183,181,178,176,174,172,170
  dw 167,165,163,161,159,157,156,154,152,150,148,147,145,143,142,140
  dw 139,137,136,134,133,131,130,128,127,125,124,123,121,120,119,118
  dw 116,115,114,113,111,110,109,108,107,106,105,103,102,101,100,99
  dw 98,97,96,95,94,93,92,91,90,89,88,87,86,85,84,84
  dw 83,82,81,80,79,78,77,77,76,75,74,73,72,72,71,70
  dw 69,69,68,67,66,65,65,64,63,63,62,61,60,60,59,58
  dw 58,57,56,55,55,54,53,53,52,51,51,50,50,49,48,48
  dw 47,46,46,45,45,44,43,43,42,42,41,40,40,39,39,38
  dw 37,37,36,36,35,35,34,34,33,32,32,31,31,30,30,29
  dw 29,28,28,27,27,26,26,25,25,24,24,23,23,22,22,21
  dw 21,20,20,19,19,18,18,17,17,17,16,16,15,15,14,14
  dw 13,13,12,12,12,11,11,10,10,9,9,9,8,8,7,7
  dw 6,6,6,5,5,4,4,4,3,3,2,2,2,1,1,0
  dw 0

; ---------- mutable state ---------------------------------------------------

epoch    dw 0
shown    dw 0
last_nll dw 0
last_acc dw 0
before_n dw 0
before_a dw 0
abort    db 0
mode     db 0
do_grad  db 0
log_y    db 4
sample_m db 0
line_i   db 0
raw_n    db 0
dig_n    db 0
ctx0     db 0
ctx1     db 0
ctx2     db 0
target   db 0
span_ptr dw 0
span_len dw 0
span_i   dw 0
embed_ptr dw 0
out_ptr   dw 0
apply_e   dw 0
apply_u   dw 0
phase_ptr dw 0
sup_ptr  dw 0
sup_len  dw 0
qry_ptr  dw 0
qry_len  dw 0
inner_i  dw 0
gen_len  dw 0
gen_from dw 0
seed     dw 1
div_n    dw 0
exp_sum  dw 0
max_l    dw 0
acc_lo   dw 0
acc_hi   dw 0
dh_lo    dw 0
dh_hi    dw 0
prod_lo  dw 0
prod_hi  dw 0
g_tmp    dw 0
nll_sum  dw 0, 0
nll_n    dw 0
hit_n    dw 0
hidd     times 6 dw 0
logits   times 27 dw 0
exps     times 27 dw 0
probs    times 27 dw 0
linebuf  times 80 db 0
raw_line times 64 db 0
digs     times 24 db 0
scratch  times 8 dw 0
gen_tok  times 96 db 0
gen_sav  times 96 db 0
pre_tok  times 160 db 0
pre_len  dw 0
dos_sup  times 160 db 0
dos_sup_len dw 0
dos_qry  times 160 db 0
dos_qry_len dw 0
geo_sup  times 160 db 0
geo_sup_len dw 0
geo_qry  times 160 db 0
geo_qry_len dw 0
hw_sup   times 160 db 0
hw_sup_len dw 0
hw_qry   times 160 db 0
hw_qry_len dw 0
demo_tok times 16 db 0

embed    times 162 dw 0
outw     times 162 dw 0
embed_s  times 162 dw 0
outw_s   times 162 dw 0
grad_u   times 324 dw 0
grad_e   times 324 dw 0

bytes_text dw 40960, 43313, 58207, 0, 0, 0, 0, 0
bytes_all  dw 0, 60672, 49813, 1423, 10842, 0, 0, 0

; ---------- boot -------------------------------------------------------------

start:
  cld
  mov ax, ds
  mov es, ax
  call init_w
  call tokenize_all
  call cls
  call chrome
  mov si, boot1
  call logln
  mov si, boot2
  call logln
  mov si, boot3
  call logln
  mov si, boot4
  call logln
  jmp menu

menu:
  mov byte [mode], 0
  mov word [phase_ptr], ready_s
  mov word [shown], 0
  mov word [span_i], 0
  call paint_train
menu_w:
  call getkey
  cmp al, '1'
  jne m_2
  call do_ingest
  jmp menu
m_2:
  cmp al, '2'
  jne m_3
  call do_token
  jmp menu
m_3:
  cmp al, '3'
  jne m_4
  call do_pretrain
  jmp menu
m_4:
  cmp al, '4'
  jne m_5
  call do_maml
  jmp menu
m_5:
  cmp al, '5'
  jne m_6
  call do_infer
  jmp menu
m_6:
  cmp al, '6'
  jne m_r
  call do_about
  jmp menu
m_r:
  cmp al, 'r'
  jne m_R
  jmp do_reset
m_R:
  cmp al, 'R'
  jne m_fn
  jmp do_reset
m_fn:
  cmp al, 0
  jne menu_w
  cmp ah, 3Bh
  jne mf2
  call do_ingest
  jmp menu
mf2:
  cmp ah, 3Ch
  jne mf3
  call do_token
  jmp menu
mf3:
  cmp ah, 3Dh
  jne mf4
  call do_pretrain
  jmp menu
mf4:
  cmp ah, 3Eh
  jne mf5
  call do_maml
  jmp menu
mf5:
  cmp ah, 3Fh
  jne mf6
  call do_infer
  jmp menu
mf6:
  cmp ah, 40h
  jne menu_w
  call do_about
  jmp menu

do_reset:
  call init_w
  mov word [epoch], 0
  mov si, rst
  call logln
  jmp menu

; ---------- chrome / log -----------------------------------------------------

cls:
  push es
  mov ax, 0B800h
  mov es, ax
  xor di, di
  mov ax, 0A20h
  mov cx, 2000
  cld
  rep stosw
  pop es
  ret

; AL char, AH attr, BL row, BH col
vputch:
  push es
  push di
  push cx
  push dx
  mov cx, ax
  mov al, bl
  xor ah, ah
  mov dx, 80
  mul dx
  mov dl, bh
  xor dh, dh
  add ax, dx
  shl ax, 1
  mov di, ax
  mov ax, 0B800h
  mov es, ax
  mov ax, cx
  cld
  stosw
  pop dx
  pop cx
  pop di
  pop es
  ret

; SI string, AH attr, BL row, BH col
vputs:
  mov dh, ah
vp_l:
  mov al, [si]
  or al, al
  jz vp_d
  mov ah, dh
  call vputch
  inc si
  inc bh
  cmp bh, 80
  jb vp_l
vp_d:
  ret

; BL row, AH attr
row_clear:
  push cx
  mov dh, ah
  mov bh, 0
  mov cx, 80
rc_l:
  mov ah, dh
  mov al, ' '
  call vputch
  inc bh
  loop rc_l
  pop cx
  ret

chrome:
  mov bl, 0
  mov ah, 1Eh
  call row_clear
  mov si, title_s
  mov ah, 1Eh
  mov bl, 0
  mov bh, 0
  call vputs
  mov bl, 2
  mov ah, 08h
  call row_clear
  mov si, rule_s
  mov ah, 08h
  mov bl, 2
  mov bh, 0
  call vputs
  mov bl, 20
  mov ah, 08h
  call row_clear
  mov si, rule_s
  mov ah, 08h
  mov bl, 20
  mov bh, 0
  call vputs
  mov bl, 21
  mov ah, 07h
  call row_clear
  mov si, spec_s
  mov ah, 07h
  mov bl, 21
  mov bh, 0
  call vputs
  mov bl, 23
  mov ah, 0Eh
  call row_clear
  mov si, keys_s
  mov ah, 0Eh
  mov bl, 23
  mov bh, 0
  call vputs
  mov byte [log_y], 4
  ret

logln:
  mov bl, [log_y]
  mov bh, 1
  mov ah, 0Ah
  call vputs
  inc byte [log_y]
  cmp byte [log_y], 20
  jb log_ok
  call scroll_log
  mov byte [log_y], 19
log_ok:
  ret

scroll_log:
  push ds
  push es
  mov ax, 0B800h
  mov ds, ax
  mov es, ax
  cld
  mov si, 800
  mov di, 640
  mov cx, 1200
  rep movsw
  pop es
  pop ds
  mov bl, 19
  mov ah, 0Ah
  call row_clear
  ret

show_status:
  mov bl, 1
  mov ah, 0Eh
  call row_clear
  mov si, linebuf
  mov ah, 0Eh
  mov bl, 1
  mov bh, 1
  call vputs
  ret

show_prompt:
  mov bl, 22
  mov ah, 0Fh
  call row_clear
  mov si, linebuf
  mov ah, 0Fh
  mov bl, 22
  mov bh, 1
  call vputs
  ret

getkey:
  mov ah, 0
  int 16h
  ret

poll_esc:
  mov ah, 1
  int 16h
  jz pe_no
  mov ah, 0
  int 16h
  cmp al, 27
  jne pe_no
  mov byte [abort], 1
pe_no:
  ret

; ---------- number formatting ------------------------------------------------

buf_clr:
  push es
  push di
  push cx
  push ax
  mov byte [line_i], 0
  mov ax, ds
  mov es, ax
  xor ax, ax
  mov di, linebuf
  mov cx, 80
  cld
  rep stosb
  pop ax
  pop cx
  pop di
  pop es
  ret

buf_ch:
  push bx
  mov bl, [line_i]
  cmp bl, 76
  jae bc_x
  xor bh, bh
  mov [linebuf+bx], al
  inc byte [line_i]
bc_x:
  pop bx
  ret

buf_str:
bs_l:
  mov al, [si]
  or al, al
  jz bs_d
  call buf_ch
  inc si
  jmp bs_l
bs_d:
  ret

buf_u16:
  push ax
  push bx
  push cx
  push dx
  xor cx, cx
  mov bx, 10
bu_d:
  xor dx, dx
  div bx
  push dx
  inc cx
  or ax, ax
  jnz bu_d
bu_p:
  pop ax
  add al, '0'
  call buf_ch
  loop bu_p
  pop dx
  pop cx
  pop bx
  pop ax
  ret

buf_nll:
  push ax
  push bx
  push dx
  xor dx, dx
  mov bx, 100
  div bx
  call buf_u16
  push dx
  mov al, '.'
  call buf_ch
  pop ax
  xor dx, dx
  mov bx, 10
  div bx
  push dx
  add al, '0'
  call buf_ch
  pop ax
  add al, '0'
  call buf_ch
  pop dx
  pop bx
  pop ax
  ret

paint_train:
  call buf_clr
  mov si, [phase_ptr]
  call buf_str
  mov si, ep_s
  call buf_str
  mov ax, [shown]
  call buf_u16
  mov si, tok_s
  call buf_str
  mov ax, [span_i]
  call buf_u16
  mov si, nll_s
  call buf_str
  mov ax, [last_nll]
  call buf_nll
  mov si, acc_s
  call buf_str
  mov ax, [last_acc]
  call buf_u16
  mov al, '%'
  call buf_ch
  call show_status
  ret

; ---------- 128-bit ingest math ----------------------------------------------

; DI = limb 0, BX = divisor, DX = remainder
div128:
  push cx
  push si
  mov word [div_n], bx
  xor dx, dx
  mov cx, 8
d128:
  mov si, cx
  dec si
  shl si, 1
  mov bx, di
  mov ax, [bx+si]
  mov bx, [div_n]
  div bx
  mov bx, di
  mov [bx+si], ax
  loop d128
  mov bx, [div_n]
  pop si
  pop cx
  ret

scratch_zero:
  push si
  push cx
  mov si, scratch
  mov cx, 8
  xor ax, ax
sz_l:
  or ax, [si]
  add si, 2
  loop sz_l
  or ax, ax
  pop cx
  pop si
  ret

print_scratch:
  mov byte [dig_n], 0
ps0:
  call scratch_zero
  jz ps_out
  mov di, scratch
  mov bx, 10
  call div128
  mov bl, [dig_n]
  xor bh, bh
  mov [digs+bx], dl
  inc byte [dig_n]
  cmp byte [dig_n], 22
  jb ps0
ps_out:
  cmp byte [dig_n], 0
  jne ps_p
  mov al, '0'
  call buf_ch
  ret
ps_p:
  mov bl, [dig_n]
ps_l:
  dec bl
  xor bh, bh
  mov al, [digs+bx]
  add al, '0'
  call buf_ch
  or bl, bl
  jnz ps_l
  ret

copy_bytes:
  ; SI source limbs, copies 8 words to scratch
  push es
  mov ax, ds
  mov es, ax
  mov di, scratch
  mov cx, 8
  cld
  rep movsw
  pop es
  ret

years_into_line:
  mov di, scratch
  mov bx, 120
  call div128
  mov bx, 3600
  call div128
  mov bx, 24
  call div128
  mov bx, 365
  call div128
  call print_scratch
  ret

do_ingest:
  mov byte [mode], 1
  mov si, ing1
  call logln
  mov si, ing2
  call logln
  mov si, ing3
  call logln
  mov si, ing4
  call logln
  call buf_clr
  mov si, bytes_text
  call copy_bytes
  call years_into_line
  mov si, ing5
  call buf_str
  mov si, linebuf
  call logln
  mov si, ing6
  call logln
  call buf_clr
  mov si, bytes_all
  call copy_bytes
  call years_into_line
  mov si, ing7
  call buf_str
  mov si, linebuf
  call logln
  mov si, ing8
  call logln
  mov si, ing9
  call logln
  ret

; ---------- tokenizer --------------------------------------------------------

char_to_tok:
  cmp al, 'A'
  jb ct_1
  cmp al, 'Z'
  ja ct_1
  add al, 32
ct_1:
  cmp al, 'a'
  jb ct_0
  cmp al, 'z'
  ja ct_0
  sub al, 96
  ret
ct_0:
  xor al, al
  ret

; SI raw, DI dest, CX = length, cap 150
tok_copy:
  xor cx, cx
tc_l:
  mov al, [si]
  or al, al
  jz tc_d
  call char_to_tok
  mov [di], al
  inc si
  inc di
  inc cx
  cmp cx, 150
  jb tc_l
tc_d:
  ret

tokenize_all:
  mov si, pre_raw
  mov di, pre_tok
  call tok_copy
  mov [pre_len], cx
  mov si, dos_s_raw
  mov di, dos_sup
  call tok_copy
  mov [dos_sup_len], cx
  mov si, dos_q_raw
  mov di, dos_qry
  call tok_copy
  mov [dos_qry_len], cx
  mov si, geo_s_raw
  mov di, geo_sup
  call tok_copy
  mov [geo_sup_len], cx
  mov si, geo_q_raw
  mov di, geo_qry
  call tok_copy
  mov [geo_qry_len], cx
  mov si, hw_s_raw
  mov di, hw_sup
  call tok_copy
  mov [hw_sup_len], cx
  mov si, hw_q_raw
  mov di, hw_qry
  call tok_copy
  mov [hw_qry_len], cx
  ret

do_token:
  mov byte [mode], 2
  mov si, tok1
  call logln
  call buf_clr
  mov si, tok2
  call buf_str
  mov si, demo_raw
  call buf_str
  mov si, linebuf
  call logln
  mov si, demo_raw
  mov di, demo_tok
  call tok_copy
  call buf_clr
  mov si, tok3
  call buf_str
  mov di, demo_tok
  mov [span_i], cx
tok_show:
  mov al, [di]
  xor ah, ah
  call buf_u16
  mov al, ' '
  call buf_ch
  inc di
  dec word [span_i]
  cmp word [span_i], 0
  jne tok_show
  mov si, linebuf
  call logln
  ret

; ---------- weights ----------------------------------------------------------

init_w:
  xor si, si
  mov di, embed
iw1:
  cmp si, EMBED_N
  jb iw1b
  jmp iw2
iw1b:
  mov ax, si
  mov bx, 17
  mul bx
  add ax, 4
  xor dx, dx
  mov bx, 5
  div bx
  mov ax, dx
  sub ax, 2
  mov [di], ax
  add di, 2
  inc si
  jmp iw1
iw2:
  xor si, si
  mov di, outw
iw3:
  cmp si, EMBED_N
  jb iw3b
  jmp iw4
iw3b:
  mov ax, si
  mov bx, 13
  mul bx
  add ax, 1
  xor dx, dx
  mov bx, 5
  div bx
  mov ax, dx
  sub ax, 2
  mov [di], ax
  add di, 2
  inc si
  jmp iw3
iw4:
  call point_main
  ret

point_main:
  mov ax, embed
  mov [embed_ptr], ax
  mov [apply_e], ax
  mov ax, outw
  mov [out_ptr], ax
  mov [apply_u], ax
  ret

point_shadow:
  mov ax, embed_s
  mov [embed_ptr], ax
  mov [apply_e], ax
  mov ax, outw_s
  mov [out_ptr], ax
  mov [apply_u], ax
  ret

point_outer:
  mov ax, embed_s
  mov [embed_ptr], ax
  mov ax, embed
  mov [apply_e], ax
  mov ax, outw_s
  mov [out_ptr], ax
  mov ax, outw
  mov [apply_u], ax
  ret

copy_to_shadow:
  push es
  mov ax, ds
  mov es, ax
  cld
  mov si, embed
  mov di, embed_s
  mov cx, EMBED_N
  rep movsw
  mov si, outw
  mov di, outw_s
  mov cx, EMBED_N
  rep movsw
  pop es
  ret

zero_grads:
  push es
  push di
  mov ax, ds
  mov es, ax
  xor ax, ax
  mov di, grad_u
  mov cx, 648
  cld
  rep stosw
  pop di
  pop es
  ret

zero_metrics:
  xor ax, ax
  mov [nll_sum], ax
  mov [nll_sum+2], ax
  mov [nll_n], ax
  mov [hit_n], ax
  ret

finalize:
  mov bx, [nll_n]
  or bx, bx
  jnz fin1
  mov word [last_nll], 0
  mov word [last_acc], 0
  ret
fin1:
  mov ax, [nll_sum]
  mov dx, [nll_sum+2]
  div bx
  mov [last_nll], ax
  mov ax, [hit_n]
  mov bx, 100
  mul bx
  mov bx, [nll_n]
  xor dx, dx
  div bx
  mov [last_acc], ax
  ret

apply_sign:
  mov ax, [si+2]
  or ax, ax
  js as_neg
  jnz as_pos
  mov ax, [si]
  or ax, ax
  jnz as_pos
  jmp as_z
as_pos:
  mov ax, [di]
  inc ax
  cmp ax, CLAMP
  jle as_st
  mov ax, CLAMP
  jmp as_st
as_neg:
  mov ax, [di]
  dec ax
  cmp ax, -30
  jge as_st
  mov ax, -30
as_st:
  mov [di], ax
as_z:
  xor ax, ax
  mov [si], ax
  mov [si+2], ax
  ret

apply_all:
  mov si, grad_u
  mov di, [apply_u]
  mov cx, EMBED_N
aa1:
  call apply_sign
  add si, 4
  add di, 2
  loop aa1
  mov si, grad_e
  mov di, [apply_e]
  mov cx, EMBED_N
aa2:
  call apply_sign
  add si, 4
  add di, 2
  loop aa2
  ret

; ---------- forward ----------------------------------------------------------

; AL token, DI dim, BX accumulator
add_embed:
  push ax
  push cx
  push dx
  push si
  xor ah, ah
  mov cx, D
  mul cx
  add ax, di
  shl ax, 1
  mov si, [embed_ptr]
  add si, ax
  mov ax, [si]
  add bx, ax
  pop si
  pop dx
  pop cx
  pop ax
  ret

sar32_4:
  push cx
  mov cx, 4
s4:
  sar word [acc_hi], 1
  rcr word [acc_lo], 1
  loop s4
  pop cx
  mov ax, [acc_lo]
  ret

forward:
  xor di, di
fw_h:
  cmp di, D
  jb fw_hb
  jmp fw_v0
fw_hb:
  xor bx, bx
  mov al, [ctx0]
  call add_embed
  mov al, [ctx1]
  call add_embed
  mov al, [ctx2]
  call add_embed
  mov al, [ctx2]
  call add_embed
  mov ax, di
  shl ax, 1
  mov si, ax
  mov [hidd+si], bx
  inc di
  jmp fw_h
fw_v0:
  xor di, di
fw_v:
  cmp di, V
  jb fw_vb
  jmp fw_max
fw_vb:
  mov word [acc_lo], 0
  mov word [acc_hi], 0
  xor bp, bp
fw_d:
  cmp bp, D
  jb fw_db
  jmp fw_vs
fw_db:
  mov ax, bp
  mov cx, V
  mul cx
  add ax, di
  shl ax, 1
  mov si, [out_ptr]
  add si, ax
  mov bx, [si]
  mov ax, bp
  shl ax, 1
  mov si, ax
  mov ax, [hidd+si]
  imul bx
  add word [acc_lo], ax
  adc word [acc_hi], dx
  inc bp
  jmp fw_d
fw_vs:
  call sar32_4
  mov bx, di
  shl bx, 1
  mov [logits+bx], ax
  inc di
  jmp fw_v
fw_max:
  mov ax, [logits]
  mov cx, 26
  mov si, logits
fw_ml:
  add si, 2
  mov dx, [si]
  cmp dx, ax
  jle fw_mn
  mov ax, dx
fw_mn:
  loop fw_ml
  mov [max_l], ax
  xor bx, bx
  xor di, di
fw_ex:
  cmp di, V
  jb fw_exb
  jmp fw_pr0
fw_exb:
  mov ax, [max_l]
  mov si, di
  shl si, 1
  sub ax, [logits+si]
  cmp ax, 0
  jge fw_e1
  xor ax, ax
fw_e1:
  cmp ax, 15
  jle fw_e2
  mov ax, 15
fw_e2:
  shl ax, 1
  mov si, ax
  mov ax, [explut+si]
  mov si, di
  shl si, 1
  mov [exps+si], ax
  add bx, ax
  inc di
  jmp fw_ex
fw_pr0:
  mov [exp_sum], bx
  xor di, di
fw_pr:
  cmp di, V
  jb fw_prb
  ret
fw_prb:
  mov si, di
  shl si, 1
  mov cx, [exp_sum]
  or cx, cx
  jnz fw_pr1
  mov word [probs+si], 0
  jmp fw_prn
fw_pr1:
  mov ax, [exps+si]
  push cx
  mov cx, 256
  mul cx
  pop cx
  push cx
  shr cx, 1
  add ax, cx
  adc dx, 0
  pop cx
  div cx
  mov [probs+si], ax
fw_prn:
  inc di
  jmp fw_pr

; ---------- one training window ----------------------------------------------

accum_one:
  call forward
  xor ax, ax
  mov dx, [probs]
  mov di, 1
ac_arg:
  cmp di, V
  jb ac_ab
  jmp ac_ad
ac_ab:
  mov si, di
  shl si, 1
  mov cx, [probs+si]
  cmp cx, dx
  jle ac_an
  mov dx, cx
  mov ax, di
ac_an:
  inc di
  jmp ac_arg
ac_ad:
  mov cl, [target]
  xor ch, ch
  cmp ax, cx
  jne ac_miss
  inc word [hit_n]
ac_miss:
  mov bl, [target]
  xor bh, bh
  shl bx, 1
  mov ax, [probs+bx]
  cmp ax, 256
  jbe ac_nl
  mov ax, 256
ac_nl:
  shl ax, 1
  mov si, ax
  mov ax, [nll_lut+si]
  cwd
  add word [nll_sum], ax
  adc word [nll_sum+2], dx
  inc word [nll_n]
  cmp byte [do_grad], 0
  jne ac_g0
  ret
ac_g0:
  xor bp, bp
ac_gd:
  cmp bp, D
  jb ac_gdb
  ret
ac_gdb:
  mov word [dh_lo], 0
  mov word [dh_hi], 0
  xor di, di
ac_gv:
  cmp di, V
  jb ac_gvb
  jmp ac_ge
ac_gvb:
  mov si, di
  shl si, 1
  mov ax, [probs+si]
  mov cl, [target]
  xor ch, ch
  cmp di, cx
  jne ac_gg
  sub ax, 256
ac_gg:
  mov [g_tmp], ax
  mov ax, bp
  shl ax, 1
  mov si, ax
  mov ax, [hidd+si]
  mov bx, [g_tmp]
  imul bx
  mov [prod_lo], ax
  mov [prod_hi], dx
  mov ax, bp
  mov cx, V
  mul cx
  add ax, di
  shl ax, 1
  shl ax, 1
  add ax, grad_u
  mov si, ax
  mov ax, [prod_lo]
  mov dx, [prod_hi]
  add [si], ax
  adc [si+2], dx
  mov ax, bp
  mov cx, V
  mul cx
  add ax, di
  shl ax, 1
  mov si, [out_ptr]
  add si, ax
  mov bx, [si]
  mov ax, [g_tmp]
  imul bx
  add word [dh_lo], ax
  adc word [dh_hi], dx
  inc di
  jmp ac_gv
ac_ge:
  mov al, [ctx0]
  mov cl, 1
  call add_ge
  mov al, [ctx1]
  mov cl, 1
  call add_ge
  mov al, [ctx2]
  mov cl, 2
  call add_ge
  inc bp
  jmp ac_gd

; AL token, CL repeats, BP dim
add_ge:
  push ax
  push cx
  xor ah, ah
  mov dx, D
  mul dx
  add ax, bp
  shl ax, 1
  shl ax, 1
  add ax, grad_e
  mov di, ax
  mov ax, [dh_lo]
  mov dx, [dh_hi]
ag_l:
  add [di], ax
  adc [di+2], dx
  dec cl
  jnz ag_l
  pop cx
  pop ax
  ret

; SI tokens, CX length
run_span:
  cmp cx, 4
  jae rs0
  ret
rs0:
  mov [span_ptr], si
  mov [span_len], cx
  mov word [span_i], 3
rs_l:
  mov ax, [span_i]
  cmp ax, [span_len]
  jb rs_b
  ret
rs_b:
  mov si, [span_ptr]
  add si, ax
  mov al, [si]
  mov [target], al
  mov al, [si-1]
  mov [ctx2], al
  mov al, [si-2]
  mov [ctx1], al
  mov al, [si-3]
  mov [ctx0], al
  call accum_one
  mov ax, [span_i]
  and ax, 3
  jnz rs_np
  call finalize
  call paint_train
rs_np:
  call poll_esc
  cmp byte [abort], 1
  jne rs_c
  ret
rs_c:
  inc word [span_i]
  jmp rs_l

do_pretrain:
  mov byte [mode], 3
  mov byte [abort], 0
  mov si, trn1
  call logln
  mov word [phase_ptr], ready_s
  mov si, trn_phase
  mov [phase_ptr], si
  mov cx, PRE_EPOCHS
dp_e:
  cmp byte [abort], 1
  jne dp_b
  jmp dp_x
dp_b:
  mov [shown], cx
  call point_main
  call zero_metrics
  call zero_grads
  mov byte [do_grad], 1
  mov si, pre_tok
  push cx
  mov cx, [pre_len]
  call run_span
  call finalize
  call paint_train
  cmp byte [abort], 1
  jne dp_a
  pop cx
  jmp dp_x
dp_a:
  call apply_all
  pop cx
  inc word [epoch]
  loop dp_e
  mov si, trn2
  call logln
  jmp dp_y
dp_x:
  mov si, abt
  call logln
dp_y:
  call point_main
  ret

trn_phase db "TRAIN", 0

; ---------- FoMAML -----------------------------------------------------------

do_maml:
  mov byte [mode], 4
  mov byte [abort], 0
  mov si, meta1
  call logln
  mov ax, dos_sup
  mov [sup_ptr], ax
  mov ax, [dos_sup_len]
  mov [sup_len], ax
  mov ax, dos_qry
  mov [qry_ptr], ax
  mov ax, [dos_qry_len]
  mov [qry_len], ax
  mov si, name_dos
  call maml_one
  cmp byte [abort], 1
  je dm_x
  mov ax, geo_sup
  mov [sup_ptr], ax
  mov ax, [geo_sup_len]
  mov [sup_len], ax
  mov ax, geo_qry
  mov [qry_ptr], ax
  mov ax, [geo_qry_len]
  mov [qry_len], ax
  mov si, name_geo
  call maml_one
  cmp byte [abort], 1
  je dm_x
  mov ax, hw_sup
  mov [sup_ptr], ax
  mov ax, [hw_sup_len]
  mov [sup_len], ax
  mov ax, hw_qry
  mov [qry_ptr], ax
  mov ax, [hw_qry_len]
  mov [qry_len], ax
  mov si, name_hw
  call maml_one
  jmp dm_y
dm_x:
  mov si, abt
  call logln
dm_y:
  call point_main
  ret

; SI = task name
maml_one:
  mov [phase_ptr], si
  call copy_to_shadow
  call point_shadow
  mov byte [do_grad], 0
  call zero_metrics
  push si
  mov si, [qry_ptr]
  mov cx, [qry_len]
  mov word [shown], 0
  call run_span
  call finalize
  pop si
  mov ax, [last_nll]
  mov [before_n], ax
  mov ax, [last_acc]
  mov [before_a], ax
  mov word [inner_i], 0
mi_l:
  cmp byte [abort], 1
  je mi_x
  mov ax, [inner_i]
  cmp ax, INNER_STEPS
  jb mi_b
  jmp mi_q
mi_b:
  mov [shown], ax
  call point_shadow
  call zero_grads
  mov byte [do_grad], 1
  mov si, [sup_ptr]
  mov cx, [sup_len]
  call run_span
  cmp byte [abort], 1
  je mi_x
  call apply_all
  inc word [inner_i]
  jmp mi_l
mi_q:
  call point_shadow
  mov byte [do_grad], 0
  call zero_metrics
  mov si, [qry_ptr]
  mov cx, [qry_len]
  call run_span
  call finalize
  call report_task
  call point_outer
  call zero_grads
  mov byte [do_grad], 1
  mov si, [qry_ptr]
  mov cx, [qry_len]
  call run_span
  call apply_all
mi_x:
  ret

report_task:
  call buf_clr
  mov si, meta2
  call buf_str
  mov si, [phase_ptr]
  call buf_str
  mov si, meta3
  call buf_str
  mov ax, [before_n]
  call buf_nll
  mov si, meta4
  call buf_str
  mov ax, [last_nll]
  call buf_nll
  mov si, meta5
  call buf_str
  mov ax, [before_a]
  call buf_u16
  mov al, '%'
  call buf_ch
  mov si, meta4
  call buf_str
  mov ax, [last_acc]
  call buf_u16
  mov al, '%'
  call buf_ch
  mov si, linebuf
  call logln
  mov si, meta6
  call logln
  ret

; ---------- inference --------------------------------------------------------

do_infer:
  mov byte [mode], 5
  mov si, ask1
  call logln
  call read_prompt
  mov si, ask2
  call logln
  call getkey
  cmp al, 'y'
  je inf_y
  cmp al, 'Y'
  je inf_y
  jmp inf_n
inf_y:
  call adapt_prompt
  jmp inf_g
inf_n:
  mov si, ad0
  call logln
  call point_main
inf_g:
  call top3
  mov byte [sample_m], 0
  call generate
  call buf_clr
  mov si, g1
  call buf_str
  call detok_new
  mov si, linebuf
  call logln
  call restore_gen
  mov byte [sample_m], 1
  call generate
  call buf_clr
  mov si, g2
  call buf_str
  call detok_new
  mov si, linebuf
  call logln
  call point_main
  ret

adapt_prompt:
  mov si, ad1
  call logln
  call copy_to_shadow
  call point_shadow
  mov word [inner_i], 0
ap_l:
  mov ax, [inner_i]
  cmp ax, INNER_STEPS
  jb ap_b
  ret
ap_b:
  call zero_grads
  mov byte [do_grad], 1
  mov si, gen_tok
  mov cx, [gen_len]
  call run_span
  call apply_all
  inc word [inner_i]
  jmp ap_l

read_prompt:
  call buf_clr
  mov si, pmt
  call buf_str
  mov di, raw_line
  mov byte [raw_n], 0
rp_l:
  call show_prompt
  call getkey
  cmp al, 13
  jne rp_1
  jmp rp_d
rp_1:
  cmp al, 27
  jne rp_2
  jmp rp_d
rp_2:
  cmp al, 8
  jne rp_3
  cmp byte [raw_n], 0
  je rp_l
  dec byte [raw_n]
  dec di
  mov byte [di], 0
  dec byte [line_i]
  mov bl, [line_i]
  xor bh, bh
  mov byte [linebuf+bx], 0
  jmp rp_l
rp_3:
  cmp al, 32
  jb rp_l
  cmp byte [raw_n], 58
  jae rp_l
  mov [di], al
  inc di
  inc byte [raw_n]
  call buf_ch
  jmp rp_l
rp_d:
  mov byte [di], 0
  cmp byte [raw_n], 0
  jne rp_tok
  mov si, pmt_def
  mov di, raw_line
  call tok_raw_copy
rp_tok:
  mov si, raw_line
  mov di, gen_tok
  call tok_copy
  mov [gen_len], cx
  call pad3
  call save_gen
  ret

tok_raw_copy:
trc:
  mov al, [si]
  or al, al
  jz trc_d
  mov [di], al
  inc si
  inc di
  jmp trc
trc_d:
  mov byte [di], 0
  ret

pmt db "PROMPT> ", 0
pmt_def db "tandy", 0

pad3:
  cmp word [gen_len], 3
  jae pad_d
  mov si, gen_tok
  mov bx, [gen_len]
  add si, bx
pad_s:
  cmp si, gen_tok
  je pad0
  mov al, [si-1]
  mov [si], al
  dec si
  jmp pad_s
pad0:
  mov byte [gen_tok], 0
  inc word [gen_len]
  jmp pad3
pad_d:
  ret

save_gen:
  push es
  mov ax, ds
  mov es, ax
  mov si, gen_tok
  mov di, gen_sav
  mov cx, 96
  cld
  rep movsb
  mov ax, [gen_len]
  mov [gen_from], ax
  pop es
  ret

restore_gen:
  push es
  mov ax, ds
  mov es, ax
  mov si, gen_sav
  mov di, gen_tok
  mov cx, 96
  cld
  rep movsb
  mov ax, [gen_from]
  mov [gen_len], ax
  pop es
  ret

generate:
  mov cx, GEN_N
gn_l:
  push cx
  mov si, gen_tok
  mov ax, [gen_len]
  add si, ax
  mov al, [si-1]
  mov [ctx2], al
  mov al, [si-2]
  mov [ctx1], al
  mov al, [si-3]
  mov [ctx0], al
  call forward
  cmp byte [sample_m], 0
  jne gn_s
  call argmax
  jmp gn_w
gn_s:
  call sample_tok
gn_w:
  mov di, gen_tok
  add di, [gen_len]
  mov [di], al
  inc word [gen_len]
  pop cx
  loop gn_l
  ret

argmax:
  xor ax, ax
  mov dx, [probs]
  mov di, 1
am_l:
  cmp di, V
  jb am_b
  ret
am_b:
  mov si, di
  shl si, 1
  mov cx, [probs+si]
  cmp cx, dx
  jle am_n
  mov dx, cx
  mov ax, di
am_n:
  inc di
  jmp am_l

sample_tok:
  mov ax, [seed]
  mov bx, 75
  mul bx
  add ax, 74
  mov [seed], ax
  xor dx, dx
  mov bx, [exp_sum]
  or bx, bx
  jnz st1
  mov bx, 1
st1:
  div bx
  mov ax, dx
  xor di, di
st2:
  cmp di, V
  jb st2b
  xor ax, ax
  ret
st2b:
  mov si, di
  shl si, 1
  mov cx, [exps+si]
  cmp ax, cx
  jb st_hit
  sub ax, cx
  inc di
  jmp st2
st_hit:
  mov ax, di
  ret

detok_new:
  mov si, gen_tok
  mov cx, [gen_len]
dt_l:
  mov al, [si]
  or al, al
  jnz dt_c
  mov al, ' '
  jmp dt_p
dt_c:
  add al, 96
dt_p:
  call buf_ch
  inc si
  loop dt_l
  ret

top3:
  mov si, gen_tok
  mov ax, [gen_len]
  add si, ax
  mov al, [si-1]
  mov [ctx2], al
  mov al, [si-2]
  mov [ctx1], al
  mov al, [si-3]
  mov [ctx0], al
  call forward
  call buf_clr
  mov si, top1
  call buf_str
  mov byte [raw_n], 0
t3_o:
  cmp byte [raw_n], 3
  jb t3_ob
  jmp t3_d
t3_ob:
  xor ax, ax
  xor dx, dx
  xor di, di
t3_s:
  cmp di, V
  jb t3_sb
  jmp t3_p
t3_sb:
  mov si, di
  shl si, 1
  mov cx, [probs+si]
  cmp cx, dx
  jbe t3_n
  mov dx, cx
  mov ax, di
t3_n:
  inc di
  jmp t3_s
t3_p:
  mov di, ax
  shl di, 1
  mov word [probs+di], 0
  or ax, ax
  jnz t3_ch
  mov al, '_'
  jmp t3_w
t3_ch:
  add al, 96
t3_w:
  call buf_ch
  mov al, ' '
  call buf_ch
  mov ax, dx
  mov bx, 100
  mul bx
  mov bx, 256
  xor dx, dx
  div bx
  call buf_u16
  mov al, '%'
  call buf_ch
  mov al, ' '
  call buf_ch
  inc byte [raw_n]
  jmp t3_o
t3_d:
  mov si, linebuf
  call logln
  ret

do_about:
  mov byte [mode], 6
  mov si, ab1
  call logln
  mov si, ab2
  call logln
  mov si, ab3
  call logln
  mov si, ab4
  call logln
  mov si, ab5
  call logln
  mov si, ab6
  call logln
  mov si, ab7
  call logln
  ret