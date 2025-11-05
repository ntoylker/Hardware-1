//
// File: tb_nn.v
// Description: Full testbench for the 'nn' module (Exercise 4).
//              Corrects $urandom_range logic for signed ranges.
//              Now prints DUT flags (OVF/ZERO stages) on every test.
//

`timescale 1ns / 1ps

module tb_nn;

    // --- Parameters ---
    parameter DATAWIDTH  = 32;
    parameter CLK_PERIOD = 10; // 10 ns clock period
    
    // FSM Latency: PRE(1) + INPUT(1) + OUT(2) + POST(1) = 5 cycles
    parameter FSM_LATENCY = 5; 
    
    // Load Time: 1 cycle (Req R0,R1) + 8 cycles (Write R0-R15) = 9 cycles
    parameter LOAD_CYCLES = 9;
    
    // Number of repetitions as per specification
    parameter NUM_REPETITIONS = 100;

    // --- Test Range Constants ---
    localparam [DATAWIDTH-1:0] MAX_POS = 32'h7FFFFFFF;
    localparam [DATAWIDTH-1:0] MAX_POS_HALF = 32'h30000000;
    localparam [DATAWIDTH-1:0] MAX_NEG = 32'h80000000;
    localparam [DATAWIDTH-1:0] MAX_NEG_HALF = 32'hC0000000;
    
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

    // --- Reference Model & Counters ---
    logic signed [DATAWIDTH-1:0] expected_output;
    integer pass_count = 0;
    integer total_count = 0;

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
// --- REFERENCE MODEL (nn_model) ---
//*****************************************************************************************
function [31:0] nn_model (input [31:0] input_1, input [31:0] input_2);
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
        $readmemb("rom_bytes.data", ROM);
        shift_bias1 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        shift_bias2 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        inter1 = $signed(input_1) >>> shift_bias1; 
        inter2 = $signed(input_2) >>> shift_bias2;
        weight1 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        bias1 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        weight2 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        bias2 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        mul1 = $signed({{32{inter1[31]}}, inter1}) * $signed({{32{weight1[31]}}, weight1});
        ovf_mul1 = (mul1[63:32] != {32{mul1[31]}})? 1'b1 : 1'b0;
        mac1 = $signed({{32{mul1[31]}}, mul1[31:0]}) + $signed({{32{bias1[31]}}, bias1});
        ovf_mac1 = (mac1[63:32] != {32{mac1[31]}})? 1'b1 : 1'b0;
        mul2 = $signed({{32{inter2[31]}}, inter2}) * $signed({{32{weight2[31]}}, weight2});
        ovf_mul2 = (mul2[63:32] != {32{mul2[31]}})? 1'b1 : 1'b0;
        mac2 = $signed({{32{mul2[31]}}, mul2[31:0]}) + $signed({{32{bias2[31]}}, bias2});
        ovf_mac2 = (mac2[63:32] != {32{mac2[31]}})? 1'b1 : 1'b0;
        weight3 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        weight4 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        bias3 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        mul3 = $signed({{32{mac1[31]}}, mac1[31:0]}) * $signed({{32{weight3[31]}}, weight3});
        ovf_mul3 = (mul3[63:32] != {32{mul3[31]}})? 1'b1 : 1'b0;
        mul4 = $signed({{32{mac2[31]}}, mac2[31:0]}) * $signed({{32{weight4[31]}}, weight4});
        ovf_mul4 = (mul4[63:32] != {32{mul4[31]}})? 1'b1 : 1'b0;
        mac3 = $signed({{32{mul3[31]}}, mul3[31:0]}) + $signed({{32{bias3[31]}}, bias3});
        ovf_mac3 = (mac3[63:32] != {32{mac3[31]}})? 1'b1 : 1'b0;
        mac4 = $signed({{32{mul4[31]}}, mul4[31:0]}) + $signed({{32{mac3[31]}}, mac3[31:0]});
        ovf_mac4 = (mac4[63:32] != {32{mac4[31]}})? 1'b1 : 1'b0;
        shift_bias3 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]}; addr = addr + 4;
        result = $signed(mac4[31:0]) <<< shift_bias3;
        ovf_sb = (result[63:32] != {32{result[31]}})? 1'b1 : 1'b0;
        if (ovf_mul1 | ovf_mul2 | ovf_mul3 | ovf_mul4 | ovf_mac1 | ovf_mac2 | ovf_mac3 | ovf_mac4 | ovf_sb) begin
            nn_model = 32'hFFFFFFFF;
        end else begin
            nn_model = result[31:0];
        end
    end
endfunction
//*****************************************************************************************
// --- END: REFERENCE MODEL (nn_model) ---
//*****************************************************************************************


    // --- Helper Task for Checking ---
    // This task executes one full test cycle
    task check_test(
        input string test_name,
        input signed [31:0] in1, 
        input signed [31:0] in2
    );
        
        total_count++;
        
        // 1. Apply inputs and enable
        @(posedge clk);
        tb_input_1 = in1;
        tb_input_2 = in2;
        enable = 1;

        // 2. Calculate expected value (immediately)
        expected_output = nn_model(in1, in2);
        
        @(posedge clk); // FSM moves from IDLE to STATE_PRE_PROC
        
        // 3. De-assert enable
        enable = 0;
        
        // 4. Wait for the FSM to complete its 5-cycle pipeline
        repeat (FSM_LATENCY) @(posedge clk);
        
        // 5. Check the result (after the 5th cycle)
        #1; // Wait 1ps for combinatorial outputs to stabilize
        
        // --- 8< --- MODIFIED: Display Logic --- 8< ---
        $display("       Inputs: %h(%d), %h(%d)", in1, in1, in2, in2);
        $display("       DUT Output: %h(%d) | Model Output: %h(%d)", 
                 dut_final_output, dut_final_output, expected_output, expected_output);

        if (dut_final_output === expected_output) begin
            $display("[PASS] (Test %0d) %s", total_count, test_name);
            pass_count++;
        end else begin
            // Error message as specified
            $error("[FAIL] (Test %0d) %s @ time %0t ns", total_count, test_name, $time);
            $error("       Inputs: %h(%d), %h(%d)", in1, in1, in2, in2);
            $error("       Expected: %h(%d)", expected_output, expected_output);
            $error("       Got (DUT): %h(%d)", dut_final_output, dut_final_output);
        end
        
        // Always print flags
        $display("       DUT Flags: OVF=%b (Stage:%b), ZERO=%b (Stage:%b)", 
                 dut_total_ovf, dut_ovf_fsm_stage, 
                 dut_total_zero, dut_zero_fsm_stage);
        $display("       -------------------------------------------------");
        // --- 8< --- END OF MODIFICATION --- 8< ---
        
        // Wait 2 cycles for FSM to be stable in IDLE before next test
        repeat(2) @(posedge clk);
        
    endtask
    
    // --- 8< --- NEW: Helper Function for Signed Random --- 8< ---
    // Generates a signed random number in the range [min_val, max_val]
    function automatic signed [31:0] get_signed_random_range(
        input signed [31:0] min_val, 
        input signed [31:0] max_val
    );
        logic [31:0] range_span;
        range_span = max_val - min_val + 1;
        return min_val + $urandom_range(range_span - 1, 0);
    endfunction
    

    // --- Main Stimulus Sequence ---
    integer i;
    
    initial begin
        $display("--- Start: Full Randomized Testbench ---");
        
        // VCD Dump settings
        $dumpfile("nn_full_test_dump.vcd");
        $dumpvars(0, tb_nn);

        // 1. Initialization & Reset
        resetn = 1'b0; // Assert reset
        enable = 1'b0;
        tb_input_1 = '0;
        tb_input_2 = '0;
        
        repeat (2) @(posedge clk);
        resetn = 1'b1; // De-assert reset
        
        // 2. Wait for STATE_LOAD to complete
        $display("[%0t ns] Reset released. Waiting for STATE_LOAD (%0d cycles)...", 
                 $time, LOAD_CYCLES + 1);
        repeat (LOAD_CYCLES + 1) @(posedge clk); 
        
        $display("[%0t ns] FSM is now in IDLE. Starting %0d test repetitions...", $time, NUM_REPETITIONS);
        
        @(posedge clk);
        
        // 3. Run the 100 repetitions
        for (i = 0; i < NUM_REPETITIONS; i = i + 1) begin
            
            $display("--- Repetition %0d of %0d ---", i+1, NUM_REPETITIONS);
            
            // Test 1: Normal Range [-4096, 4095]
            // We use the new 'get_signed_random_range' function here
            check_test(
                "Normal Range",
                get_signed_random_range(-4096, 4095), 
                get_signed_random_range(-4096, 4095)
            );
            
            // Test 2: Positive Overflow Range
            // This range works fine as-is
            check_test(
                "Positive Overflow Range",
                $urandom_range(MAX_POS, MAX_POS_HALF), 
                $urandom_range(MAX_POS, MAX_POS_HALF)
            );
            
            // Test 3: Negative Overflow Range
            // This range also works fine as-is
            check_test(
                "Negative Overflow Range",
                $urandom_range(MAX_NEG_HALF, MAX_NEG), 
                $urandom_range(MAX_NEG_HALF, MAX_NEG)
            );
            
        end // end of for loop

        // 4. Final Report
        $display("\n--- All Repetitions Finished ---");
        // Print "number of PASS/ number of test cases"
        $display("Final Score: %0d / %0d tests passed.", pass_count, total_count);
        
        if (pass_count == total_count) begin
          $display("--- ALL TESTS PASSED ---\n\n");
        end else begin
            $error("--- FAILURE: %0d / %0d tests failed ---\n\n", 
                   (total_count - pass_count), total_count);
        end

        #20;
        $finish;
    end

endmodule
