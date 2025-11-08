module calc(
  input clk,
  input btnc,    // Central button (Load)
  input btnac,   // All Clear button (Reset)
  input btnl,
  input btnr,
  input btnd,
  input [15:0] sw,
  output [15:0] led
);

  // --- 1. Accumulator Register ---
  reg [15:0] accumulator;
  
  // --- 2. Internal Wires ---
  wire [31:0] alu_result_wire;   // 32-bit output from ALU
  wire [3:0]  alu_op_wire;       // 4-bit output from calc_enc
  wire signed [31:0] op1_signed; // 32-bit sign-extended op1 to ALU
  wire signed [31:0] op2_signed; // 32-bit sign-extended op2 to ALU
  
  // Unused ALU flags (must be connected)
  wire alu_zero_wire;
  wire alu_ovf_wire;

  // --- 3. Accumulator Logic (Sequential) ---
  // This block runs on the positive edge of the clock
  always @(posedge clk) begin
    // Synchronous reset (as per instructions)
    if (btnac) begin
      accumulator <= 16'b0;
    // Synchronous load (as per instructions)
    end else if (btnc) begin
      // Load the lower 16 bits from the ALU result
      accumulator <= alu_result_wire[15:0];
    end
  end
  
  // Connect the accumulator value to the LED output
  assign led = accumulator;
  
  // --- 4. ALU Input Logic (Combinational) ---
  
  // Sign-extend the 16-bit accumulator to 32 bits for op1
  // Replicates the 15th bit (sign bit) 16 times
  assign op1_signed = { {16{accumulator[15]}}, accumulator };
  
  // Sign-extend the 16-bit switch input to 32 bits for op2
  assign op2_signed = { {16{sw[15]}}, sw };
  
  
  // --- 5. Module Instantiations ---
  
  // Instantiate the structural encoder (calc_enc.v)
  calc_enc u_encoder (
    .btnl(btnl),
    .btnr(btnr),
    .btnd(btnd),
    .alu_op(alu_op_wire) // 4-bit output wire
  );
  
  // Instantiate the ALU (alu.v)
  alu u_alu (
    .op1(op1_signed),      // op1 from sign-extended accumulator
    .op2(op2_signed),      // op2 from sign-extended switches
    .alu_op(alu_op_wire),  // alu_op from encoder
    
    .result(alu_result_wire), // 32-bit result back to accumulator logic
    .zero(alu_zero_wire),
    .ovf(alu_ovf_wire)
  );

endmodule
