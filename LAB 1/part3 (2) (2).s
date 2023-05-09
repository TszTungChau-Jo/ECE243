/* Program that finds the largest number in a list of integers	*/
            
            .text                   // executable code follows
            .global _start                  
_start:                             
            MOV     R4, #RESULT     // R4 points to result location
			LDR     R0, [R4, #4]    // R0 holds the number of elements (N) in the list
            
			MOV     R1, #NUMBERS    // R1 points to the start of the list
            
			BL      LARGE           
            
			STR     R0, [R4]        // stores the value of R0 into the memory addr of R4
									// R0 holds the subroutine return value

END:        B       END             

/* Subroutine: to find the largest integer in a list
 * Variable:   R0 counter
 *             R1 has the address of the start of the list
 * Returns:    R0 stores the largest item in the list 
 */

			// at this point, R0 holds the number of numbers left in the list
LARGE:		LDR		R2, [R1]		// R2 is used to store the largest number in the list
			// continue...
			
LOOP:		SUBS	R0, #1			// compares all elements in the list
			BEQ 	RETURN
			
			ADD 	R1, #4			// points to the next element in the list; by adding 4 bytes to access the next word in memory
			LDR		R3, [R1]
			
			CMP		R2, R3			// substracts R3 from R2 and uses the result for the next conditional
			BGE		LOOP			// if R2 is greater or equal to R3, we goes to LOOP and compare the next #
			
			// at this point, R3 is larger than R2
			MOV		R2, R3			// so we need to update R2
			
			// then repeats the loop till we have checked for all numbers
			B 		LOOP
			
			// since we want to use R0 to stores the largest number, which is now in R2
RETURN:		MOV 	R0, R2
			MOV 	PC, LR
			// returns
			
			
RESULT:     .word   0           
N:          .word   7           // number of entries in the list
NUMBERS:    .word   4, 5, 3, 6  // the data
            .word   1, 8, 2                 

            .end                            
