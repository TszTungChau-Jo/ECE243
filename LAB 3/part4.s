/* Lab 3 Part 2: Display HEX 1-0 as a counter from 0~99
   Name: Joshua Chau
   Date: 2023-02-04
 */
          .text                   // executable code follows
          .global _start    
		  .equ KEY_BASE, 0xFF200050   // base address of KEY 3-0
		  .equ HEX0_BASE, 0xFF200020  // base address of HEX 0~4
		  .equ PTIMER, 0xFFFEC600      // base address of private timer

_start:
		  MOV	  SP, #0x20000    // must always initialise the stack pointer
	      LDR     R4, =KEY_BASE   // R4 holds the base addr of KEY 3~0
		  LDR     R5, =HEX0_BASE  // R5 holds the base addr of HEX 3~0
		  
		  LDR     R7, =PTIMER
		  LDR     R10, =2000000   // Requirement: counter will be loaded with 2000000 -> 0.01 sec count down
		  						  // reminder: after changing the load to counter 
								  //           need to restart CUPlator to see
								  //           the real changes
		  STR     R10, [R7]       // put it into the Load Register of the Counter
		  
		  MOV     R1, #0          // R1 is the tens digit
		  MOV     R0, #0          // R0 is the ones digit
		  MOV     R8, #0          // R8 is the counter number for displaying miliseconds
		  MOV     R10, #0         // R10 is the counter number for displaying seconds
		  MOV     R6, #0          // R6 is the display register
		  
//////////////////////////////////////////////////////////////////////////////////////////////////////// Display

LOOP:  
	      MOV     R0, R8
		  BL      DIVIDE          // tens in R1, ones in R0
		  
		  MOV     R9, R1          // R9 saves the tens digit
		  BL      SEG7_CODE       // HEX0 is ready
		  
		  MOV     R6, R0          // saves the ones digit for HEX0
		  
		  MOV     R0, R9          // retrieves the tens digit
		  BL      SEG7_CODE       // HEX1 is ready
		  
		  LSL     R0, #8          // shifts bits to position for HEX1
		  ORR     R6, R0
		  
		  MOV     R0, R10         // for ones seconds on HEX2
		  BL      DIVIDE  
		  
		  MOV     R9, R1          // R9 currently holds tens digit second
		  BL      SEG7_CODE
		  
		  LSL     R0, #16
		  ORR     R6, R0
		  
		  MOV     R0, R9          // for tens seconds on HEX3
		  BL      SEG7_CODE
		  
		  LSL     R0, #24
		  ORR     R6, R0
		  
		  STR     R6, [R5]        // displays the numbers

//////////////////////////////////////////////////////////////////////////////////////////////////////// Timer
		  
TIMER:    
		  MOV     R3, #0b011      // turn on A and E bits in counter control register
		  STR     R3, [R7, #8]    // store 0b011 into timer control reg
		  
WAIT:     LDR     R3, [R7, #0xC]  // get the full interrupt status register
		  ANDS    R3, #0x1        // isolate the F bit (bit 0)
		  BEQ     WAIT            // wait until F bit is 1 (R3 is 1)
		  STR     R3, [R7, #0xC]  // to reset the F bit to 0 in interrupt status regiser
		  MOV     R3, #0          // turn off A and E bits in counter control register
		  STR     R3, [R7, #8]    // store 0b011 into timer control reg

//////////////////////////////////////////////////////////////////////////////////////////////////////// Keys

PRESSED:  
		  LDR     R2, [R4, #0xC]  // load edge capture reg
		  CMP     R2, #0   
		  BEQ     UP              // if no KEY is pressed
POLLING:     
		  MOV     R3, R2		  // turn off edge capture bit
	      STR     R3, [R4, #0xC]  // by writing 1 into bit 2 
RELEASED: 
		  LDR     R2, [R4, #0xC]  // load edge capture reg
		  CMP     R2, #0   
		  BEQ     RELEASED        // wait until we release the key
		  MOV     R3, R2		  // turn off edge capture bit
	      STR     R3, [R4, #0xC]  // by writing 1 into bit 2 

UP:
		  CMP     R8, #99         // the limit for this counter is 99
		  BEQ     RESET
		  ADD     R8, #1
		  B       LOOP
RESET:    MOV     R8, #0          // resets to 0 if reach 99
    	  CMP     R10, #59        // the limit for a minute is 59 seconds
		  BEQ     RESET_SE
		  ADD     R10, #1
		  B       LOOP
RESET_SE: MOV     R10, #0
          B       LOOP


END:	  B		  END             // end of MAIN

////////////////////////////////////
DIVIDE:	  MOV     R2, #0
		  MOV	  R1, #10
CONT_DIV: CMP     R0, R1
          BLT     DIV_END
          SUB     R0, R1
          ADD     R2, #1
          B       CONT_DIV
DIV_END:  MOV     R1, R2          // tens in R1, ones in R0
	      MOV	  PC, LR

////////////////////////////////////
SEG7_CODE:  
		  MOV     R1, #BIT_CODES  
          ADD     R1, R0          // index into the BIT_CODES "array"
          LDRB    R0, [R1]        // load the bit pattern (to be returned)
          MOV     PC, LR              

BIT_CODES:  
		  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
          .byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
          .skip   2               // pad with 2 bytes zeros at the front to maintain word alignment


          .end