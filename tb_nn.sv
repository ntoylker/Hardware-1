//
// File: tb_nn.v
// Description: Sanity check testbench for the 'nn' module.
//              Executes a single forward pass to check FSM operation.
//

`timescale 1ns / 1ps

module tb_nn;

    // --- Parameters ---
    parameter DATAWIDTH  = 32;
    parameter CLK_PERIOD = 10; // 10 ns clock period
    
    // FSM Latency: PRE(1) + INPUT(1) + OUT(2) + POST(1) = 5 cycles
    parameter FSM_LATENCY = 5; 
    
    // Load Time: 1 cycle (Request R0,R1) + 8 cycles (Write R0-R15) = 9 cycles
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
        $display("Final Output (hex): %h", dut_final_output);
        $display("Final Output (dec): %d", dut_final_output);
        $display("Overflow Flag:    %b", dut_total_ovf);
        $display("Zero Flag:        %b", dut_total_zero);
        $display("OVF Stage:        %b", dut_ovf_fsm_stage);
        $display("Zero Stage:       %b", dut_zero_fsm_stage);
        $display("--------------------------------");


        #20;
        $display("--- Test Finished ---");
        $finish;
    end

endmodule
