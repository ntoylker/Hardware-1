// Kodikas gia tin ALU
module alu (
    input signed [31:0] op1,     // Eisodos 1 (signed)
    input signed [31:0] op2,     // Eisodos 2 (signed)
    input [3:0] alu_op,          // 4-bit kwdikos praksis
    output wire zero,            // Eksodos: 1 an to result einai 0
    output reg [31:0] result,    // Eksodos: To 32-bit apotelesma
    output reg ovf               // Eksodos: 1 an yparxei yperxeilisi
);

    /* STATHERES GIA TIS PRAKSEIS TIS ALU */
    // LOGIKES PRAKSEIS
    parameter[3:0] ALUOP_AND  = 4'b1000;
    parameter[3:0] ALUOP_OR   = 4'b1001;
    parameter[3:0] ALUOP_NOR  = 4'b1010;
    parameter[3:0] ALUOP_NAND = 4'b1011;
    parameter[3:0] ALUOP_XOR  = 4'b1100;
    // PROSHMASMENES PRAKSEIS
    parameter[3:0] ALUOP_SUM  = 4'b0100;
    parameter[3:0] ALUOP_SUB  = 4'b0101;
    parameter[3:0] ALUOP_MUL  = 4'b0110;
    // OLISTHISEIS (Shifts)
    parameter[3:0] ALUOP_LOG_SHFT_RIGHT   = 4'b0000;
    parameter[3:0] ALUOP_LOG_SHFT_LEFT    = 4'b0001;
    parameter[3:0] ALUOP_ARTHM_SHFT_RIGHT = 4'b0010;
    parameter[3:0] ALUOP_ARTHM_SHFT_LEFT  = 4'b0011;

    // Endiamesa simata gia ton ypologismo tis yperxeilisis (overflow)
    // Auta einai xrisima gia na krathsoume to 'always' block katharo.
    wire signed [31:0] add_res = op1 + op2;
    wire signed [31:0] sub_res = op1 - op2;
    wire signed [63:0] mul_res = op1 * op2; // O pollaplasiasmos 32x32 dinei 64-bit apotelesma

    /* OVERFLOW LOGIC */
    // 1. Prosthesi: Yperxeilisi symvainei an oi telestes exoun idio prosimo
    //    kai to apotelesma exei diaforetiko prosimo.
    wire add_ovf = (op1[31] == op2[31]) && (add_res[31] != op1[31]);
    
    // 2. Afairesi: Yperxeilisi symvainei an oi telestes exoun diaforetiko prosimo
    //    kai to apotelesma exei to prosimo tou op2 (tou afaireteou).
    wire sub_ovf = (op1[31] != op2[31]) && (sub_res[31] != op1[31]);
    
    // 3. Pollaplasiasmos: Yperxeilisi symvainei an to 64-bit apotelesma den
    //    "xoraei" se 32 bits (dhl. ta anw 32 bits den einai apli epektasi prosimou).
    //    Elegxoume an *ola* ta bits [63:31] einai idia.
    wire mul_ovf = |(mul_res[63:32] ^ {32{mul_res[31]}});

    /* O POLYPLEKTHS (YLOPOIHSH ME CASE) */
    // Auto to block ylopoiei ti syndyastiki logiki tis ALU.
    // Ekteleitai "panta" (@) otan allaksei opoiadipote eisodos (*).
    always @(*) begin
        // Xrhsimopoioume 'case' gia na epileksoume tin praksi vasei tou alu_op
        case (alu_op)
            ALUOP_AND:  begin
                result = op1 & op2;
                ovf = 1'b0; // Den orizetai yperxeilisi
            end
            ALUOP_OR:   begin
                result = op1 | op2;
                ovf = 1'b0;
            end
            ALUOP_NOR:  begin
                result = ~(op1 | op2);
                ovf = 1'b0;
            end
            ALUOP_NAND: begin
                result = ~(op1 & op2);
                ovf = 1'b0;
            end
            ALUOP_XOR:  begin
                result = op1 ^ op2;
                ovf = 1'b0;
            end
            ALUOP_SUM:  begin
                result = add_res;
                ovf = add_ovf;
            end
            ALUOP_SUB:  begin
                result = sub_res;
                ovf = sub_ovf;
            end
            ALUOP_MUL:  begin
                result = mul_res[31:0]; // Kratame mono ta katw 32 bits
                ovf = mul_ovf;
            end
            
            // Simiwsi: Oi telestes olisthisis se Verilog xrhsimopoioun 
            // automatika mono ta 5 xamilotera bits tou op2 (afou o op1 einai 32-bit).
            ALUOP_LOG_SHFT_RIGHT:   begin
                // Xrhsimopoioume $unsigned gia na ginei sigoura logiki (oxi arithmitiki) olisthisi
                result = $unsigned(op1) >> op2;
                ovf = 1'b0;
            end
            ALUOP_ARTHM_SHFT_RIGHT: begin
                // Epeidi o op1 einai 'signed', o telestis '>>>' tha kanei arithmitiki olisthisi
                result = op1 >>> op2;
                ovf = 1'b0;
            end
            ALUOP_LOG_SHFT_LEFT:    begin
                result = op1 << op2;
                ovf = 1'b0;
            end
            ALUOP_ARTHM_SHFT_LEFT:  begin
                // H arithmitiki aristeri olisthisi einai idia me ti logiki
                result = op1 << op2;
                ovf = 1'b0;
            end
            
            // Einai kali praktiki na exoume 'default' gia na apofygei latches
            default: begin
                result = 32'bx; // 'x' = agnosti/adiafori timi
                ovf = 1'bx;
            end
        endcase
    end
endmodule
