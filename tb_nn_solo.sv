//
// File: tb_nn.v
// Description: Sanity check testbench for the 'nn' module.
//              Executes a single forward pass and COMPARES 
//              against the 'nn_model' reference function.
//

`timescale 1ns / 1ps

module tb_nn;

    // --- Parameters ---
    parameter DATAWIDTH  = 32;
    parameter CLK_PERIOD = 10; // 10 ns clock period
    
    // FSM Latency: PRE(1) + INPUT(1) + OUT(2) + POST(1) = 5 cycles
    parameter FSM_LATENCY = 5; 
    
    // Load Time: 1 cycle (Req R0,R1) + 8 cycles (Write R0-R15) = 9 cycles
    // (This is the "safe" non-optimized version)
    parameter LOAD_CYCLES = 9;

    // --- Testbench Signals ---
    logic clk;
    logic resetn;
    logic enable;
    logic signed [DATAWIDTH-1:0] tb_input_1;
    logic signed [DATAWIDTH-1:0] tb_input_2;

    // Outputs from DUT
    wire signed [DATAWIDTH-1:0] dut_final_output;
    wire dut_total_ovf;
    wire dut_total_zero;
    wire [2:0] dut_ovf_fsm_stage;
    wire [2:0] dut_zero_fsm_stage;
    
    // --- ADDED: Signal for Reference Model ---
    logic signed [DATAWIDTH-1:0] expected_output;


    // --- Clock Generator ---
    initial begin
        clk = 1'b0;
        forever # (CLK_PERIOD / 2) clk = ~clk;
    end

    // --- DUT Instantiation ---
    nn #(
        .DATAWIDTH(DATAWIDTH)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .enable(enable),
        .input_1(tb_input_1),
        .input_2(tb_input_2),
        .final_output(dut_final_output),
        .total_ovf(dut_total_ovf),
        .total_zero(dut_total_zero),
        .ovf_fsm_stage(dut_ovf_fsm_stage),
        .zero_fsm_stage(dut_zero_fsm_stage)
    );

//*****************************************************************************************
// --- 8< --- ADDED: REFERENCE MODEL (nn_model) --- 8< ---
//*****************************************************************************************
function [31:0] nn_model (input [31:0] input_1, input [31:0] input_2);

    // Internal variables
    reg [7:0] ROM [0:511];
    reg [31:0] inter1, inter2;
    reg [63:0] mul1, mul2, mac1, mac2, mul3, mul4, mac3, mac4;
    
    reg ovf_mul1, ovf_mul2, ovf_mul3, ovf_mul4, ovf_mac1, ovf_mac2, ovf_mac3, ovf_mac4, ovf_sb;

    reg [31:0] weight1, weight2, weight3, weight4, bias1, bias2, bias3;
    reg [31:0] shift_bias1, shift_bias2, shift_bias3;
    reg [63:0] result;
    integer addr;

    begin
        addr = 8;
        // -----    Load the rom.data file  -----
        $readmemb("rom_bytes.data", ROM);

        // -----    Pre-processing layer     -----
        shift_bias1 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        shift_bias2 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;

        inter1 = $signed(input_1) >>> shift_bias1; 
        inter2 = $signed(input_2) >>> shift_bias2;

        // -----    Neural Network Input Layer     -----
        // Load weights and biases from ROM
        weight1 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        bias1 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;

        weight2 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        bias2 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;

        // Neuron calculations
        mul1 = $signed({{32{inter1[31]}}, inter1}) * $signed({{32{weight1[31]}}, weight1});
        ovf_mul1 = (mul1[63:32] != {32{mul1[31]}})? 1'b1 : 1'b0;
        
        mac1 = $signed({{32{mul1[31]}}, mul1[31:0]}) + $signed({{32{bias1[31]}}, bias1});
        ovf_mac1 = (mac1[63:32] != {32{mac1[31]}})? 1'b1 : 1'b0;

        mul2 = $signed({{32{inter2[31]}}, inter2}) * $signed({{32{weight2[31]}}, weight2});
        ovf_mul2 = (mul2[63:32] != {32{mul2[31]}})? 1'b1 : 1'b0;

        mac2 = $signed({{32{mul2[31]}}, mul2[31:0]}) + $signed({{32{bias2[31]}}, bias2});
        ovf_mac2 = (mac2[63:32] != {32{mac2[31]}})? 1'b1 : 1'b0;

        // -----    Neural Network Output Layer     -----
        // Load weights and bias from ROM
        weight3 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        weight4 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        bias3 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;

        // Neuron calculation
        mul3 = $signed({{32{mac1[31]}}, mac1[31:0]}) * $signed({{32{weight3[31]}}, weight3});
        ovf_mul3 = (mul3[63:32] != {32{mul3[31]}})? 1'b1 : 1'b0;

        mul4 = $signed({{32{mac2[31]}}, mac2[31:0]}) * $signed({{32{weight4[31]}}, weight4});
        ovf_mul4 = (mul4[63:32] != {32{mul4[31]}})? 1'b1 : 1'b0;

        mac3 = $signed({{32{mul3[31]}}, mul3[31:0]}) + $signed({{32{bias3[31]}}, bias3});
        ovf_mac3 = (mac3[63:32] != {32{mac3[31]}})? 1'b1 : 1'b0;

        mac4 = $signed({{32{mul4[31]}}, mul4[31:0]}) + $signed({{32{mac3[31]}}, mac3[31:0]});
        ovf_mac4 = (mac4[63:32] != {32{mac4[31]}})? 1'b1 : 1'b0;

        // -----    Post-processing layer   -----
        shift_bias3 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        result = $signed(mac4[31:0]) <<< shift_bias3;

        // -----    Overflow check and final output    -----
        ovf_sb = (result[63:32] != {32{result[31]}})? 1'b1 : 1'b0;

        if (ovf_mul1 | ovf_mul2 | ovf_mul3 | ovf_mul4 | ovf_mac1 | ovf_mac2 | ovf_mac3 | ovf_mac4 | ovf_sb) begin
            // If overflow occurred in any operation, set result the max value
            nn_model = 32'hFFFFFFFF;
        end
        else
        begin
            // Return the final output
            nn_model = result[31:0];
        end
    end
endfunction
//*****************************************************************************************
// --- 8< --- END: REFERENCE MODEL (nn_model) --- 8< ---
//*****************************************************************************************


    // --- Main Stimulus Sequence ---
    initial begin
        $display("--- Start: Simple Forward Pass Test ---");
        
        // VCD Dump settings
        $dumpfile("nn_sanity_dump.vcd");
        $dumpvars(0, tb_nn);

        // 1. Initialization & Reset
        resetn = 1'b0; // Assert reset
        enable = 1'b0;
        tb_input_1 = '0;
        tb_input_2 = '0;
        
        // Wait 2 cycles for stability
        repeat (2) @(posedge clk);
        resetn = 1'b1; // De-assert reset
        
        // 2. Wait for STATE_LOAD to complete
        // We must wait (LOAD_CYCLES) + 1 cycle to transition to IDLE.
        $display("[%0t ns] Reset released. Waiting for STATE_LOAD (%0d cycles)...", 
                 $time, LOAD_CYCLES + 1);
        repeat (LOAD_CYCLES + 1) @(posedge clk); 
        
        $display("[%0t ns] FSM is now in IDLE.", $time);
        
        // Wait one more cycle for safety
        @(posedge clk);
        
        // 3. Apply inputs and start the FSM
        $display("[%0t ns] Applying inputs and asserting 'enable'.", $time);
        tb_input_1 = 32'd100; // Example input 1
        tb_input_2 = 32'd50;  // Example input 2
        enable = 1;
        
        // --- ADDED: Calculate expected output from model ---
        expected_output = nn_model(tb_input_1, tb_input_2);
        
        @(posedge clk); // FSM moves from IDLE to STATE_PRE_PROC
        
        // De-assert enable
        enable = 0;
        $display("[%0t ns] Enable de-asserted. Waiting for FSM latency (%0d cycles)...", 
                 $time, FSM_LATENCY);

        // 4. Wait for the FSM to complete its 5-cycle pipeline
        repeat (FSM_LATENCY) @(posedge clk);
        
        // 5. Check the result (after the 5th cycle)
        #1; // Wait 1ps for combinatorial outputs to stabilize
        
        $display("--- FORWARD PASS COMPLETE ---");
        $display("Timestamp: %0t ns", $time);
        $display("Inputs: %d, %d", tb_input_1, tb_input_2);
        $display("--------------------------------");
        
        // --- MODIFIED: Added comparison ---
        $display("DUT Output (Hardware):   %d (%h)", dut_final_output, dut_final_output);
        $display("Model Output (Software): %d (%h)", expected_output, expected_output);
        
        if (dut_final_output === expected_output) begin
            $display("[PASS] Results match!");
        end else begin
            $error("[FAIL] Results DO NOT match!");
        end
        $display("--------------------------------");
        // --- END OF MODIFICATION ---
        
        $display("Overflow Flag (DUT):    %b", dut_total_ovf);
        $display("Zero Flag (DUT):        %b", dut_total_zero);
        $display("OVF Stage (DUT):        %b", dut_ovf_fsm_stage);
        $display("Zero Stage (DUT):       %b", dut_zero_fsm_stage);
        $display("--------------------------------");


        #20;
        $display("--- Test Finished ---");
        $finish;
    end

endmodule
