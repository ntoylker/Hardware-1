//
// Αρχείο: testbench.sv
// Περιγραφή: Ελέγχει το module 'calc' ακολουθώντας
//            τους πίνακες της εκφώνησης.
//
`timescale 1ns / 1ps

module testbench;

    // Περίοδος Ρολογιού
    parameter CLK_PERIOD = 10;

    // --- Σήματα Testbench ---
    logic clk;
    logic btnc;   // Central (Load)
    logic btnac;  // All Clear (Reset)
    logic btnl;
    logic btnr;
    logic btnd;
    logic [15:0] sw;
    
    wire [15:0] led; // Η έξοδος του accumulator

    // --- Σύνδεση του 'calc' (Device Under Test) ---
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
    
    // --- Παραγωγός Ρολογιού ---
    initial begin
        clk = 0;
        forever # (CLK_PERIOD / 2) clk = ~clk;
    end

    // --- Βοηθητικό Task για Έλεγχο ---
    // Αυτό το task διευκολύνει την αποστολή των σημάτων ελέγχου
    task check_step(
        input b_ac, b_c, b_l, b_r, b_d, // Κατάσταση κουμπιών
        input [15:0] sw_val,           // Τιμή switches
        input [15:0] expected_led,     // Αναμενόμενο αποτέλεσμα
        input string op_name           // Όνομα πράξης για εκτύπωση
    );
        // 1. Ορισμός όλων των εισόδων πριν την ακμή του ρολογιού
        btnac = b_ac;
        btnc  = b_c;
        btnl  = b_l;
        btnr  = b_r;
        btnd  = b_d;
        sw    = sw_val;
        
        // 2. Αναμονή για την ακμή του ρολογιού
        // Εδώ ο accumulator θα πάρει τη νέα τιμή
        @ (posedge clk);
        
        // 3. Μικρή αναμονή για να σταθεροποιηθεί η έξοδος 'led'
        #1;
        
        // 4. Έλεγχος και Εκτύπωση
        $display("[%0t ns] Op: %-5s | Btns(AC,C,L,R,D)=%b,%b,%b%b%b | SW=%h | LED=%h",
                 $time, op_name, b_ac, b_c, b_l, b_r, b_d, sw_val, led);
                 
        if (led == expected_led) begin
            $display("    -> PASS: (Expected: %h)", expected_led);
        end else begin
            // Τυπώνει ΣΦΑΛΜΑ αν η τιμή του led δεν είναι η αναμενόμενη
            $error("    -> FAIL: (Expected: %h, Got: %h)", expected_led, led);
        end
    endtask


    // --- Κύρια Ακολουθία Ελέγχου (Stimulus) ---
    initial begin
        // Ρυθμίσεις για το EDA Playground
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        $display("--- ΕΝΑΡΞΗ TESTBENCH ΓΙΑ 'calc' ---");
        
        // Περιμένουμε την πρώτη ακμή για να είμαστε σταθεροί
        @ (posedge clk);

        // 1. Reset (btnac=1)
        // (b_ac, b_c, b_l, b_r, b_d, sw_val, expected_led, op_name)
        check_step( 1,   0,   0,   0,   0, 16'hxxxx, 16'h0000,  "RESET");

        // --- Πίνακας από 'image_727317.png' ---
        // ΣΗΜΕΙΩΣΗ: Για να φορτωθεί το αποτέλεσμα, το btnc πρέπει να είναι 1
        
        // 2. ADD (0,1,0) | Prev=0x0 | SW=0x285a | Exp=0x285a
        check_step( 0,   1,   0,   1,   0, 16'h285a, 16'h285a,  "ADD");
        
        // 3. XOR (1,1,1) | Prev=0x285a | SW=0x04c8 | Exp=0x2c92
        check_step( 0,   1,   1,   1,   1, 16'h04c8, 16'h2c92,  "XOR");
        
        // 4. LSR (0,0,0) | Prev=0x2c92 | SW=0x0005 | Exp=0x0164
        check_step( 0,   1,   0,   0,   0, 16'h0005, 16'h0164,  "LSR");
        
        // --- Πίνακας από 'image_72c495.png' ---
        
        // 5. NOR (1,0,1) | Prev=0x0164 | SW=0xa085 | Exp=0x5e1a
        check_step( 0,   1,   1,   0,   1, 16'ha085, 16'h5e1a,  "NOR");
        
        // 6. MULT (1,0,0) | Prev=0x5e1a | SW=0x07fe | Exp=0x13cc
        check_step( 0,   1,   1,   0,   0, 16'h07fe, 16'h13cc,  "MULT");

        // 7. LSL (0,0,1) | Prev=0x13cc | SW=0x0004 | Exp=0x3cc0
        check_step( 0,   1,   0,   0,   1, 16'h0004, 16'h3cc0,  "LSL");
        
        // 8. NAND (1,1,0) | Prev=0x3cc0 | SW=0xfa65 | Exp=0xc7bf
        check_step( 0,   1,   1,   1,   0, 16'hfa65, 16'hc7bf,  "NAND");
        
        // 9. SUB (0,1,1) | Prev=0xc7bf | SW=0xb2e4 | Exp=0x14db
        check_step( 0,   1,   0,   1,   1, 16'hb2e4, 16'h14db,  "SUB");

        $display("--- ΤΕΛΟΣ TESTBENCH ---");
        #20;
        $finish;
    end

endmodule

