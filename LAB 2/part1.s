/* Program that counts consecutive 1's */

          .text                   // executable code follows
          .global _start                  
_start:                             
          MOV     R1, #TEST_NUM   // load the data word ...
          LDR     R1, [R1]        // into R1

          MOV     R0, #0          // R0 will hold the result

LOOP:     CMP     R1, #0          // loop until the data contains no more 1's
          BEQ     END             
          
		  LSR     R2, R1, #1      // perform LOGICAL SHIFT RIGHT, followed by AND
          AND     R1, R1, R2      
		  
          ADD     R0, #1          // R0 counts the string length so far
          B       LOOP            

END:      B       END             

TEST_NUM: .word   0x0007fc00      // 0xf is binary 1111, which gives us 4 consecutive 1s
								  // 0x7 is binary 0111, which gives us 3 consecutive 1s
								  // 0x3 is binary 0011, which gives us 2 consecutive 1s
								  // 0x1 is binary 0001, which gives us 1 
								  // 0xc is binary 1100, which gives us 2 consecutive 1s
								  // 0xe is binary 1110, which gives us 3 consecutive 1s
          .end                            
