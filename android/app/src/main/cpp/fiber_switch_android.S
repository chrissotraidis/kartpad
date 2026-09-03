.text
.p2align 2

.global KartPadSwitchAndroidFiber
.hidden KartPadSwitchAndroidFiber
.type KartPadSwitchAndroidFiber, %function
KartPadSwitchAndroidFiber:
  stp x19, x20, [x0, #0]
  stp x21, x22, [x0, #16]
  stp x23, x24, [x0, #32]
  stp x25, x26, [x0, #48]
  stp x27, x28, [x0, #64]
  stp x29, x30, [x0, #80]
  mov x9, sp
  str x9, [x0, #96]
  mrs x9, fpcr
  mrs x10, fpsr
  stp x9, x10, [x0, #104]
  stp d8, d9, [x0, #128]
  stp d10, d11, [x0, #144]
  stp d12, d13, [x0, #160]
  stp d14, d15, [x0, #176]

  ldp x19, x20, [x1, #0]
  ldp x21, x22, [x1, #16]
  ldp x23, x24, [x1, #32]
  ldp x25, x26, [x1, #48]
  ldp x27, x28, [x1, #64]
  ldp x29, x30, [x1, #80]
  ldr x9, [x1, #96]
  mov sp, x9
  ldp x9, x10, [x1, #104]
  msr fpcr, x9
  msr fpsr, x10
  ldp d8, d9, [x1, #128]
  ldp d10, d11, [x1, #144]
  ldp d12, d13, [x1, #160]
  ldp d14, d15, [x1, #176]
  mov x0, x19
  ret
.size KartPadSwitchAndroidFiber, .-KartPadSwitchAndroidFiber

.macro check_x register, offset, code
  ldr x9, [x19, #\offset]
  cmp \register, x9
  b.ne .Lfiber_fail_\code
.endm

.macro check_d register, offset, code
  ldr x9, [x19, #\offset]
  fmov x10, \register
  cmp x10, x9
  b.ne .Lfiber_fail_\code
.endm

.global KartPadAndroidRegisterFiberEntry
.hidden KartPadAndroidRegisterFiberEntry
.type KartPadAndroidRegisterFiberEntry, %function
KartPadAndroidRegisterFiberEntry:
.Lfiber_loop:
  check_x x20, 48, 20
  check_x x21, 56, 21
  check_x x22, 64, 22
  check_x x23, 72, 23
  check_x x24, 80, 24
  check_x x25, 88, 25
  check_x x26, 96, 26
  check_x x27, 104, 27
  check_x x28, 112, 28
  check_d d8, 120, 8
  check_d d9, 128, 9
  check_d d10, 136, 10
  check_d d11, 144, 11
  check_d d12, 152, 12
  check_d d13, 160, 13
  check_d d14, 168, 14
  check_d d15, 176, 15
  mrs x10, fpcr
  ldr x9, [x19, #184]
  cmp x10, x9
  b.ne .Lfiber_fail_30
  mrs x10, fpsr
  ldr x9, [x19, #192]
  cmp x10, x9
  b.ne .Lfiber_fail_31
  ldr x9, [x19, #200]
  cmp x29, x9
  b.ne .Lfiber_fail_29

  ldr x9, [x19, #16]
  cbz x9, .Lfiber_finished
  sub x9, x9, #1
  str x9, [x19, #16]
  ldr x10, [x19, #24]
  add x10, x10, #1
  str x10, [x19, #24]
  ldp x0, x1, [x19, #0]
  bl KartPadSwitchAndroidFiber
  b .Lfiber_loop

.macro failure_label code
.Lfiber_fail_\code:
  mov x9, #\code
  str x9, [x19, #32]
  b .Lfiber_finished
.endm

  failure_label 8
  failure_label 9
  failure_label 10
  failure_label 11
  failure_label 12
  failure_label 13
  failure_label 14
  failure_label 15
  failure_label 20
  failure_label 21
  failure_label 22
  failure_label 23
  failure_label 24
  failure_label 25
  failure_label 26
  failure_label 27
  failure_label 28
  failure_label 29
  failure_label 30
  failure_label 31

.Lfiber_finished:
  mov x9, #1
  str x9, [x19, #40]
  ldp x0, x1, [x19, #0]
  bl KartPadSwitchAndroidFiber
  brk #0
.size KartPadAndroidRegisterFiberEntry, .-KartPadAndroidRegisterFiberEntry

.section .note.GNU-stack,"",%progbits
