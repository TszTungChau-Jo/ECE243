/* Subroutine to convert the digits from 0 to 9 to be shown on a HEX display.
 *    Parameters: R0 = the decimal value of the digit to be displayed
 *    Returns: R0 = bit patterm to be written to the HEX display
 */
          .text                   // executable code follows
          .global _start    

_start:
		  MOV	  SP, #0x20000    // must always initialise the stack pointer
		  MOV     R3, #TEST_NUM   // R3 holds the address of the word
		  MOV	  R10, #CONST
		  LDR	  R10, [R10]

M_LOOP:   LDR     R1, [R3]  	  // load the data word TO R1
		  CMP 	  R1, #0
		  BEQ	  DISPLAY			  // if reaches 0, program ends  
		  BL	  ONES
		  CMP	  R5, R0
		  BGE	  CONT_0
		  MOV	  R5, R0		  // consecutive 1s
		  
CONT_0:	  LDR	  R1, [R3]
		  BL	  ZEROS
		  CMP	  R6, R0
		  BGE	  CONT_ALT
		  MOV	  R6, R0		  // consecutive 0s
		  
CONT_ALT: LDR	  R1, [R3], #4    // pre-indexing the pointer to the next element in the list
		  MOV	  R8, R1
		  BL	  ALTERNATE

		  B		  M_LOOP  


ZEROS:	  PUSH	  {LR}	  
		  MVN	  R1, R1		  // calculate for 0s
		  BL	  ONES
		  POP	  {PC}


ONES:     MOV     R0, #0          // R0 will hold the result
LOOP:     CMP     R1, #0          // loop until the data contains no more 1's
          BEQ     DONE             
          LSR     R2, R1, #1      // perform SHIFT, followed by AND
          AND     R1, R1, R2      
          ADD     R0, #1          // count the string length so far
          B       LOOP            
DONE:     MOV     PC, LR         


ALTERNATE:PUSH	  {LR}

		  EOR	  R1, R10
		  BL	  ZEROS
		  CMP	  R7, R0
		  BGE	  CONT
		  MOV	  R7, R0

CONT:	  MOV	  R1, R8
		  EOR	  R1, R10
		  BL	  ONES
		  CMP	  R7, R0
		  BGE	  ALT_END
		  MOV	  R7, R0
		  
ALT_END:  POP	  {PC}


///////////////////////////////////////////////////////////////////// above is the same the previous section


/* Display R5 on HEX1-0, R6 on HEX3-2 and R7 on HEX5-4 */
DISPLAY:    LDR     R8, =0xFF200020 // base address of HEX3-HEX0
            MOV		R4, #0			// make sure R4 is cleared
			MOV     R0, R5          // display R5 on HEX1-0
            BL      DIVIDE          // ones digit will be in R0; tens
                                    // digit in R1
            MOV     R9, R1          // save the tens digit!!
            BL      SEG7_CODE       
            MOV     R4, R0          // HEX0
           
		    MOV     R0, R9          // retrieve the tens digit, get bit
            BL      SEG7_CODE       // code
            LSL     R0, #8
            ORR     R4, R0          // HEX1


            //	code for R6 - the second result - the longest string of 0's
			MOV		R0, R6
			BL		DIVIDE
			
			MOV		R9, R1
			BL		SEG7_CODE
			LSL		R0, #16
			ORR		R4, R0          // HEX2
			
			MOV		R0, R9
			BL		SEG7_CODE
			LSL		R0, #24
			ORR		R4, R0          // HEX3

            STR     R4, [R8]        // display the numbers from R6 and R5
            
			
			LDR     R8, =0xFF200030 // base address of HEX5-HEX4
			
			//	code for R7 - the third result - the longest string of alternating 1s,0s 
			MOV		R4, #0
			
			MOV		R0, R7
			BL		DIVIDE
			
			MOV		R9, R1
			BL		SEG7_CODE
			MOV		R4, R0          // HEX4
			
			MOV		R0, R9
			BL		SEG7_CODE
			LSL		R0, #8
			ORR		R4, R0          // HEX5
			

            STR     R4, [R8]        // display the number from R7

END:	  B		  END


DIVIDE:		MOV    R2, #0
			MOV	   R1, #10
CONT_DIV:   CMP    R0, R1
            BLT    DIV_END
            SUB    R0, R1
            ADD    R2, #1
            B      CONT_DIV
DIV_END:    MOV    R1, R2     // tens in R1, ones in R0
			MOV	   PC, LR
			


SEG7_CODE:  MOV     R1, #BIT_CODES  
            ADD     R1, R0         // index into the BIT_CODES "array"
            LDRB    R0, [R1]       // load the bit pattern (to be returned)
            MOV     PC, LR              

BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
            .byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
            .skip   2      // pad with 2 bytes zeros at the front to maintain word alignment


TEST_NUM: .word   0x2B55B1, 0xb51, 0x103fe00f, 0x12345678, 0x11451419, 0
CONST:	  .word   0x55555555
          .end                            
