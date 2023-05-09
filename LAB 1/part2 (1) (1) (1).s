/* Program that finds the largest number in a list of integers   */

         .text                  // executable code follows
         .global  _start
_start:      
         MOV      R4, #RESULT   // copy the addr of the lable #RESULT into register R4
		 
         LDR      R2, [R4, #4]  // "dereference" the value in (R4+4) && loads it into R2 
		 						
         MOV      R3, #NUMBERS  // copy the addr of the lable #NUMBERS into register R3
         
		 LDR      R0, [R3]      // "dereference" the value in (R3) && loads it into R0

LOOP:    SUBS     R2, #1        // decrements the loop counter && updates the flag in cpsr
		 BEQ      DONE          // if result is equal to 0, goes to DONE, else continue...
		 
		 ADD      R3, #4        // advance to the next memory block by incrementing up 4 bytes in memory addr
         
		 LDR      R1, [R3]      // "dereference" the value in (R3) && loads it into R1
         
		 CMP      R0, R1        // substracts R1 from R0 && uses the temporary result for the next conditionals
         BGE      LOOP          // if result is greater or equal to 0, goes to LOOP, else continue...
		 
		 /*
		 Current Program Status Register(cpsr): holds processor status and control information
		 									changes when a condition is false
		 Saved Program Status Register(spsr): stores the current value of the CPSR when an 
		 									exception is taken so that the CPSR can be restored 
		 									after handling the exception
		 */
								
		 MOV      R0, R1        // copy the value in R1 into R0
         
		 B        LOOP          // branch to the beginning of the LOOP
		// if we set a break point at here, we always stop when we get a larger # in the list

DONE:    STR      R0, [R4]      // stores the value of R0 into the memory addr of R4


END:     B        END

// lables: as variables
RESULT:  .word    0
N:       .word    7             // number of entries in the list
NUMBERS: .word    4, 5, 3, 6    // the data
         .word    1, 8, 2

         .end     
