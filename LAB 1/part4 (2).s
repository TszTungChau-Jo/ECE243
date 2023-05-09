/* Program that converts a binary number to decimal */
           
           .text               // executable code follows
           .global _start

/* Registors Usage:
 * R0: holds the remainder after calculation
 * R1: holds the digit in each decimal place
 * R2: counts the number in each digit and paste the value to R1 at the end
 * R3: used to vary the "dividend" for finding each digit
 * R4: holds the number #N to be coverted
 * R5: holds the word memory address to be modified
 */

_start:
			MOV    R4, #N		// R4 point to the addr of the number (N) to be operated
            MOV    R5, #Digits  // R5 points to the decimal digits storage location
            LDR    R4, [R4]     // R4 holds N
            
			MOV    R0, R4       // parameter for DIVIDE goes in R0
            
			MOV	   R3, #1000  	// To get the 4th thoudandth digit
			BL     DIVIDE
			STRB   R1, [R5, #3] // Stores the value of R1 into the 4th word byte of the memory address of R5
            // Thousands digit is now in R1
			
			MOV	   R3, #100  	// To get the 3rd hundredth digit
			BL     DIVIDE
			STRB   R1, [R5, #2] // Stores the value of R1 into the 3rd word byte of the memory address of R5
			// Hundreds digit is now in R1
			
			MOV	   R3, #10  	// To get the 2nd tenth digit
			BL     DIVIDE
			STRB   R1, [R5, #1] // Stores the value of R1 into the 2nd word byte of the memory address of R5
            // Tens digit is now in R1
			
			STRB   R0, [R5]     // Stores the value of R0 into the 1st word byte of the memory address of R5
			// Ones digit is in R0

END:        B      END


/* Subroutine to perform the integer division R0 / 10.
 * Returns: quotient in R1, and remainder in R0 */
DIVIDE:     MOV    R2, #0

// Conditional
CONT:       CMP    R0, R3		// Instead of comparing #10, we varies R3 so that we can get different digit values
            BLT    DIV_END
            SUB    R0, R3
            ADD    R2, #1
            B      CONT

// Return Statement
DIV_END:    MOV    R1, R2     // quotient in R1 (remainder in R0)
            MOV    PC, LR



N:          .word  2345         // the decimal number to be converted

Digits:     .space 4         // storage "space" for the decimal digits (N) above => defines 4 bytes of zeroed storage
							 // The SPACE assembler directive reserves a zeroed block of memory

            .end
