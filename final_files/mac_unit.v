module mac_unit (
    // --- Inputs ---
    input signed [31:0] op1, // First input to the multiplication
    input signed [31:0] op2, // Second input to the multiplication
    input signed [31:0] op3, // Input to the addition (bias)

    // --- Outputs ---
    output signed [31:0] total_result, // The final result
    output logic         zero_mul,     // 1 if (op1 * op2) == 0
    output logic         ovf_mul,      // 1 if multiplication overflowed
    output logic         zero_add,     // 1 if total_result == 0
    output logic         ovf_add       // 1 if addition overflowed
);

    // --- 1. Constants for ALU Operations ---
    // These values must match 'alu.v'
    localparam [3:0] ALUOP_SUM = 4'b0100; // Addition Opcode
    localparam [3:0] ALUOP_MUL = 4'b0110; // Multiplication Opcode

    // --- 2. Intermediate Signals ---
    // This wire will connect the output of the 1st ALU (MUL)
    // to the input of the 2nd ALU (ADD).
    wire signed [31:0] mul_result_wire;

    // --- 3. Module Instantiation ---

    // Step A: Multiplication (op1 * op2)
    // "the first will always perform the multiplication operation"
    alu u_alu_mul (
        .op1(op1),
        .op2(op2),
        .alu_op(ALUOP_MUL),

        // Multiplication Outputs
        .result(mul_result_wire), // The result goes to the next step
        .zero(zero_mul),         // MAC 'zero_mul' output
        .ovf(ovf_mul)            // MAC 'ovf_mul' output
    );

    // Step B: Addition ( [multiplication result] + op3 )
    // "the second always the addition operation"
    alu u_alu_add (
        .op1(mul_result_wire), // Input 1 = The result of u_alu_mul
        .op2(op3),
        .alu_op(ALUOP_SUM),

        // Final Outputs
        .result(total_result),   // MAC 'total_result' output
        .zero(zero_add),       // MAC 'zero_add' output
        .ovf(ovf_add)          // MAC 'ovf_add' output
    );

endmodule
