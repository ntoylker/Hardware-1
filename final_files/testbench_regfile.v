`timescale 1ns / 1ps

module tb_regfile;

    // --- Parameters ---
    parameter CLK_PERIOD = 10;
    parameter DATAWIDTH = 32;
    
    // --- CONSTANTS FOR TEST DATA ---
    localparam [DATAWIDTH-1:0] DATA_A     = 32'hAAAAAAAA;
    localparam [DATAWIDTH-1:0] DATA_B     = 32'hBBBBBBBB;
    localparam [DATAWIDTH-1:0] DATA_C     = 32'hCCCCCCCC;
    localparam [DATAWIDTH-1:0] DATA_D     = 32'hDDDDDDDD;
    localparam [DATAWIDTH-1:0] DATA_W1    = 32'hFACECAFE;
    localparam [DATAWIDTH-1:0] DATA_W2    = 32'hDEADBEEF;
    localparam [DATAWIDTH-1:0] NEW_DATA_2 = 32'h22222222;
    localparam [DATAWIDTH-1:0] NEW_DATA_5 = 32'h55555555;
    
    // --- Testbench Signals ---
    logic clk;
    logic resetn;
    logic write;
    
    logic [3:0] readReg1, readReg2, readReg3, readReg4;
    logic [3:0] writeReg1, writeReg2;
    logic [DATAWIDTH-1:0] writeData1, writeData2;

    logic [DATAWIDTH-1:0] readData1, readData2, readData3, readData4;

    // --- Instantiate the 'regfile' (DUT) ---
    regfile #(
        .DATAWIDTH(DATAWIDTH)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .write(write),
        .readReg1(readReg1),
        .readReg2(readReg2),
        .readReg3(readReg3),
        .readReg4(readReg4),
        .writeReg1(writeReg1),
        .writeReg2(writeReg2),
        .writeData1(writeData1),
        .writeData2(writeData2),
        .readData1(readData1),
        .readData2(readData2),
        .readData3(readData3),
        .readData4(readData4)
    );

    // --- Clock Generator ---
    initial begin
        clk = 0;
        forever # (CLK_PERIOD / 2) clk = ~clk;
    end

    // --- Helper Task for Checking Outputs ---
    task check_read_data(
        input string            test_name,
        input [DATAWIDTH-1:0] exp1,
        input [DATAWIDTH-1:0] exp2,
        input [DATAWIDTH-1:0] exp3,
        input [DATAWIDTH-1:0] exp4
    );
        #1; 
        $display("[%0t ns] CHECK: %s", $time, test_name);
        
        if (readData1 !== exp1 || readData2 !== exp2 || readData3 !== exp3 || readData4 !== exp4) begin
            $error("  -> FAIL:");
            $display("     Exp R1: %h, Got: %h %s", exp1, readData1, (readData1 === exp1 ? "" : "<- ERROR"));
            $display("     Exp R2: %h, Got: %h %s", exp2, readData2, (readData2 === exp2 ? "" : "<- ERROR"));
            $display("     Exp R3: %h, Got: %h %s", exp3, readData3, (readData3 === exp3 ? "" : "<- ERROR"));
            $display("     Exp R4: %h, Got: %h %s", exp4, readData4, (readData4 === exp4 ? "" : "<- ERROR"));
        end else begin
            $display("  -> PASS: R1=%h, R2=%h, R3=%h, R4=%h", readData1, readData2, readData3, readData4);
        end
    endtask

    // --- Helper Task for a Write Cycle ---
    task write_cycle(
        input [3:0] addr1, input [DATAWIDTH-1:0] data1,
        input [3:0] addr2, input [DATAWIDTH-1:0] data2
    );
        // Set signals *before* the clock edge
        write = 1;
        writeReg1 = addr1; writeData1 = data1;
        writeReg2 = addr2; writeData2 = data2;
        
        // Wait for the clock edge
        @ (posedge clk); 
        
        // **FIX: De-assert write *after* the clock edge**
        #1; 
        write = 0; 
        
        $display("[%0t ns] WRITE: R%0d <= %h | R%0d <= %h", $time, addr1, data1, addr2, data2);
    endtask


    // --- Main Control Sequence (Stimulus) ---
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_regfile);
        $display("--- START TESTBENCH FOR 'regfile' ---");

        // Initialize signals
        resetn = 1; 
        write = 0;
        readReg1 = 0; readReg2 = 0; readReg3 = 0; readReg4 = 0;
        writeReg1 = 0; writeReg2 = 0;
        writeData1 = 'x; writeData2 = 'x;
        
        @ (posedge clk);

        // --- Test 1: Asynchronous Reset ---
        $display("\n--- Test 1: ASYNCHRONOUS RESET (resetn=0) ---");
        resetn <= 0; 
        
        readReg1 = 0; readReg2 = 5; readReg3 = 10; readReg4 = 15;
        check_read_data("Async Reset Check", 32'h0, 32'h0, 32'h0, 32'h0);
        
        #5; 
        resetn <= 1; 
        $display("[%0t ns] Reset De-asserted (resetn=1)", $time);
        @ (posedge clk); 

        // --- Test 2: Basic Write & Read ---
        $display("\n--- Test 2: BASIC WRITE & READ ---");
        
        write_cycle(1, DATA_A, 2, DATA_B);
        write_cycle(3, DATA_C, 4, DATA_D);

        readReg1 = 1; readReg2 = 2; readReg3 = 3; readReg4 = 4;
        check_read_data("Read R1-R4", DATA_A, DATA_B, DATA_C, DATA_D);

        readReg1 = 4; readReg2 = 0; readReg3 = 2; readReg4 = 15;
        check_read_data("Async Reset Check", 32'h0, 32'h0, 32'h0, 32'h0);
        
        #5; 
        resetn <= 1; 
        $display("[%0t ns] Reset De-asserted (resetn=1)", $time);
        @ (posedge clk); 

        // --- Test 2: Basic Write & Read ---
        $display("\n--- Test 2: BASIC WRITE & READ ---");
        
        write_cycle(1, DATA_A, 2, DATA_B);
        write_cycle(3, DATA_C, 4, DATA_D);

        readReg1 = 1; readReg2 = 2; readReg3 = 3; readReg4 = 4;
        check_read_data("Read R1-R4", DATA_A, DATA_B, DATA_C, DATA_D);

        readReg1 = 4; readReg2 = 0; readReg3 = 2; readReg4 = 3;
        check_read_data("Read R4,R0,R2,R3", DATA_D, 32'h0, DATA_B, DATA_C);


        // --- Test 3: Simultaneous Write (Write Collision) ---
        $display("\n--- Test 3: SIMULTANEOUS WRITE (Collision) -> R5 ---");

        write_cycle(5, DATA_W1, 5, DATA_W2);
        
        readReg1 = 5; readReg2 = 5; readReg3 = 5; readReg4 = 5;
        check_read_data("Check Collision R5", DATA_W2, DATA_W2, DATA_W2, DATA_W2);


        // --- Test 4.1: Bypass Logic (R2, R5) ---
        $display("\n--- Test 4.1: BYPASS LOGIC (R2, R5) ---");
        
        // Now (with Test 3 corrected) we have: 
        // R1=A, R2=B, R3=C, R4=D, R5=DEADBEEF
        
        readReg1 = 1; readReg2 = 2; readReg3 = 3; readReg4 = 5;
        $display("[%0t ns] Setting up read for R1, R2, R3, R5...", $time);
        
        // Check *before* bypass (values from memory)
        check_read_data("Pre-Bypass 4.1 Check", DATA_A, DATA_B, DATA_C, DATA_W2);

        $display("[%0t ns] Activating Bypass (write=1) for R2, R5...", $time);
        write = 1;
        writeReg1 = 2; writeData1 = NEW_DATA_2; 
        writeReg2 = 5; writeData2 = NEW_DATA_5; 
        
        // Check *during* bypass (combinational values)
        check_read_data("Bypass 4.1 Check", DATA_A, NEW_DATA_2, DATA_C, NEW_DATA_5);

        // **FIX: Completing 1st cycle to store R2, R5**
        @ (posedge clk);
        #1; 
        write = 0; 
        $display("[%0t ns] Write cycle for R2, R5 completed.", $time);


        // --- Test 4.2: Bypass Collision (W1 vs W2) -> R8 ---
        $display("\n--- Test 4.2: Bypass Collision (W1 vs W2) -> R8 ---");
        
        // R1, R2, R3, R4, R5 now have the values: A, NEW_DATA_2, C, D, NEW_DATA_5
        
        // Reading R8, R8, R1 (old), R2 (new)
        readReg1 = 8; readReg2 = 8; readReg3 = 1; readReg4 = 2;
        
        // Check *before* bypass: R8=0 (from reset), R1=A, R2=NEW_DATA_2
        check_read_data("Pre-Bypass 4.2 Check", 32'h0, 32'h0, DATA_A, NEW_DATA_2);

        $display("[%0t ns] Activating Bypass (write=1) for R8, R8...", $time);
        write = 1;
        writeReg1 = 8; writeData1 = 32'h88881111; // This one should lose
        writeReg2 = 8; writeData2 = 32'h88882222; // This one should win
        
        // Check *during* bypass (combinational values)
        check_read_data("Bypass Collision 4.2 Check", 
                        32'h88882222, 32'h88882222, DATA_A, NEW_DATA_2);

        // **FIX: Completing 2nd cycle to store R8**
        @ (posedge clk);
        #1; 
        write = 0; 
        $display("[%0t ns] Write cycle for R8 completed.", $time);

        // --- Test 5: Final Storage Check ---
        $display("\n--- Test 5: FINAL STORAGE CHECK ---");
        
        // Final check: Are the values (NEW_DATA_2, NEW_DATA_5, 88882222) 
        // now permanently stored?
        readReg1 = 2; readReg2 = 5; readReg3 = 8; readReg4 = 1;
        check_read_data("Post-Bypass Storage Check", 
                        NEW_DATA_2, NEW_DATA_5, 32'h88882222, DATA_A);
        
        $display("\n--- ALL TESTS PASSED ---");
        #20;
        $finish;
    end

endmodule
