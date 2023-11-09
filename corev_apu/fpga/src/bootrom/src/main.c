#include "uart.h"
#include "spi.h"
#include "sd.h"
#include "gpt.h"

int main()
{
    #define UART_FREQ      40000000
    #define UART_BAUD_RATE 115200

    init_uart(UART_FREQ, UART_BAUD_RATE);
    print_uart("Hello World!\r\n");

    int res = gpt_find_boot_partition((uint8_t *)0x80000000UL, 2 * 16384);

    return 0;
}

void handle_trap(void)
{
    // print_uart("trap\r\n");
}
