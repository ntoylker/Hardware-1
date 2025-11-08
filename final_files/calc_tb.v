`timescale 1ns / 1ps

module calc_tb;

    // --- Parameters ---
    parameter CLK_PERIOD = 10; // 10ns clock period

    // --- Testbench Signals ---
    logic clk;
    logic btnc;   // Central button (Load accumulator)
    logic btnac;  // All Clear (Synchronous reset)
    logic btnl;   // Left button
    logic btnr;   // Right button
    logic btnd;   // Down button
    logic [15:0] sw; // 16-bit switch input

    wire [15:0] led; // 16-bit LED output (from accumulator)

    // --- Instantiate the Device Under Test (DUT) ---
    // Connects this testbench to the 'calc.v' module
    calc dut (
        .clk(clk),
        .btnc(btnc),
        .btnac(btnac),
        .btnl(btnl),
        .btnr(btnr),
        .btnd(btnd),
        .sw(sw),
        .led(led)
    );
    
    // --- Clock Generator ---
    // Creates a clock signal that flips every 5ns
    initial begin
        clk = 0;
        forever # (CLK_PERIOD / 2) clk = ~clk;
    end

    // --- Helper Task ---
    // This task makes it easy to run one test step.
    // It sets all button/switch inputs, waits for one clock cycle,
    // and then checks if the 'led' output matches the expected value.
    task check_step(
        input b_ac, b_c, b_l, b_r, b_d, // Button states
        input [15:0] sw_val,           // Switch value
        input [15:0] expected_led,     // Expected result on LEDs
        input string op_name           // Name of the operation for logging
    );
        // 1. Set all inputs *before* the clock edge
        btnac = b_ac;
        btnc  = b_c;
        btnl  = b_l;
        btnr  = b_r;
        btnd  = b_d;
        sw    = sw_val;
        
        // 2. Wait for the clock edge
        // This is when the 'accumulator' register in 'calc.v' updates
        @ (posedge clk);
        
        // 3. Wait a tiny amount (#1) for the 'led' output to update
        #1;
        
        // 4. Check the result and print a message
        $display("[%0t ns] Op: %-5s | Btns(AC,C,L,R,D)=%b,%b,%b%b%b | SW=%h | LED=%h",
                 $time, op_name, b_ac, b_c, b_l, b_r, b_d, sw_val, led);
                 
        if (led == expected_led) begin
            $display("    -> PASS: (Expected: %h)", expected_led);
        end else begin
            // Print an error if the 'led' value is wrong
            $error("    -> FAIL: (Expected: %h, Got: %h)", expected_led, led);
        end
    endtask


    // --- Main Test Sequence ---
    // This block runs once at the start of the simulation.
    initial begin
        // VCD file for waveform viewing
        $dumpfile("calc_dump.vcd");
        $dumpvars(0, calc_tb);

        $display("--- STARTING CALCULATOR TESTBENCH ---");
        
        // Wait for the first clock edge to stabilize
        @ (posedge clk);

        // --- Test sequence from the PDF table ---
        
        // 1. Reset (btnac=1)
        //    (b_ac, b_c, b_l, b_r, b_d, sw_val,   expected_led, op_name)
        check_step( 1,   0,   0,   0,   0, 16'hxxxx, 16'h0000,     "RESET");

        // 2. ADD (btnl=0, btnr=1, btnd=0) | Prev=0x0 | SW=0x285a
        //    btnc=1 is needed to load the result
        check_step( 0,   1,   0,   1,   0, 16'h285a, 16'h285a,     "ADD");
        
        // 3. XOR (btnl=1, btnr=1, btnd=1) | Prev=0x285a | SW=0x04c8
        check_step( 0,   1,   1,   1,   1, 16'h04c8, 16'h2c92,     "XOR");
        
        // 4. LSR (btnl=0, btnr=0, btnd=0) | Prev=0x2c92 | SW=0x0005
        check_step( 0,   1,   0,   0,   0, 16'h0005, 16'h0164,     "LSR");
        
        // 5. NOR (btnl=1, btnr=0, btnd=1) | Prev=0x0164 | SW=0xa085
        check_step( 0,   1,   1,   0,   1, 16'ha085, 16'h5e1a,     "NOR");
        
        // 6. MULT (btnl=1, btnr=0, btnd=0) | Prev=0x5e1a | SW=0x07fe
        check_step( 0,   1,   1,   0,   0, 16'h07fe, 16'h13cc,     "MULT");

        // 7. LSL (btnl=0, btnr=0, btnd=1) | Prev=0x13cc | SW=0x0004
        check_step( 0,   1,   0,   0,   1, 16'h0004, 16'h3cc0,     "LSL");
        
        // 8. NAND (btnl=1, btnr=1, btnd=0) | Prev=0x3cc0 | SW=0xfa65
        check_step( 0,   1,   1,   1,   0, 16'hfa65, 16'hc7bf,     "NAND");
        
        // 9. SUB (btnl=0, btnr=1, btnd=1) | Prev=0xc7bf | SW=0xb2e4
        check_step( 0,   1,   0,   1,   1, 16'hb2e4, 16'h14db,     "SUB");

        $display("--- TESTBENCH FINISHED ---");
        #20;
        $finish; // End the simulation
    end

endmodule
