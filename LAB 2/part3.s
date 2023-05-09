/* Program that counts consecutive 1's */

          .text                   // executable code follows
          .global _start                  
_start:
		  MOV	  SP, #0x20000
		  MOV     R3, #TEST_NUM   // R3 holds the address of the word

M_LOOP:   LDR     R1, [R3]  	  // load the data word to R1
		  CMP 	  R1, #0
		  BEQ	  END			  // if reaches 0, end of list, program ends  
		  BL	  ONES
		  CMP	  R5, R0
		  BGE	  CONT_0
		  MOV	  R5, R0		  // consecutive 1s
		  
CONT_0:	  LDR	  R1, [R3]
		  BL	  ZEROS
		  CMP	  R6, R0
		  BGE	  CONT_ALT
		  MOV	  R6, R0		  // consecutive 0s
		  
CONT_ALT: LDR	  R1, [R3], #4
		  MOV	  R8, R1
		  BL	  ALTERNATE

		  B		  M_LOOP  
END:	  B		  END


/////////////////////////////////////////////////////////////////////////////////////////


ZEROS:	  PUSH	  {LR}	  
		  MVN	  R1, R1		  // bit-wise logical NOT instruction
		  BL	  ONES            // calculate for 0s
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
		  MOV	  R10, #CONST
		  
		  LDR	  R10, [R10]
		  EOR	  R1, R10         // EOR to count for longest consecutive zeros
		  BL	  ZEROS
		  CMP	  R7, R0
		  BGE	  CONT
		  MOV	  R7, R0

CONT:	  MOV	  R1, R8
		  EOR	  R1, R10         // EOR to count for longest consecutive ones
		  BL	  ONES
		  CMP	  R7, R0          // the longest alternating 0,1 is either
		  BGE	  ALT_END         // the longest consecutive zeros, or ones
		  MOV	  R7, R0          // and this is mainly by observation
		  
ALT_END:  POP	  {PC}




TEST_NUM: .word   0x2B55B1, 0xb51, 0x103fe00f, 0x12345678, 0x11451419, 0
CONST:	  .word   0x55555555
          .end                            
