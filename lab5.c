/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"

#include "xparameters.h"
#include "xgpio.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_printf.h"

// Parameter definitions
#define INTC_DEVICE_ID 		XPAR_PS7_SCUGIC_0_DEVICE_ID
#define SWITCH_DEVICE_ID		XPAR_AXI_GPIO_0_DEVICE_ID
#define INTC_GPIO_INTERRUPT_ID XPAR_FABRIC_AXI_GPIO_0_IP2INTC_IRPT_INTR
#define SWITCH_CHANNEL	 	1					/* Channel 1 of the GPIO Device */
#define LED_CHANNEL	 		2					/* Channel 2 of the GPIO Device */
#define SWITCH_INT 			XGPIO_IR_CH1_MASK

/*
* Global variables
*/
XGpio GPIOInst;
XScuGic INTCInst;
int *count28_pointer = (int *) XPAR_COUNTER28_0_S00_AXI_BASEADDR; /* Pointer to access the 28-bit counter software register */
int InterruptFlag; /* Flag used to indicate that an interrupt has occurred */
unsigned int counter; /* Counts the number of rising edges produced by SW0 */
static int switch_value;

//----------------------------------------------------
// PROTOTYPE FUNCTIONS
//----------------------------------------------------
static void Switch_Intr_Handler(void *baseaddr_p);
static int InterruptSystemSetup(XScuGic *XScuGicInstancePtr);
static int IntcInitFunction(u16 DeviceId, XGpio *GpioInstancePtr);

//----------------------------------------------------
// INTERRUPT HANDLER FUNCTIONS

void Switch_Intr_Handler(void *InstancePtr) {
	// Disable GPIO interrupts
	XGpio_InterruptDisable(&GPIOInst, SWITCH_INT);
	// Ignore additional button presses
	if ((XGpio_InterruptGetStatus(&GPIOInst) & SWITCH_INT) != SWITCH_INT) {
		return;
	}

	/* Sets the interrupt flag */
	InterruptFlag = 1;

	(void) XGpio_InterruptClear(&GPIOInst, SWITCH_INT);
	// Enable GPIO interrupts
	XGpio_InterruptEnable(&GPIOInst, SWITCH_INT);
}

//----------------------------------------------------
// INITIAL SETUP FUNCTIONS
//----------------------------------------------------

int InterruptSystemSetup(XScuGic *XScuGicInstancePtr) {
	// Enable interrupt
	XGpio_InterruptEnable(&GPIOInst, SWITCH_INT);
	XGpio_InterruptGlobalEnable(&GPIOInst);

	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
			(Xil_ExceptionHandler) XScuGic_InterruptHandler,
			XScuGicInstancePtr);
	Xil_ExceptionEnable();

	return XST_SUCCESS;

}

int IntcInitFunction(u16 DeviceId, XGpio *GpioInstancePtr) {
	XScuGic_Config *IntcConfig;
	int status;

	// Interrupt controller initialisation
	IntcConfig = XScuGic_LookupConfig(DeviceId);
	status = XScuGic_CfgInitialize(&INTCInst, IntcConfig,
			IntcConfig->CpuBaseAddress);
	if (status != XST_SUCCESS)
		return XST_FAILURE;

	// Call to interrupt setup
	status = InterruptSystemSetup(&INTCInst);
	if (status != XST_SUCCESS)
		return XST_FAILURE;

	// Connect GPIO interrupt to handler
	status = XScuGic_Connect(&INTCInst, INTC_GPIO_INTERRUPT_ID,
			(Xil_ExceptionHandler) Switch_Intr_Handler, (void *) GpioInstancePtr);
	if (status != XST_SUCCESS)
		return XST_FAILURE;

	// Enable GPIO interrupts interrupt
	XGpio_InterruptEnable(GpioInstancePtr, 1);
	XGpio_InterruptGlobalEnable(GpioInstancePtr);

	// Enable GPIO and timer interrupts in the controller
	XScuGic_Enable(&INTCInst, INTC_GPIO_INTERRUPT_ID);

	return XST_SUCCESS;
}

int main()
{

	int status;
	int new_data;
	int old_data;

	/* Variable initialisation */
	InterruptFlag = 0;
	counter = 0;

    init_platform();

	// Initialise GPIO
	status = XGpio_Initialize(&GPIOInst, SWITCH_DEVICE_ID);
	if (status != XST_SUCCESS)
		return XST_FAILURE;

	// Config GPIO channel 1 as input
	XGpio_SetDataDirection(&GPIOInst, SWITCH_CHANNEL, 0xFF);

	// Config GPIO channel 2 as output
	XGpio_SetDataDirection(&GPIOInst, LED_CHANNEL, 0x00);

	// Initialize interrupt controller
	status = IntcInitFunction(INTC_DEVICE_ID, &GPIOInst);
	if (status != XST_SUCCESS)
		return XST_FAILURE;

	*count28_pointer = 1; // Enables the 28-bit counter
	/* Prints the wellcome mesage */
	printf("##### Application Starts #####\n\r");
	printf("\r\n");
	// Reads initial value of the SWITCH
	new_data = XGpio_DiscreteRead(&GPIOInst, SWITCH_CHANNEL);
	old_data = new_data;
	while (1) {
		/* Test for an interrupt produced by GPIO*/
		if (InterruptFlag == 1)
		{
			InterruptFlag = 0; // resets the interrupt flag
			new_data = XGpio_DiscreteRead(&GPIOInst, SWITCH_CHANNEL);
			/* Rising edge detection*/
			if ((new_data == 1) && (old_data == 0))
			{
				printf("##### Rising edge on switch detected #####\n\r");
				printf("\r\n");
				counter++;
				if (counter == 4)
					counter = 0;
				/* Prints the current value of the counter*/
				printf("Counter = %d\n\r", counter);
				printf("\r\n");
			}
			old_data = new_data;
		}
		/* Displays the value of the counter on LED7 and LED6*/
		XGpio_DiscreteWrite(&GPIOInst, LED_CHANNEL, counter);
		/* Enables or disables the 28-bit counter depending on internal counter variable*/
		if (counter == 0)
			*count28_pointer = 1;
		else
		    *count28_pointer = 0;
	}

    cleanup_platform();
    return 0;
}