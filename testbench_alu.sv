//
// TESTBENCH ΓΙΑ ΤΗΝ ALU - ΔΕΚΑΕΞΑΔΙΚΗ ΕΚΤΥΠΩΣΗ
//
`timescale 1ns / 1ps

module testbench;
  
  /* ΣΤΑΘΕΡΕΣ ΓΙΑ ΤΙΣ ΠΡΑΞΕΙΣ ΤΗΣ ALU */
  parameter[3:0] ALUOP_AND  = 4'b1000;
  parameter[3:0] ALUOP_OR   = 4'b1001;
  parameter[3:0] ALUOP_NOR  = 4'b1010;
  parameter[3:0] ALUOP_NAND = 4'b1011;
  parameter[3:0] ALUOP_XOR  = 4'b1100;
  parameter[3:0] ALUOP_SUM  = 4'b0100;
  parameter[3:0] ALUOP_SUB  = 4'b0101;
  parameter[3:0] ALUOP_MUL  = 4'b0110;
  parameter[3:0] ALUOP_LOG_SHFT_RIGHT   = 4'b0000;
  parameter[3:0] ALUOP_LOG_SHFT_LEFT    = 4'b0001;
  parameter[3:0] ALUOP_ARTHM_SHFT_RIGHT = 4'b0010;
  parameter[3:0] ALUOP_ARTHM_SHFT_LEFT  = 4'b0011;

  /* ΣΗΜΑΤΑ TESTBENCH */
  logic signed [31:0] tb_op1;
  logic signed [31:0] tb_op2;
  logic [3:0]         tb_alu_op;

  wire [31:0]         tb_result;
  wire                tb_zero;
  wire                tb_ovf;

  /* INSTANTIATE THE DUT (Device Under Test) */
  alu dut (
    .op1(tb_op1),
    .op2(tb_op2),
    .alu_op(tb_alu_op),
    .result(tb_result),
    .zero(tb_zero),
    .ovf(tb_ovf)
  );

  /* STIMULUS (ΔΙΕΓΕΡΣΗ) */
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, testbench);

    $display("--- ΕΝΑΡΞΗ TESTBENCH ΓΙΑ ALU (ΕΞΟΔΟΣ ΣΕ ΔΕΚΑΕΞΑΔΙΚΗ ΜΟΡΦΗ) ---");

    // --- TEST 1: ALUOP_SUM (Πρόσθεση) ---
    check_op(ALUOP_SUM, 100, 50);          // 100 + 50 = 150
    check_op(ALUOP_SUM, 10, -5);           // 10 + (-5) = 5
    check_op(ALUOP_SUM, 32'h7FFFFFFF, 1);  // Test Θετικής Υπερχείλισης
    check_op(ALUOP_SUM, 32'h80000000, -1); // Test Αρνητικής Υπερχείλισης

    // --- TEST 2: ALUOP_SUB (Αφαίρεση) ---
    check_op(ALUOP_SUB, 100, 50);          // 100 - 50 = 50
    check_op(ALUOP_SUB, 50, 100);          // 50 - 100 = -50
    check_op(ALUOP_SUB, 25, 25);           // Test για Zero flag
    check_op(ALUOP_SUB, 32'h80000000, 1);  // Test Υπερχείλισης (MIN_INT - 1)
    
    // --- TEST 3: ALUOP_MUL (Πολλαπλασιασμός) ---
    check_op(ALUOP_MUL, 10, 5);            // 10 * 5 = 50
    check_op(ALUOP_MUL, 10, -5);           // 10 * -5 = -50
    check_op(ALUOP_MUL, 32'h0001_0000, 32'h0001_0000); // 2^16 * 2^16 = 2^32 (Υπερχείλιση)

    // --- TEST 4: Λογικές Πράξεις ---
    check_op(ALUOP_AND,  32'h0F0F0F0F, 32'hFFFF0000); 
    check_op(ALUOP_OR,   32'h0F0F0F0F, 32'hFFFF0000); 
    check_op(ALUOP_XOR,  32'h0F0F0F0F, 32'hFFFF0000); 
    check_op(ALUOP_NAND, 32'h0F0F0F0F, 32'hFFFF0000); 
    check_op(ALUOP_NOR,  32'h0F0F0F0F, 32'hFFFF0000); 
    
    // --- TEST 5: Ολισθήσεις (Shifts) ---
    check_op(ALUOP_LOG_SHFT_LEFT,    32'h0000000F, 4); 
    check_op(ALUOP_ARTHM_SHFT_LEFT,  32'h0000000F, 4); 
    check_op(ALUOP_LOG_SHFT_RIGHT,   32'hF000000A, 4); // Λογική
    check_op(ALUOP_ARTHM_SHFT_RIGHT, 32'hF000000A, 4); // Αριθμητική

    $display("--- ΤΕΛΟΣ TESTBENCH ---");
    #20; 
    $finish; 
  end


  /* ΒΟΗΘΗΤΙΚΟ TASK ΓΙΑ ΕΚΤΥΠΩΣΗ */
  task check_op(input [3:0] op, input [31:0] a, input [31:0] b);
    string op_name;
    
    case(op)
      ALUOP_AND:  op_name = "AND ";
      ALUOP_OR:   op_name = "OR  ";
      ALUOP_NOR:  op_name = "NOR ";
      ALUOP_NAND: op_name = "NAND";
      ALUOP_XOR:  op_name = "XOR ";
      ALUOP_SUM:  op_name = "SUM ";
      ALUOP_SUB:  op_name = "SUB ";
      ALUOP_MUL:  op_name = "MUL ";
      ALUOP_LOG_SHFT_RIGHT:   op_name = "LSR ";
      ALUOP_LOG_SHFT_LEFT:    op_name = "LSL ";
      ALUOP_ARTHM_SHFT_RIGHT: op_name = "ASR ";
      ALUOP_ARTHM_SHFT_LEFT:  op_name = "ASL ";
      default:    op_name = "??? ";
    endcase
    
    tb_alu_op = op;
    tb_op1 = a;
    tb_op2 = b;
    
    #10; 
    
    // --- ΑΛΛΑΓΗ ΕΔΩ ---
    // Χρησιμοποιούμε %8h για να δείξει 8 δεκαεξαδικά ψηφία
    $display("[%0t ns] OP: %s | op1=%8h, op2=%8h | result=%8h | ovf=%b | zero=%b",
             $time, op_name, tb_op1, tb_op2, tb_result, tb_ovf, tb_zero);
  endtask

endmodule
