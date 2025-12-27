.section .text
.globl _start
_start:
    la gp, __global_pointer$
    la sp, boot_stack_top
    call clear_bss
    call kmain
1:
    wfi
    j 1b

.section .bss
.align 16
.globl boot_stack
boot_stack:
    .space 16384
.globl boot_stack_top
boot_stack_top:
