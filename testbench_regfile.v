//
// Αρχείο: tb_regfile.sv
// Περιγραφή: Testbench για το 'regfile' της Άσκης 3. (ΔΙΟΡΘΩΜΕΝΟ)
//

`timescale 1ns / 1ps

module tb_regfile;

    // --- Παράμετροι ---
    parameter CLK_PERIOD = 10;
    parameter DATAWIDTH = 32;
    
    // --- ΣΤΑΘΕΡΕΣ ΓΙΑ ΤΑ TEST DATA ---
    localparam [DATAWIDTH-1:0] DATA_A     = 32'hAAAAAAAA;
    localparam [DATAWIDTH-1:0] DATA_B     = 32'hBBBBBBBB;
    localparam [DATAWIDTH-1:0] DATA_C     = 32'hCCCCCCCC;
    localparam [DATAWIDTH-1:0] DATA_D     = 32'hDDDDDDDD;
    localparam [DATAWIDTH-1:0] DATA_W1    = 32'hFACECAFE;
    localparam [DATAWIDTH-1:0] DATA_W2    = 32'hDEADBEEF;
    localparam [DATAWIDTH-1:0] NEW_DATA_2 = 32'h22222222;
    localparam [DATAWIDTH-1:0] NEW_DATA_5 = 32'h55555555;
    
    // --- Σήματα Testbench ---
    logic clk;
    logic resetn;
    logic write;
    
    logic [3:0] readReg1, readReg2, readReg3, readReg4;
    logic [3:0] writeReg1, writeReg2;
    logic [DATAWIDTH-1:0] writeData1, writeData2;

    logic [DATAWIDTH-1:0] readData1, readData2, readData3, readData4;

    // --- Σύνδεση του 'regfile' (DUT) ---
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

    // --- Παραγωγός Ρολογιού ---
    initial begin
        clk = 0;
        forever # (CLK_PERIOD / 2) clk = ~clk;
    end

    // --- Βοηθητικό Task για Έλεγχο Εξόδων ---
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

    // --- Βοηθητικό Task για Κύκλο Εγγραφής ---
    task write_cycle(
        input [3:0] addr1, input [DATAWIDTH-1:0] data1,
        input [3:0] addr2, input [DATAWIDTH-1:0] data2
    );
        // Ρυθμίζουμε τα σήματα *πριν* την ακμή
        write = 1;
        writeReg1 = addr1; writeData1 = data1;
        writeReg2 = addr2; writeData2 = data2;
        
        // Περιμένουμε την ακμή
        @ (posedge clk); 
        
        // **ΔΙΟΡΘΩΣΗ: Απενεργοποιούμε το write *ΜΕΤΑ* την ακμή**
        #1; 
        write = 0; 
        
        $display("[%0t ns] WRITE: R%0d <= %h | R%0d <= %h", $time, addr1, data1, addr2, data2);
    endtask


    // --- Κύρια Ακολουθία Ελέγχου (Stimulus) ---
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_regfile);
        $display("--- START TESTBENCH FOR 'regfile' ---");

        // Αρχικοποίηση σημάτων
        resetn = 1; 
        write = 0;
        readReg1 = 0; readReg2 = 0; readReg3 = 0; readReg4 = 0;
        writeReg1 = 0; writeReg2 = 0;
        writeData1 = 'x; writeData2 = 'x;
        
        @ (posedge clk);

        // --- Test 1: Ασύγχρονος Μηδενισμός ---
        $display("\n--- Test 1: ASYXRONOS MHDENISMOS (resetn=0) ---");
        resetn <= 0; 
        
        readReg1 = 0; readReg2 = 5; readReg3 = 10; readReg4 = 15;
        check_read_data("Async Reset Check", 32'h0, 32'h0, 32'h0, 32'h0);
        
        #5; 
        resetn <= 1; 
        $display("[%0t ns] Reset De-asserted (resetn=1)", $time);
        @ (posedge clk); 

        // --- Test 2: Βασική Εγγραφή & Ανάγνωση ---
        $display("\n--- Test 2: BASIKI EGGRAFH & ANAGNWSH ---");
        
        write_cycle(1, DATA_A, 2, DATA_B);
        write_cycle(3, DATA_C, 4, DATA_D);

        readReg1 = 1; readReg2 = 2; readReg3 = 3; readReg4 = 4;
        check_read_data("Read R1-R4", DATA_A, DATA_B, DATA_C, DATA_D);

        readReg1 = 4; readReg2 = 0; readReg3 = 2; readReg4 = 3;
        check_read_data("Read R4,R0,R2,R3", DATA_D, 32'h0, DATA_B, DATA_C);


        // --- Test 3: Ταυτόχρονη Εγγραφή (Write Collision) ---
        $display("\n--- Test 3: TAUTOXRONH EGGRAFH (Collision) -> R5 ---");

        write_cycle(5, DATA_W1, 5, DATA_W2);
        
        readReg1 = 5; readReg2 = 5; readReg3 = 5; readReg4 = 5;
        check_read_data("Check Collision R5", DATA_W2, DATA_W2, DATA_W2, DATA_W2);


        // --- Test 4.1: Λογική Bypass (R2, R5) ---
        $display("\n--- Test 4.1: LOGIKH Bypass (R2, R5) ---");
        
        // Τώρα (με το Test 3 διορθωμένο) έχουμε: 
        // R1=A, R2=B, R3=C, R4=D, R5=DEADBEEF
        
        readReg1 = 1; readReg2 = 2; readReg3 = 3; readReg4 = 5;
        $display("[%0t ns] Ruthmisi anagnosis gia R1, R2, R3, R5...", $time);
        
        // Έλεγχος *πριν* το bypass (τιμές από μνήμη)
        check_read_data("Pre-Bypass 4.1 Check", DATA_A, DATA_B, DATA_C, DATA_W2);

        $display("[%0t ns] Energopoihsh Bypass (write=1) gia R2, R5...", $time);
        write = 1;
        writeReg1 = 2; writeData1 = NEW_DATA_2; 
        writeReg2 = 5; writeData2 = NEW_DATA_5; 
        
        // Έλεγχος *κατά* το bypass (συνδυαστικές τιμές)
        check_read_data("Bypass 4.1 Check", DATA_A, NEW_DATA_2, DATA_C, NEW_DATA_5);

        // **ΔΙΟΡΘΩΣΗ: Ολοκληρώνουμε τον 1ο κύκλο για να αποθηκευτούν τα R2, R5**
        @ (posedge clk);
        #1; 
        write = 0; 
        $display("[%0t ns] Oloklirothike o kuklos eggrafhs R2, R5.", $time);


        // --- Test 4.2: Bypass Collision (W1 vs W2) -> R8 ---
        $display("\n--- Test 4.2: Bypass Collision (W1 vs W2) -> R8 ---");
        
        // Οι R1, R2, R3, R4, R5 έχουν πλέον τις τιμές: A, NEW_DATA_2, C, D, NEW_DATA_5
        
        // Διαβάζουμε R8, R8, R1 (παλιό), R2 (νέο)
        readReg1 = 8; readReg2 = 8; readReg3 = 1; readReg4 = 2;
        
        // Έλεγχος *πριν* το bypass: R8=0 (από reset), R1=A, R2=NEW_DATA_2
        check_read_data("Pre-Bypass 4.2 Check", 32'h0, 32'h0, DATA_A, NEW_DATA_2);

        $display("[%0t ns] Energopoihsh Bypass (write=1) gia R8, R8...", $time);
        write = 1;
        writeReg1 = 8; writeData1 = 32'h88881111; // Αυτό πρέπει να χάσει
        writeReg2 = 8; writeData2 = 32'h88882222; // Αυτό πρέπει να κερδίσει
        
        // Έλεγχος *κατά* το bypass (συνδυαστικές τιμές)
        check_read_data("Bypass Collision 4.2 Check", 
                        32'h88882222, 32'h88882222, DATA_A, NEW_DATA_2);

        // **ΔΙΟΡΘΩΣΗ: Ολοκληρώνουμε τον 2ο κύκλο για να αποθηκευτεί το R8**
        @ (posedge clk);
        #1; 
        write = 0; 
        $display("[%0t ns] Oloklirothike o kuklos eggrafhs R8.", $time);

        // --- Test 5: Τελικός Έλεγχος Αποθήκευσης ---
        $display("\n--- Test 5: TELIKOS ELEGXOS APOHKEYSHS ---");
        
        // Τελικός έλεγχος: Οι τιμές (NEW_DATA_2, NEW_DATA_5, 88882222) 
        // είναι τώρα μόνιμα αποθηκευμένες;
        readReg1 = 2; readReg2 = 5; readReg3 = 8; readReg4 = 1;
        check_read_data("Post-Bypass Storage Check", 
                        NEW_DATA_2, NEW_DATA_5, 32'h88882222, DATA_A);
        
        $display("\n--- OLA TA TEST PERASAN ---");
        #20;
        $finish;
    end

endmodule

