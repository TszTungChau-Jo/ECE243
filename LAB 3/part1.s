/* Lab 3 Part 1: Display HEX 3-0 with the desired numbers
   Name: Joshua Chau
   Date: 2023-02-04
 */
          .text                   // executable code follows
          .global _start    
		  
		  .equ KEY_BASE, 0xFF200050   // base address of KEY 3-0
		  .equ HEX0_BASE, 0xFF200020  // base address of HEX 0~4

_start:
		  MOV	  SP, #0x20000    // must always initialise the stack pointer
	      LDR     R4, =KEY_BASE   // R4 holds the base addr of KEY 3~0
		  LDR     R5, =HEX0_BASE  // R5 holds the base addr of HEX 3~0
		  MOV     R3, #0          // R3 is the number we will display

POLLING:  
	      LDR     R6, [R4]        // R6 reads the current ON/OFF of a KEY
		  CMP     R6, #0
		  BEQ     POLLING         // Idling for a pressed KEY

KEY3:     CMP     R6, #8          // 8 -> 1000
   		  BGE     BLACK

KEY2:     CMP     R6, #4          // 4 -> 0100
		  BGE     DOWN

KEY1:     CMP     R6, #2          // 2 -> 0010
          BGE     UP

KEY0:     CMP     R6, #1          // 1 -> 0001
		  BEQ     RESET

RESET:	  
		  LDR     R6, [R4]        
		  CMP     R6, #0
		  BNE     RESET          // checks if the KEY has not released yet
		  
		  MOV     R3, #0

		  B       DISPLAY
UP:
		  CMP     R3, #9
		  BEQ     DISPLAY
		  
		  LDR     R6, [R4]
		  CMP     R6, #0
		  BNE     UP             // checks if the KEY has not released yet
		  
		  ADD     R3, #1
		  BEQ     DISPLAY
DOWN:
		  CMP     R3, #0
		  BEQ     DISPLAY
		  
		  LDR     R6, [R4]
		  CMP     R6, #0
		  BNE     DOWN           // checks if the KEY has not released yet
		  
		  SUB     R3, #1
		  BEQ     DISPLAY

BLACK:
		  LDR     R6, [R4]
		  CMP     R6, #0
		  BNE     BLACK          // checks if the KEY has not released yet
		  
		  MOV     R3, #0
		  STR     R3, [R5]       // blanks the display back to nothing
		  
		  B       POLLING

DISPLAY:    
          MOV     R0, R3         // R3 is the number we previously determined to be displayed
		  BL	  SEG7_CODE
		  STR     R0, [R5]
		  
		  B       POLLING        // repeat the cycle of polling

END:	  B		  END            // end of MAIN

SEG7_CODE:  
		  MOV     R1, #BIT_CODES  
          ADD     R1, R0         // index into the BIT_CODES "array"
          LDRB    R0, [R1]       // load the bit pattern (to be returned)
          MOV     PC, LR              

BIT_CODES:  
		  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
          .byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
          .skip   2      // pad with 2 bytes zeros at the front to maintain word alignment


          .end