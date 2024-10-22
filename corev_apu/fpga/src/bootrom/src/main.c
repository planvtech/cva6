// Copyright OpenHW Group contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "uart.h"
#include "spi.h"
#include "sd.h"
#include "gpt.h"

int main()
{
    #ifndef PLAT_AGILEX

    init_uart(CLOCK_FREQUENCY, UART_BITRATE); //removed in intel setup
    spi_init(); //removed in intel setup
    
    #endif 

    print_uart("Hello World!\r\n"); 

    #ifndef PLAT_AGILEX

    int res = gpt_find_boot_partition((uint8_t *)0x80000000UL, 2 * 16384); //removed in intel setup

    if (res == 0)
    {
        // jump to the address
        __asm__ volatile(
            "li s0, 0x80000000;"
            "la a1, _dtb;"
            "jr s0");
    }

    #endif
    while (1)
    {
        // do nothing
    }
}

void handle_trap(void)
{
    // print_uart("trap\r\n");
}
