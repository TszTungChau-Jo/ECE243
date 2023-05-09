//... use your processor code from Part III, and add support for b{cond}

module proc(DIN, Resetn, Clock, Run, DOUT, ADDR, W);
    input [15:0] DIN;
    input Resetn, Clock, Run;
    output wire [15:0] DOUT;
    output wire [15:0] ADDR;
    output wire W;

    wire [0:7] R_in; // r0, ..., r7 register enables
    reg rX_in, IR_in, ADDR_in, Done, DOUT_in, A_in, G_in, AddSub, ALU_and;
    reg [2:0] Tstep_Q, Tstep_D;
    reg [15:0] BusWires;
    reg [3:0] Select; // BusWires selector
    reg [15:0] Sum;
    wire [2:0] III, rX, rY; // instruction opcode and register operands
    wire [15:0] r0, r1, r2, r3, r4, r5, r6, pc, A;
    wire [15:0] G;
    wire [15:0] IR;
    reg pc_incr;    // used to increment the pc
    reg pc_in;      // used to load the pc
    reg W_D;        // used for write signal
    wire Imm;
    reg F_in;       // used to update conditional flags
    wire [2:0] flags;  // 3-bit flag: flags[2] => carry, flags[1] => negative, flags[0] => zero
    reg Cout;       // carry-out from an ALU operation

    assign III = IR[15:13];
    assign Imm = IR[12];
    assign rX = IR[11:9];
    assign rY = IR[2:0];
    dec3to8 decX (rX_in, rX, R_in); // produce r0 - r7 register enables

    // Six cycles maximum
    parameter T0 = 3'b000, 
              T1 = 3'b001, 
              T2 = 3'b010, 
              T3 = 3'b011, 
              T4 = 3'b100, 
              T5 = 3'b101;

    // Control FSM state table
    always @(Tstep_Q, Run, Done)
        case (Tstep_Q)
            T0: // instruction fetch
                if (~Run) Tstep_D = T0;
                else Tstep_D = T1;
            
            T1: // wait cycle for synchronous memory
                Tstep_D = T2;
            
            T2: // this time step stores the instruction word in IR
                Tstep_D = T3;
            
            T3: if (Done) Tstep_D = T0;
                else Tstep_D = T4;
            
            T4: if (Done) Tstep_D = T0;
                else Tstep_D = T5;
            
            T5: // instructions end after this time step
                Tstep_D = T0;
            
            default: Tstep_D = 3'bxxx;
        endcase

    /* OPCODE format: III M XXX DDDDDDDDD, where 
    *     III = instruction, M = Immediate, XXX = rX. 
    *     If M = 0, DDDDDDDDD = 000000YYY = rY
    *     If M = 1, DDDDDDDDD = #D is the immediate operand 
    *
    *  III M  Instruction   Description
    *  --- -  -----------   -----------
    *  000 0: mv   rX,rY    rX <- rY
    *  000 1: mv   rX,#D    rX <- D (sign extended)
    *  001 1: mvt  rX,#D    rX <- D << 8
    *  010 0: add  rX,rY    rX <- rX + rY
    *  010 1: add  rX,#D    rX <- rX + D
    *  011 0: sub  rX,rY    rX <- rX - rY
    *  011 1: sub  rX,#D    rX <- rX - D
    *  100 0: ld   rX,[rY]  rX <- [rY]
    *  101 0: st   rX,[rY]  [rY] <- rX
    *  110 0: and  rX,rY    rX <- rX & rY
    *  110 1: and  rX,#D    rX <- rX & D */
    
    parameter mv = 3'b000, 
              mvt = 3'b001, 
              add = 3'b010, 
              sub = 3'b011, 
              ld = 3'b100, 
              st = 3'b101,
	          and_ = 3'b110;
    
    // selectors for the BusWires multiplexer
    parameter _R0 = 4'b0000, 
              _R1 = 4'b0001, 
              _R2 = 4'b0010, 
              _R3 = 4'b0011, 
              _R4 = 4'b0100,
              _R5 = 4'b0101, 
              _R6 = 4'b0110, 
              _PC = 4'b0111, 
              _G = 4'b1000, 
              _IR8_IR8_0 /* signed-extended immediate data */ = 4'b1001, 
              _IR7_0_0 /* immediate data << 8 */ = 4'b1010,
              _DIN /* data-in from memory */ = 4'b1011;
    
    // conditional branches parameters; total 7 conditions
    parameter _BBB = 3'b000,
              _BEQ = 3'b001,
              _BNE = 3'b010,
              _BCC = 3'b011,
              _BCS = 3'b100,
              _BPL = 3'b101,
              _BMI = 3'b110;

    // define the internal processor bus
    always @(*)
        case (Select)
            _R0: BusWires = r0;
            _R1: BusWires = r1;
            _R2: BusWires = r2;
            _R3: BusWires = r3;
            _R4: BusWires = r4;
            _R5: BusWires = r5;
            _R6: BusWires = r6;
            _PC: BusWires = pc;
            _G: BusWires = G;
            _IR8_IR8_0: BusWires = {{7{IR[8]}}, IR[8:0]}; // sign extended
            _IR7_0_0: BusWires = {IR[7:0], 8'b0};
            _DIN: BusWires = DIN;
            default: BusWires = 16'bx;
        endcase

    // Control FSM outputs
    always @(*) begin
        // default values for control signals
        rX_in = 1'b0; 
        A_in = 1'b0; 
        G_in = 1'b0; 
        IR_in = 1'b0; 
        DOUT_in = 1'b0; 
        ADDR_in = 1'b0; 
        
        Select = 4'bxxxx; 
        AddSub = 1'b0; 
        ALU_and = 1'b0; 
        W_D = 1'b0; 
        Done = 1'b0;

        pc_in = R_in[7] /* default pc enable */; 
        pc_incr = 1'b0;

        F_in = 1'b0;

        case (Tstep_Q)
            T0: begin // fetch the instruction
                Select = _PC;  // put pc onto the internal bus
                ADDR_in = 1'b1;
                pc_incr = Run; // to increment pc
            end
            
            T1: // wait cycle for synchronous memory
                ;
            
            T2: // store instruction on DIN in IR 
                IR_in = 1'b1;
            
            T3: // define signals in T3
                case (III)
                    ////////////////////////////////////////////////////////////////////// Instrction 1
                    mv: begin
                        if (!Imm) Select = rY;          // mv rX, rY
                        else Select = _IR8_IR8_0;       // mv rX, #D
                        rX_in = 1'b1;                   // enable the rX register
                        Done = 1'b1;
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 2
                    mvt: begin
                        case(Imm)
                            ///////////////////////////// mvt                         
                            1'b1: begin
                                Select = _IR7_0_0;
                                rX_in = 1'b1;                   // enable the rX register
                                Done = 1'b1;
                            end

                            ///////////////////////////// B{COND}
                            1'b0: begin
                                Select = _PC;
                                A_in = 1'b1;
                                /* check for the XXX bits in III M XXX DDDDDDDDD opCode */

                                /* flags [2:0]
                                *  flags [2] => carry-bit
                                *  flags [1] => negative-bit
                                *  flage [0] => zero-bit
                                */

                                case(rX)  
                                    ///////////////////// 1. B{BB} (always branch)
                                    // _BBB: begin
                                    //     ;  // no condition check needed, proceed to next cycle
                                    // end

                                    ///////////////////// 2. B{EQ}
                                    _BEQ: begin
                                        if (!flags[0]) Done = 1'b1;  // if(!COND) Done
                                    end

                                    ///////////////////// 3. B{NE}
                                    _BNE: begin
                                        if (flags[0]) Done = 1'b1;  // if(!COND) Done
                                    end
                                    
                                    ///////////////////// 4. B{CC}
                                    _BCC: begin
                                        if (flags[2]) Done = 1'b1;  // if(!COND) Done
                                    end

                                    ///////////////////// 5. B{CS}
                                    _BCS: begin
                                        if (!flags[2]) Done = 1'b1;  // if(!COND) Done
                                    end

                                    ///////////////////// 6. B{PL}
                                    _BPL: begin
                                        if (flags[1]) Done = 1'b1;  // if(!COND) Done
                                    end

                                    ///////////////////// 7. B{MI}
                                    _BMI: begin
                                        if (!flags[1]) Done = 1'b1;  // if(!COND) Done
                                    end

                                    default: ; 
                                endcase
                            end

                        endcase
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 3, 4, 5
                    add, sub, and_: begin
                        Select = rX;                    // side note: select rX first goes to the 3to8dec decoder, so that we can select a specific register to use
                        A_in = 1'b1;
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 6, 7
                    ld, st: begin
                        Select = rY;
                        ADDR_in = 1'b1;
                    end
                    
                    default: ;
                endcase
            
            T4: // define signals T2
                case (III)
                    ////////////////////////////////////////////////////////////////////// Instrction 2 === for b{COND}
                    mvt: begin
                        Select = _IR8_IR8_0;
                        AddSub = 1'b0;  // add that const "DDD DDD DDD" to the program counter
                        G_in = 1'b1;
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 3
                    add: begin
                        Select = Imm ? _IR8_IR8_0 : rY;
                        AddSub = 1'b0;
                        G_in = 1'b1;
                        F_in = 1'b1;  // updates flags
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 4
                    sub: begin
                        Select = Imm ? _IR8_IR8_0 : rY;
                        AddSub = 1'b1;
                        G_in = 1'b1;
                        F_in = 1'b1;  // updates flags
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 5
                    and_: begin
                        Select = Imm ? _IR8_IR8_0 : rY;
                        ALU_and = 1'b1;
                        G_in = 1'b1;
                        F_in = 1'b1;  // updates flags
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 6
                    ld: // wait cycle for synchronous memory
                        ;
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 7
                    st: begin
                        Select = rX;
                        DOUT_in = 1'b1;
                        W_D = 1'b1; 
                        Done = 1'b1;
                    end
                    
                    default: ; 
                endcase
            
            T5: // define T3
                case (III)
                    ////////////////////////////////////////////////////////////////////// Instrction 2 === for b{COND}
                    mvt: begin
                        Select = _G;
                        pc_in = 1'b1;
                        Done = 1'b1;
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 3, 4, 5
                    add, sub, and_: begin
                        Select = _G;
                        rX_in = 1'b1;
                        Done = 1'b1;
                    end
                    
                    ////////////////////////////////////////////////////////////////////// Instrction 6
                    ld: begin
                        Select = _DIN;
                        rX_in = 1'b1;
                        Done = 1'b1;
                    end
                    
                    default: ;
                endcase
            
            default: ;
        endcase
    end   
   
    // Control FSM flip-flops
    always @(posedge Clock)
        if (!Resetn)
            Tstep_Q <= T0;
        else
            Tstep_Q <= Tstep_D;   
    
    // Instantiation of Computation Registers
    regn reg_0 (BusWires, Resetn, R_in[0], Clock, r0);
    regn reg_1 (BusWires, Resetn, R_in[1], Clock, r1);
    regn reg_2 (BusWires, Resetn, R_in[2], Clock, r2);
    regn reg_3 (BusWires, Resetn, R_in[3], Clock, r3);
    regn reg_4 (BusWires, Resetn, R_in[4], Clock, r4);
    regn reg_5 (BusWires, Resetn, R_in[5], Clock, r5);
    regn reg_6 (BusWires, Resetn, R_in[6], Clock, r6);

    // r7 is program counter
    // module pc_count(R, Resetn, Clock, E, L, Q);
    pc_count reg_pc (BusWires, Resetn, Clock, pc_incr, pc_in, pc);
    
    // rDOUT: data to be manipulated in the memory
    regn reg_DOUT (BusWires, Resetn, DOUT_in, Clock, DOUT);
    
    // rADDR: address in memory to be operated at
    regn reg_ADDR (BusWires, Resetn, ADDR_in, Clock, ADDR);
    
    // Instrction Register
    regn reg_IR (DIN, Resetn, IR_in, Clock, IR);

    // rW: Write-Enable register to the memory
    flipflop reg_W (W_D, Resetn, Clock, W);
    
    // rA: ALU computation input
    regn reg_A (BusWires, Resetn, A_in, Clock, A);

    // rG: ALU computation output
    regn reg_G (Sum, Resetn, G_in, Clock, G);

    // alu
    always @(*)
        if (!ALU_and)
            if (!AddSub)
                {Cout, Sum} = A + BusWires;             // ADD
            else
                {Cout, Sum} = A + ~BusWires + 16'b1;    // SUB: A + B(inverted + 1), 2's complement substraction
        else
            Sum = A & BusWires;                         // Bit-wise logical AND

    // rF: conditional flags registers
    reg_Flags reg_F (Cout, Sum[15], Sum[15:0], Resetn, Clock, F_in, flags);

endmodule // Proc


module reg_Flags(carry, ALU_15, ALU_sum, Resetn, Clock, E, Q);
    input carry;
    input ALU_15;
    input [15:0] ALU_sum;
    input Resetn, Clock, E;
    output [2:0] Q;
    reg [2:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= 3'b0;
        else if (E) begin
            Q[2] <= carry;                // c-bit
            Q[1] <= ALU_15;               // n-bit
            Q[0] <= (ALU_sum == 16'b0);   // z-bit
        end
endmodule


module pc_count(R, Resetn, Clock, E, L, Q);
    input [15:0] R;              // R is the input to the register from the buswires
    input Resetn, Clock, E, L;   // E -> pc_incr (a pc increment enable signal), L -> pc_in (a load enable signal)
    output [15:0] Q;             // Q is the output of the register
    reg [15:0] Q;
   
    always @(posedge Clock)
        if (!Resetn)
            Q <= 16'b0;
        else if (L)
            Q <= R;
        else if (E)
            Q <= Q + 1'b1;

endmodule // pc_count


module dec3to8(E, W, Y);
    input E; // enable
    input [2:0] W;
    output [0:7] Y;
    reg [0:7] Y;
   
    always @(*)
        if (E == 0)
            Y = 8'b00000000;
        else
            case (W)
                3'b000: Y = 8'b10000000;
                3'b001: Y = 8'b01000000;
                3'b010: Y = 8'b00100000;
                3'b011: Y = 8'b00010000;
                3'b100: Y = 8'b00001000;
                3'b101: Y = 8'b00000100;
                3'b110: Y = 8'b00000010;
                3'b111: Y = 8'b00000001;
            endcase

endmodule // dec3to8


module regn(R, Resetn, E, Clock, Q);
    parameter n = 16;
    input [n-1:0] R;
    input Resetn, E, Clock;
    output [n-1:0] Q;
    reg [n-1:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= 0;
        else if (E)
            Q <= R;

endmodule // regn
