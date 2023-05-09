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
               .equ      INT_DISABLE,       0b1100000

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

/*********************************************************************************
 * Main program
 ********************************************************************************/
                .text
                .global  _start
_start:        
                // 1. Enable Interrputs in the processor
				/* Set up stack pointers for IRQ and SVC processor modes */
                MOV      R1, #0b11010010         // interrupts masked/disabled, MODE = IRQ
												 // I-bit & F-bit disabled, T-bit always to be 0
				MSR      CPSR_c, R1              // change to IRQ mode (10010)
                LDR      SP, =0x40000            // set up the IRQ mode stack pointer
				
				/* Change back to SVC (supervisor) mode with interrupts diabled */
				MOV      R1, #0b11010011         // interrupts masked/disabled, MODE = SVC 
				MSR      CPSR_c, R1              // change to supervisor mode (10011)
				LDR      SP, =0x20000            // set up the SVC mode stack pointer
				
                BL       CONFIG_GIC              // configure the ARM generic interrupt controller
				
				// 2. Enable interrupts to come out of the KEY 3~0
                // Configure the KEY pushbutton port to generate interrupts
                LDR      R0, =0xFF200050         // pushbutton KEY base address
				MOV      R1, #0xF                // set interrupt mask bits to (1111)
				         						 // to allow/have KEY 0~3 cause an interrupt 
												 // when it is pressed & released
				STR      R1, [R0, #0x8]			 // interrupt mask register is (base + 8)

                // enable IRQ interrupts in the processor
                MOV      R0, #0b01010011         // IRQ unmasked/enabled, MODE = SVC
				MSR      CPSR_c, R0              // change to supervisor mode (10011)

IDLE:
                B        IDLE                    // main program simply idles

IRQ_HANDLER:
                PUSH     {R0-R7, LR}
    
                /* Read the ICCIAR in the CPU interface */
                LDR      R4, =0xFFFEC100
                LDR      R5, [R4, #0x0C]         // read the interrupt ID

CHECK_KEYS:
                CMP      R5, #73
UNEXPECTED:     BNE      UNEXPECTED              // if not recognized, stop here
    
                BL       KEY_ISR
EXIT_IRQ:
                /* Write to the End of Interrupt Register (ICCEOIR) */
                STR      R5, [R4, #0x10]         // 0x10 = 16 = 1 0000
    
                POP      {R0-R7, LR}
                SUBS     PC, LR, #4              // return from interrupt to the main program

/*****************************************************0xFF200050***********************************
 * Pushbutton - Interrupt Service Routine                                
 *                                                                          
 * This routine checks which KEY(s) have been pressed. It writes to HEX3-0
 ***************************************************************************************/
                .global  KEY_ISR
/* Reminder
* -> now, we are in IRQ mode, R0~12 is the same, but different SP, LR, CPSRs
* -> while we are doing task requested from interrupt, we should push and pop to save and restore R4 ~ R12
*/
KEY_ISR:        
                PUSH     {R4-R12}                // push/store original values on stack
				
				LDR      R0, =0xFF200020         // the base address of HEX 3~0
				LDR      R1, =0xFF200050         // the base address of KEY 3~0
				
				MOV      R4, #0b00111111         // 7-SEG for 0
				MOV      R5, #0b00000110         // 7-SEG for 1
				MOV      R6, #0b01011011         // 7-SEG for 2
				MOV      R7, #0b01001111         // 7-SEG for 3
				
				LSL      R5, #8                  // logical shift left R5(1) to fit into HEX1
				LSL      R6, #16                 // logical shift left R6(2) to fit into HEX2
				LSL      R7, #24                 // logical shift left R7(3) to fit into HEX3
				
				MOV      R8, #0                  // the display register

ANALYSE:		LDR      R9, [R1, #0xC]          // load the edge capture register for KEY 3~0
				
				CMP      R9, #KEY0               // if KEY0 is pressed
				ORREQ    R8, R4                  // we store the value for displaying 0 into display register
				
				CMP      R9, #KEY1               // if KEY1 is pressed
				ORREQ    R8, R5                  // we store the value for displaying 1 into display register
				
				CMP      R9, #KEY2               // if KEY2 is pressed
				ORREQ    R8, R6                  // we store the value for displaying 2 into display register
				
				CMP      R9, #KEY3               // if KEY1 is pressed
				ORREQ    R8, R7                  // we store the value for displaying 3 into display register
				
DISPLAY:		LDR      R10, [R0]               // we load what is now displaying
				EOR      R8, R10                 // and toggle the HEX display
				STR      R8, [R0]                // now, we display the HEXs value

RETURN:			STR      R9, [R1, #0xC]          // before going back, we need to reset the edge capture register of KEYs
				POP      {R4-R12}                // pop/restore orginal values back from stack
                MOV      PC, LR                  // return to IRQ_HANDLER stage

/* 
 * Configure the Generic Interrupt Controller (GIC)
*/

/* Interrupt controller (GIC) CPU interface(s) */
				.equ   MPCORE_GIC_CPUIF,     0xFFFEC100   /* PERIPH_BASE + 0x100 */
				.equ   ICCICR,               0x00         /* CPU interface control register */
				.equ   ICCPMR,               0x04         /* interrupt priority mask register */
				.equ   ICCIAR,               0x0C         /* interrupt acknowledge register */
				.equ   ICCEOIR,              0x10         /* end of interrupt register */
				/* Interrupt controller (GIC) distributor interface(s) */
				.equ   MPCORE_GIC_DIST,      0xFFFED000   /* PERIPH_BASE + 0x1000 */
				.equ   ICDDCR,               0x00         /* distributor control register */
				.equ   ICDISER,              0x100        /* interrupt set-enable registers */
				.equ   ICDICER,              0x180        /* interrupt clear-enable registers */
				.equ   ICDIPTR,              0x800        /* interrupt processor targets registers */
				.equ   ICDICFR,              0xC00        /* interrupt configuration registers */

                .global  CONFIG_GIC
CONFIG_GIC:
                PUSH     {LR}
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
