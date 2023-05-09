               .equ      EDGE_TRIGGERED,    0x1
               .equ      LEVEL_SENSITIVE,   0x0
               .equ      CPU0,              0x01    // bit-mask; bit 0 represents cpu0
               .equ      ENABLE,            0x1

               .equ      KEY0,              0b0001
               .equ      KEY1,              0b0010
               .equ      KEY2,              0b0100
               .equ      KEY3,              0b1000

               .equ      IRQ_MODE,          0b10010
               .equ      SVC_MODE,          0b10011

               .equ      INT_ENABLE,        0b01000000
               .equ      INT_DISABLE,       0b11000000

/*********************************************************************************
 * Initialize the exception vector table
 ********************************************************************************/
                .section .vectors, "ax"

                B        _start             // reset vector
                .word    0                  // undefined instruction vector
                .word    0                  // software interrrupt vector
                .word    0                  // aborted prefetch vector
                .word    0                  // aborted data vector
                .word    0                  // unused vector
                B        IRQ_HANDLER        // IRQ interrupt vector
                .word    0                  // FIQ interrupt vector

/* ********************************************************************************
 * This program demonstrates use of interrupts with assembly code. The program 
 * responds to interrupts from a timer and the pushbutton KEYs in the FPGA.
 *
 * The interrupt service routine for the timer increments a counter that is shown
 * on the red lights LEDR by the main program. The counter can be stopped/run by 
 * pressing any of the KEYs.
 ********************************************************************************/
                .text
                .global  _start
_start:                                         
				/* Set up stack pointers for IRQ and SVC processor modes */
                MOV      R1, #0b11010010         // interrupts masked/disabled, MODE = IRQ
												 // I-bit & F-bit disabled, T-bit always to be 0
				MSR      CPSR_c, R1              // change to IRQ mode (10010)
                LDR      SP, =0x40000            // set up the IRQ mode stack pointer
				
				/* Change back to SVC (supervisor) mode with interrupts diabled */
				MOV      R1, #0b11010011         // interrupts masked/disabled, MODE = SVC 
				MSR      CPSR_c, R1              // change to supervisor mode (10011)
				LDR      SP, =0x20000            // set up the SVC mode stack pointer

                BL       CONFIG_GIC              // configure the ARM generic
                                                 // interrupt controller
                BL       CONFIG_PRIV_TIMER       // configure A9 Private Timer
                BL       CONFIG_KEYS             // configure the pushbutton KEYs port

				/* Enable IRQ interrupts in the ARM processor */
                MOV      R0, #0b01010011         // IRQ unmasked/enabled, MODE = SVC
				MSR      CPSR_c, R0              // change to supervisor mode (10011)
				  
                LDR      R5, =0xFF200000         // LEDR base address
				
LOOP:                                          
                LDR      R3, COUNT               // global variable
                STR      R3, [R5]                // write to the LEDR lights
                B        LOOP                

/* Global variables */
                .global  COUNT
COUNT:          .word    0x0                     // used by timer
                .global  RUN
RUN:            .word    0x1                     // initial value to increment COUNT


/* Configure the A9 Private Timer to create interrupts at 0.25 second intervals */
CONFIG_PRIV_TIMER:                             
                LDR      R0, =0xFFFEC600         // base address of A9 Private Timer
				
				LDR      R1, =50000000	         // counter will be loaded with 500000 -> setting to 0.25 sec count down
                STR      R1, [R0]                // load the timer value - Load Register
				
				MOV      R2, #0x7                // enables interrupt and auto-refill of the timer
				STR      R2, [R0, #0x8]          // load the control status - Control Register
				
				MOV      PC, LR
                   
/* Configure the pushbutton KEYS to generate interrupts */
CONFIG_KEYS:                                    
                LDR      R0, =0xFF200050         // pushbutton KEY 3~0 base address
				
				MOV      R1, #0xF                // set interrupt mask bits to (1111)
				         						 // to allow/have KEY 0~3 cause an interrupt 
												 // when it is pressed & released
				STR      R1, [R0, #0x8]			 // interrupt mask register is (base + 8)
                
				MOV      PC, LR


/*--- IRQ HANDLER-------------------------------------------------------------*/
IRQ_HANDLER:    /* Push to store all the original values for the registers */
                PUSH     {R0-R7, LR}
				/* Read the ICCIAR in the CPU interface in the GIC */
                LDR      R4, =0xFFFEC100         // the interrupt acknowledge register
                LDR      R5, [R4, #0x0C]         // read the interrupt ID

CHECK_KEYS:	    CMP      R5, #73                 // check if the KEYs 3~0 caused interrupt
				BNE      CHECK_TIMER
				BL       KEY_ISR
				B        EXIT_IRQ

CHECK_TIMER:    CMP      R5, #29                 // check if the Private A9 Timer caused interrupt
				BNE      STOP           
				BL       PRIV_TIMER_ISR
				B        EXIT_IRQ

STOP:           B        STOP                    // if not recognized, stop here
				
EXIT_IRQ:		/* Write to the End of Interrupt Register (ICCEOIR) */
                STR      R5, [R4, #0x10]         // 0x10 = 16 = 1 0000
				POP      {R0-R7, LR}
                SUBS     PC, LR, #4

/****************************************************************************************
 * Pushbutton - Interrupt Service Routine (ISR) - updated for part 3
 *               
 * This routine toggles the RUN global variable.
 ***************************************************************************************/
                .global  KEY_ISR
KEY_ISR:		
                /* Clear the edge capture register values */
				LDR      R2, =0xFF200050         // base address of pushbutton KEY port
				LDR      R1, [R2, #0xC]          // load the edge capture register for KEY 3~0
                
				MOV      R3, R1                  // stores R1 into R3; now R3 is the edge status at this turn
				
				STR      R1, [R2, #0xC]          // reset the edge capture register

				// stopping the timer
				LDR      R2, =0xFFFEC600         // base address of A9 Private Timer
				MOV      R0, #0b000              // stop the timer and disable its functionality
				STR      R0, [R2, #0x8]

KEY_0:			// KEY 0: toggles the value of RUN
				MOV      R1, #0b0001
				AND      R1, R3                  // isolate the 1st bit
				CMP      R1, #0b0001
				BNE      KEY_1
				
				LDR      R1, RUN
				EOR      R1, #1                   // toggle by EORing with #1
				STR      R1, RUN
				
				B        KEY_BACK
				
KEY_1:			// KEY 1: doubles the rate which COUNT is incremented 
				MOV      R1, #0b0010
				AND      R1, R3                  // isolate the 2nd bit
				CMP      R1, #0b0010
				BNE      KEY_2
				
				LDR      R1, [R2]    	         // counter will be halved
				LSR      R1, #1                  // LSR to halve the counter by 2
				STR      R1, [R2]
				
				B        KEY_BACK
				
KEY_2:	 		// KEY 2: halved the rate which Count is incremented
				MOV      R1, #0b0100
				AND      R1, R3                  // isolate the 3rd bit
				CMP      R1, #0b0100
				BNE      KEY_BACK
				
				LDR      R1, [R2]    	         // counter will be doubled
				LSL      R1, #1                  // LSL to multiply the value by 2
				STR      R1, [R2]
				
				B        KEY_BACK
				

KEY_BACK:       MOV      R0, #0b0111             // enables interrupt and auto-refill of the timer
				STR      R0, [R2, #0x8]          // load the control status - Control Register
				MOV      PC, LR

/******************************************************************************
 * A9 Private Timer - Interrupt Service Routine (ISR)
 *                                                                          
 * This code toggles performs the operation COUNT = COUNT + RUN
 *****************************************************************************/
                .global    TIMER_ISR
PRIV_TIMER_ISR:
                
GO:				
                LDR      R0, =0xFFFEC600
                LDR      R1, [R0, #0xC]
                MOV      R2, #1
                STR      R2, [R0, #0xC]       // clear interrupt
                
                LDR      R0, #RUN
                LDR      R1, #COUNT
                ADD      R1,R0
                STR      R1, #COUNT
				
TIMER_BACK:     MOV      PC, LR
 
/* 
 * Configure the Generic Interrupt Controller (GIC)
*/
                .global  CONFIG_GIC
CONFIG_GIC:
                PUSH     {LR}
                MOV      R0, #29
                MOV      R1, #CPU0
                BL       CONFIG_INTERRUPT
                
                /* Enable the KEYs interrupts */
                MOV      R0, #73
                MOV      R1, #CPU0
                /* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
                BL       CONFIG_INTERRUPT

                /* configure the GIC CPU interface */
                LDR      R0, =0xFFFEC100        // base address of CPU interface
                /* Set Interrupt Priority Mask Register (ICCPMR) */
                LDR      R1, =0xFFFF            // enable interrupts of all priorities levels
                STR      R1, [R0, #0x04]
                /* Set the enable bit in the CPU Interface Control Register (ICCICR). This bit
                 * allows interrupts to be forwarded to the CPU(s) */
                MOV      R1, #1
                STR      R1, [R0]
    
                /* Set the enable bit in the Distributor Control Register (ICDDCR). This bit
                 * allows the distributor to forward interrupts to the CPU interface(s) */
                LDR      R0, =0xFFFED000
                STR      R1, [R0]    
    
                POP      {PC}
/* 
 * Configure registers in the GIC for an individual interrupt ID
 * We configure only the Interrupt Set Enable Registers (ICDISERn) and Interrupt 
 * Processor Target Registers (ICDIPTRn). The default (reset) values are used for 
 * other registers in the GIC
 * Arguments: R0 = interrupt ID, N
 *            R1 = CPU target
*/
CONFIG_INTERRUPT:
                PUSH     {R4-R5, LR}
    
                /* Configure Interrupt Set-Enable Registers (ICDISERn). 
                 * reg_offset = (integer_div(N / 32) * 4
                 * value = 1 << (N mod 32) */
                LSR      R4, R0, #3               // calculate reg_offset
                BIC      R4, R4, #3               // R4 = reg_offset
                LDR      R2, =0xFFFED100
                ADD      R4, R2, R4               // R4 = address of ICDISER
    
                AND      R2, R0, #0x1F            // N mod 32
                MOV      R5, #1                   // enable
                LSL      R2, R5, R2               // R2 = value

                /* now that we have the register address (R4) and value (R2), we need to set the
                 * correct bit in the GIC register */
                LDR      R3, [R4]                 // read current register value
                ORR      R3, R3, R2               // set the enable bit
                STR      R3, [R4]                 // store the new register value

                /* Configure Interrupt Processor Targets Register (ICDIPTRn)
                  * reg_offset = integer_div(N / 4) * 4
                  * index = N mod 4 */
                BIC      R4, R0, #3               // R4 = reg_offset
                LDR      R2, =0xFFFED800
                ADD      R4, R2, R4               // R4 = word address of ICDIPTR
                AND      R2, R0, #0x3             // N mod 4
                ADD      R4, R2, R4               // R4 = byte address in ICDIPTR

                /* now that we have the register address (R4) and value (R2), write to (only)
                 * the appropriate byte */
                STRB     R1, [R4]
    
                POP      {R4-R5, PC}
                .end   
