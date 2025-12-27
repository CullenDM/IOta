OUTPUT_ARCH(riscv)
ENTRY(_start)

KERNEL_BASE = 0x80200000;

SECTIONS
{
    . = KERNEL_BASE;

    .text : ALIGN(4K) {
        *(.text .text.*)
    }

    .rodata : ALIGN(4K) {
        *(.rodata .rodata.*)
    }

    .data : ALIGN(4K) {
        *(.sdata .sdata.*)
        *(.data .data.*)
        PROVIDE(__global_pointer$ = . + 0x800);
    }

    .bss : ALIGN(4K) {
        __bss_start = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    }
}
