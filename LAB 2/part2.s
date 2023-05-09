/* Program that counts consecutive 1's */

          .text                   // executable code follows
          .global _start                  
_start:

		  MOV     R3, #TEST_NUM   // R3 holds the address of the word

M_LOOP:   LDR     R1, [R3], #4	  // load the data word TO R1
		  CMP 	  R1, #0
		  BEQ	  END			  // if less than 0, end of list, program ends  
		  BL	  ONES
          CMP     R0, R5          // R5 stores the largest number of consecutive one's in the list
          BLE     M_LOOP
          MOV     R5, R0
		  B		  M_LOOP
		  
ONES:     MOV     R0, #0          // R0 will hold the result
LOOP:     CMP     R1, #0          // loop until the data contains no more 1's
          BEQ     DONE             
          LSR     R2, R1, #1      // perform SHIFT, followed by AND
          AND     R1, R1, R2      
          ADD     R0, #1          // count the string length so far
          B       LOOP            

DONE:     MOV     PC, LR

END:	  B		  END

TEST_NUM: .word   0x103fe00f, 0x12345678, 0x11451419, 0
          .end                            
