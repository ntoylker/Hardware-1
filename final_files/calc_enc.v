module calc_enc(
    // --- Inputs ---
    input  btnl,
    input  btnr,
    input  btnd,
    
    // --- Output ---
    output [3:0] alu_op
);

    // --- Wires for alu_op[0] (Figure 2) ---
    wire w0_nL, w0_nD, w0_w1, w0_w2, w0_w3;
    
    // --- Wires for alu_op[1] (Figure 3) ---
    wire w1_nR, w1_nD, w1_w1;
    
    // --- Wires for alu_op[2] (Figure 4) ---
    wire w2_nL, w2_w1, w2_w2_xor, w2_w3_nxor, w2_w4;
    
    // --- Wires for alu_op[3] (Figure 5) ---
    wire w3_w1, w3_w2;

    
    // --- Logic for alu_op[0] (from Figure 2) ---
    // Expression: (NOT(btnl) AND btnd) OR (btnl AND btnr AND NOT(btnd))
    not g0_not1 (w0_nL, btnl);
    not g0_not2 (w0_nD, btnd);
    and g0_and1 (w0_w1, w0_nL, btnd);
    and g0_and2 (w0_w2, btnl, btnr);
    and g0_and3 (w0_w3, w0_w2, w0_nD);
    or  g0_or1  (alu_op[0], w0_w1, w0_w3);
    

    // --- Logic for alu_op[1] (from Figure 3) ---
    // Expression: btnl AND (NOT(btnr) OR NOT(btnd))
    not g1_not1 (w1_nR, btnr);
    not g1_not2 (w1_nD, btnd);
    or  g1_or1  (w1_w1, w1_nR, w1_nD);
    and g1_and1 (alu_op[1], btnl, w1_w1);


    // --- Logic for alu_op[2] (from Figure 4) ---
    // Expression: (NOT(btnl) AND btnr) OR (btnl AND (btnr XNOR btnd))
    not g2_not1 (w2_nL, btnl);
    and g2_and1 (w2_w1, w2_nL, btnr);
    xor g2_xor1 (w2_w2_xor, btnr, btnd);
    not g2_not2 (w2_w3_nxor, w2_w2_xor); // (NOT XOR) is XNOR
    and g2_and2 (w2_w4, btnl, w2_w3_nxor);
    or  g2_or1  (alu_op[2], w2_w1, w2_w4);


    // --- Logic for alu_op[3] (from Figure 5) ---
    // Expression: (btnl AND btnr) OR (btnl AND btnd)
    and g3_and1 (w3_w1, btnl, btnr);
    and g3_and2 (w3_w2, btnl, btnd);
    or  g3_or1  (alu_op[3], w3_w1, w3_w2);
    
endmodule
