//
// Αρχείο: nn.sv
// Περιγραφή: Top-level module για το νευρωνικό δίκτυο (Άσκηση 4).
//            Υλοποιεί μια 7-state Moore FSM που ελέγχει τα
//            regfile, rom, 2x alu, και 2x mac_unit.
//


module nn #(
    parameter DATAWIDTH = 32
)(
    // --- Είσοδοι ---
    // Όπως ορίζονται στον πίνακα
    input logic clk,
    input logic resetn, // Ασύγχρονο, active-low reset
    input logic enable, // Σήμα έναρξης υπολογισμού
    input logic signed [DATAWIDTH-1:0] input_1,
    input logic signed [DATAWIDTH-1:0] input_2,

    // --- Έξοδοι ---
    // Όπως ορίζονται στους πίνακες
    output logic signed [DATAWIDTH-1:0] final_output,
    output logic total_ovf,
    output logic total_zero,
    output logic [2:0] ovf_fsm_stage,
    output logic [2:0] zero_fsm_stage
);

    // --- 1. Ορισμός Καταστάσεων FSM (Moore) ---
    typedef enum logic [2:0] {
        STATE_DEACTIVATED = 3'b000, // Κατάσταση Reset
        STATE_LOAD        = 3'b001, // Φόρτωση ROM->RegFile
        STATE_IDLE        = 3'b010, // Αναμονή για enable
        STATE_PRE_PROC    = 3'b011, // Data pre-processing
        STATE_INPUT_LAYER = 3'b100, // Input Layer (Παράλληλο)
        STATE_OUT_LAYER   = 3'b101, // Output Layer (Σειριακό)
        STATE_POST_PROC   = 3'b110  // Data post-processing
    } fsm_state_t;

    fsm_state_t current_state, next_state;

    // --- 2. Μετρητές για Multi-Cycle States ---
    
    // Μετρητής για το STATE_LOAD. Χρειαζόμαστε 9 κύκλους (0-8)
    // 1 (Req R0,R1) + 8 (Write R0-R15) = 9 κύκλοι
    logic [3:0] load_counter; 
    
    // Μετρητής βήματος για το STATE_OUT_LAYER (0 ή 1 = 2 κύκλοι)
    logic output_step; 

    // --- 3. Σταθερές ALU Opcodes (από alu.sv) ---
    localparam [3:0] OP_LSL  = 4'b0001; // LOG_SHFT_LEFT
    localparam [3:0] OP_ASR  = 4'b0010; // ARTHM_SHFT_RIGHT

    // --- 4. Ενδιάμεσοι Καταχωρητές (Datapath Memory) ---
    // Υλοποίηση της επιλογής "ενδιάμεσοι registers"
    logic signed [DATAWIDTH-1:0] inter_1_reg, inter_1_next;
    logic signed [DATAWIDTH-1:0] inter_2_reg, inter_2_next;
    logic signed [DATAWIDTH-1:0] inter_3_reg, inter_3_next;
    logic signed [DATAWIDTH-1:0] inter_4_reg, inter_4_next;
    logic signed [DATAWIDTH-1:0] temp_result_reg, temp_result_next;
    logic signed [DATAWIDTH-1:0] inter_5_reg, inter_5_next;
    logic signed [DATAWIDTH-1:0] final_output_reg, final_output_next;
    
    // Καταχωρητές για τα Flags εξόδου
    logic total_ovf_reg, total_ovf_next;
    logic total_zero_reg, total_zero_next;
    logic [2:0] ovf_fsm_stage_reg, ovf_fsm_stage_next;
    logic [2:0] zero_fsm_stage_reg, zero_fsm_stage_next;

    // --- 5. Wires για Σύνδεση των Modules ---
    
    // Σήματα ελέγχου (θα οριστούν από το always_comb)
    logic rf_write_enable_s;
    logic [7:0] rom_addr1_s, rom_addr2_s;
    logic [3:0] rf_readReg1_s, rf_readReg2_s, rf_readReg3_s, rf_readReg4_s;
    logic [3:0] rf_writeReg1_s, rf_writeReg2_s;
    logic [3:0] alu1_op_s, alu2_op_s;
    logic signed [DATAWIDTH-1:0] alu1_op1_s, alu1_op2_s, alu2_op1_s, alu2_op2_s;
    logic signed [DATAWIDTH-1:0] mac1_op1_s, mac1_op2_s, mac1_op3_s;
    logic signed [DATAWIDTH-1:0] mac2_op1_s, mac2_op2_s, mac2_op3_s;

    // Σήματα δεδομένων (από τα modules)
    wire [DATAWIDTH-1:0] rom_dout1, rom_dout2;
    wire [DATAWIDTH-1:0] rf_readData1, rf_readData2, rf_readData3, rf_readData4;
    wire [DATAWIDTH-1:0] alu1_result, alu2_result;
    wire alu1_ovf, alu1_zero, alu2_ovf, alu2_zero;
    wire [DATAWIDTH-1:0] mac1_result, mac2_result;
    wire mac1_zero_mul, mac1_zero_add, mac2_zero_mul, mac2_zero_add;
    wire mac1_ovf_mul, mac1_ovf_add, mac2_ovf_mul, mac2_ovf_add;
    
    // Wires για τη λογική των Flags
    logic stage_has_ovf;
    logic stage_has_zero;
    logic [2:0] current_stage_code;

    // --- 6. Instantiation των Υπο-Modules ---
    
    // 6.1. Η ROM (από rom.v)
    WEIGHT_BIAS_MEMORY #(
        .DATAWIDTH(DATAWIDTH)
    ) u_rom (
        .clk(clk),
        .addr1(rom_addr1_s),
        .addr2(rom_addr2_s),
        .dout1(rom_dout1),
        .dout2(rom_dout2)
    );

    // 6.2. Το Register File (από regfile.sv)
    regfile #(
        .DATAWIDTH(DATAWIDTH)
    ) u_regfile (
        .clk(clk),
        .resetn(resetn),
        .write(rf_write_enable_s), // Ελέγχεται από FSM
        .readReg1(rf_readReg1_s),
        .readReg2(rf_readReg2_s),
        .readReg3(rf_readReg3_s),
        .readReg4(rf_readReg4_s),
        .writeReg1(rf_writeReg1_s),
        .writeReg2(rf_writeReg2_s),
        .writeData1(rom_dout1), // Data έρχονται *πάντα* από ROM...
        .writeData2(rom_dout2), // ...αλλά γράφονται μόνο όταν write=1
        .readData1(rf_readData1),
        .readData2(rf_readData2),
        .readData3(rf_readData3),
        .readData4(rf_readData4)
    );

    // 6.3. Οι δύο ALU (από alu.sv)
    alu u_alu_1 (
        .op1(alu1_op1_s), .op2(alu1_op2_s), .alu_op(alu1_op_s), 
        .result(alu1_result), .zero(alu1_zero), .ovf(alu1_ovf)
    );
    alu u_alu_2 (
        .op1(alu2_op1_s), .op2(alu2_op2_s), .alu_op(alu2_op_s),
        .result(alu2_result), .zero(alu2_zero), .ovf(alu2_ovf)
    );
                  
    // 6.4. Οι δύο MAC Units (από mac_unit.sv)
    mac_unit u_mac_1 (
        .op1(mac1_op1_s), .op2(mac1_op2_s), .op3(mac1_op3_s),
        .total_result(mac1_result),
        .zero_mul(mac1_zero_mul), .zero_add(mac1_zero_add),
        .ovf_mul(mac1_ovf_mul),   .ovf_add(mac1_ovf_add)
    );
    mac_unit u_mac_2 (
        .op1(mac2_op1_s), .op2(mac2_op2_s), .op3(mac2_op3_s),
        .total_result(mac2_result),
        .zero_mul(mac2_zero_mul), .zero_add(mac2_zero_add),
        .ovf_mul(mac2_ovf_mul),   .ovf_add(mac2_ovf_add)
    );

    // --- 7. FSM Block 1: Sequential Logic (always_ff) ---
    // (Ακολουθιακό: Χειρίζεται το reset, την αλλαγή καταστάσεων, 
    // και αποθηκεύει *όλες* τις τιμές.)
    
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // --- Ασύγχρονος Μηδενισμός ---
            current_state     <= STATE_DEACTIVATED;
            load_counter      <= '0;
            output_step       <= '0;
            
            // Μηδενισμός ενδιάμεσων καταχωρητών
            inter_1_reg       <= '0;
            inter_2_reg       <= '0;
            inter_3_reg       <= '0;
            inter_4_reg       <= '0;
            temp_result_reg   <= '0;
            inter_5_reg       <= '0;
            final_output_reg  <= '0;
            
            // Μηδενισμός flags
            total_ovf_reg     <= 1'b0;
            total_zero_reg    <= 1'b0;
            ovf_fsm_stage_reg <= 3'b111; // 111 = "Δεν υπάρχει υπερχείλιση"
            zero_fsm_stage_reg<= 3'b111; // 111 = "Δεν υπάρχει μηδενικό"
        
        end else begin
            // --- Σύγχρονη Λογική ---
            current_state <= next_state; // Προχωράμε στην επόμενη κατάσταση

            // Ενημέρωση Μετρητών
            case (current_state)
                STATE_LOAD:
                    if (load_counter == 8) // Τελείωσε ο 9ος κύκλος (0..8)
                        load_counter <= '0;
                    else
                        load_counter <= load_counter + 1;
                
                STATE_OUT_LAYER:
                    if (output_step == 1) // Τελείωσε ο 2ος κύκλος (0..1)
                        output_step <= '0;
                    else
                        output_step <= output_step + 1;

                default: begin
                    load_counter <= '0;
                    output_step  <= '0;
                end
            endcase
            
            // Αποθήκευση Ενδιάμεσων Αποτελεσμάτων
            inter_1_reg       <= inter_1_next;
            inter_2_reg       <= inter_2_next;
            inter_3_reg       <= inter_3_next;
            inter_4_reg       <= inter_4_next;
            temp_result_reg   <= temp_result_next;
            inter_5_reg       <= inter_5_next;
            final_output_reg  <= final_output_next;

            // Λογική Αποθήκευσης (Latching) των Flags
            // Μηδενίζουμε τα flags *μόνο* όταν ξεκινά νέος υπολογισμός
            if (current_state == STATE_IDLE && enable) begin
                total_ovf_reg      <= 1'b0;
                total_zero_reg     <= 1'b0;
                ovf_fsm_stage_reg  <= 3'b111;
                zero_fsm_stage_reg <= 3'b111;
            end else begin
                // Αλλιώς, εφαρμόζουμε τις "sticky" τιμές
                total_ovf_reg      <= total_ovf_next;
                total_zero_reg     <= total_zero_next;
                ovf_fsm_stage_reg  <= ovf_fsm_stage_next;
                zero_fsm_stage_reg <= zero_fsm_stage_next;
            end
        end
    end

    // --- 8. FSM Block 2: Combinational Logic (always_comb) ---
    // (Συνδυαστικό: Αποφασίζει την ΕΠΟΜΕΝΗ κατάσταση και 
    // ελέγχει ΟΛΟ το datapath βασιζόμενο *μόνο* στην current_state.)
    
    always_comb begin
        
        // 8.1. Default Τιμές (Το πιο σημαντικό βήμα για Moore FSM!)
        // Ορίζουμε τα πάντα σε "αδρανή" κατάσταση για να αποφύγουμε latches.
        
        next_state = current_state; // Από default, μένουμε στην ίδια κατάσταση

        // --- Σήματα Ελέγχου (Defaults) ---
        rf_write_enable_s = 1'b0;
        rom_addr1_s = '0; 
        rom_addr2_s = '0;
        rf_readReg1_s = 4'b0; 
        rf_readReg2_s = 4'b0; 
        rf_readReg3_s = 4'b0; 
        rf_readReg4_s = 4'b0;
        rf_writeReg1_s = 4'b0; 
        rf_writeReg2_s = 4'b0;
        
        alu1_op_s  = 4'bxxxx; // Don't care
        alu2_op_s  = 4'bxxxx;
        alu1_op1_s = '0; alu1_op2_s = '0;
        alu2_op1_s = '0; alu2_op2_s = '0;
        
        mac1_op1_s = '0; mac1_op2_s = '0; mac1_op3_s = '0;
        mac2_op1_s = '0; mac2_op2_s = '0; mac2_op3_s = '0;

        // --- Ενδιάμεσοι Καταχωρητές (Defaults) ---
        // Κρατούν την παλιά τους τιμή
        inter_1_next = inter_1_reg;
        inter_2_next = inter_2_reg;
        inter_3_next = inter_3_reg;
        inter_4_next = inter_4_reg;
        temp_result_next = temp_result_reg;
        inter_5_next = inter_5_reg;
        final_output_next = final_output_reg;
        
        // --- Flags (Defaults) ---
        // Κρατούν την παλιά τους τιμή
        total_ovf_next  = total_ovf_reg;
        total_zero_next = total_zero_reg;
        ovf_fsm_stage_next  = ovf_fsm_stage_reg;
        zero_fsm_stage_next = zero_fsm_stage_reg;
        stage_has_ovf  = 1'b0;
        stage_has_zero = 1'b0;
        current_stage_code = 3'b111; // Default "no stage"
        
        
        // 8.2. Κύρια Λογική FSM (case statement)
        case (current_state)
            
            STATE_DEACTIVATED: begin
                // Κατάσταση Reset. Θα μεταβεί στο STATE_LOAD 
                // στην 1η ακμή ρολογιού *μετά* το resetn=1.
                next_state = STATE_LOAD;
            end

            STATE_LOAD: begin
                // Κύκλοι: 9 (load_counter 0..8)
                // Στόχος: Φόρτωση R[0] έως R[15] από τη ROM.
                // (Το rom_bytes.data περιέχει και τις 16 τιμές, με τα 0 στις
                // θέσεις R0, R1, R12, R13, R14, R15)
                
                // --- ROM Request (Ζητάμε data για τον *επόμενο* κύκλο) ---
                if (load_counter < 8) begin // Στους κύκλους 0-7, ζητάμε R0..R15
                    rom_addr1_s = (load_counter * 2) * 4;       // R[0], R[2], ..., R[14]
                    rom_addr2_s = ((load_counter * 2) + 1) * 4; // R[1], R[3], ..., R[15]
                end
                
                // --- RegFile Write (Γράφουμε data από τον *προηγούμενο* κύκλο) ---
                if (load_counter > 0) begin // Στους κύκλους 1-8, γράφουμε R0..R15
                    rf_write_enable_s = 1'b1;
                    rf_writeReg1_s = ((load_counter - 1) * 2);
                    rf_writeReg2_s = (((load_counter - 1) * 2) + 1);
                end

                // --- Λογική Μετάβασης ---
                if (load_counter == 8) begin
                    next_state = STATE_IDLE; // Τελείωσε η φόρτωση
                end else begin
                    next_state = STATE_LOAD; // Μείνε εδώ
                end
            end
            
            STATE_IDLE: begin
                // Κύκλοι: Άγνωστο (περιμένει 'enable')
                
                // --- Λογική Μετάβασης ---
                if (enable) begin
                    next_state = STATE_PRE_PROC;
                end else begin
                    next_state = STATE_IDLE; // Μείνε εδώ
                end
            end

            STATE_PRE_PROC: begin
                // Κύκλοι: 1
                // `inter_1 = input_1 >>> shift_bias_1`
                // `inter_2 = input_2 >>> shift_bias_2`
                current_stage_code = STATE_PRE_PROC;
                
                // Datapath: Διάβασε 2x shift, χρησιμοποίησε 2x ALU
                rf_readReg1_s = 4'h2; // shift_bias_1
                rf_readReg2_s = 4'h3; // shift_bias_2
                
                alu1_op1_s = input_1;
                alu1_op2_s = rf_readData1; // shift_bias_1
                alu1_op_s  = OP_ASR;      // ARTHM_SHFT_RIGHT

                alu2_op1_s = input_2;
                alu2_op2_s = rf_readData2; // shift_bias_2
                alu2_op_s  = OP_ASR;      // ARTHM_SHFT_RIGHT
                
                // Αποθήκευση για τον επόμενο κύκλο
                inter_1_next = alu1_result;
                inter_2_next = alu2_result;
                
                // Λογική Flags
                stage_has_ovf  = alu1_ovf | alu2_ovf;
                stage_has_zero = alu1_zero | alu2_zero;

                // Λογική Μετάβασης
                next_state = STATE_INPUT_LAYER;
            end
            
            STATE_INPUT_LAYER: begin
                // Κύκλοι: 1
                // `inter_3 = inter_1 * weight_1 + bias_1`
                // `inter_4 = inter_2 * weight_2 + bias_2`
                current_stage_code = STATE_INPUT_LAYER;
                
                // Datapath: Διάβασε 4x τιμές, χρησιμοποίησε 2x MAC (παράλληλα)
                rf_readReg1_s = 4'h4; // weight_1
                rf_readReg2_s = 4'h5; // bias_1
                rf_readReg3_s = 4'h6; // weight_2
                rf_readReg4_s = 4'h7; // bias_2
                
                mac1_op1_s = inter_1_reg; // inter_1 (από reg)
                mac1_op2_s = rf_readData1; // weight_1
                mac1_op3_s = rf_readData2; // bias_1
                
                mac2_op1_s = inter_2_reg; // inter_2 (από reg)
                mac2_op2_s = rf_readData3; // weight_2
                mac2_op3_s = rf_readData4; // bias_2
                
                // Αποθήκευση για τον επόμενο κύκλο
                inter_3_next = mac1_result;
                inter_4_next = mac2_result;
                
                // Λογική Flags
                stage_has_ovf  = mac1_ovf_mul | mac1_ovf_add | mac2_ovf_mul | mac2_ovf_add;
                stage_has_zero = mac1_zero_mul | mac1_zero_add | mac2_zero_mul | mac2_zero_add;

                // Λογική Μετάβασης
                next_state = STATE_OUT_LAYER;
            end

            STATE_OUT_LAYER: begin
                // Κύκλοι: 2 (ελέγχεται από το 'output_step')
                // "Υλοποίηση σειριακά"
                current_stage_code = STATE_OUT_LAYER;
                
                if (output_step == 0) begin
                    // Βήμα 1: `temp_result = (inter_3 * weight_3) + bias_3`
                    rf_readReg1_s = 4'h8; // weight_3
                    rf_readReg3_s = 4'hA; // bias_3
                    
                    mac1_op1_s = inter_3_reg;
                    mac1_op2_s = rf_readData1; // weight_3
                    mac1_op3_s = rf_readData3; // bias_3
                    
                    temp_result_next = mac1_result; // Αποθήκευση 1ου βήματος
                    
                    // Λογική Flags (Βήμα 1)
                    stage_has_ovf  = mac1_ovf_mul | mac1_ovf_add;
                    stage_has_zero = mac1_zero_mul | mac1_zero_add;

                    next_state = STATE_OUT_LAYER; // Μείνε εδώ
                
                end else begin // (output_step == 1)
                    // Βήμα 2: `inter_5 = (inter_4 * weight_4) + temp_result`
                    rf_readReg2_s = 4'h9; // weight_4

                    mac2_op1_s = inter_4_reg;
                    mac2_op2_s = rf_readData2; // weight_4
                    mac2_op3_s = temp_result_reg; // Αποτέλεσμα 1ου βήματος
                    
                    inter_5_next = mac2_result; // Αποθήκευση τελικού inter_5
                    
                    // Λογική Flags (Βήμα 2)
                    stage_has_ovf  = mac2_ovf_mul | mac2_ovf_add;
                    stage_has_zero = mac2_zero_mul | mac2_zero_add;

                    next_state = STATE_POST_PROC; // Πήγαινε στο επόμενο
                end
            end

            STATE_POST_PROC: begin
                // Κύκλοι: 1
                // `output = inter_5 << shift_bias_3`
                current_stage_code = STATE_POST_PROC;
                
                // Datapath: Διάβασε 1x shift, χρησιμοποίησε 1x ALU
                rf_readReg1_s = 4'hB; // shift_bias_3
                
                alu1_op1_s = inter_5_reg;
                alu1_op2_s = rf_readData1; // shift_bias_3
                alu1_op_s  = OP_LSL;      // LOG_SHFT_LEFT
                
                // Αποθήκευση στο τελικό output register
                final_output_next = alu1_result;
                
                // Λογική Flags
                stage_has_ovf  = alu1_ovf;
                stage_has_zero = alu1_zero;

                // Λογική Μετάβασης
                next_state = STATE_IDLE; // Επιστροφή στην αναμονή
            end
            
            default: begin
                // Αυτό δεν πρέπει να συμβεί ποτέ
                next_state = STATE_IDLE;
            end

        endcase // case (current_state)
        
        
        // 8.3. "Sticky" Λογική για τα Flags & ΧΕΙΡΙΣΜΟΣ OVERFLOW
        
        // --- Zero Flag ---
        if (stage_has_zero) begin
            total_zero_next = 1'b1;
            // Καταγράφουμε *μόνο* το πρώτο στάδιο που προκάλεσε ZERO
            if (total_zero_reg == 1'b0) begin // Αν δεν είχαμε ήδη ZERO
                zero_fsm_stage_next = current_stage_code;
            end
        end
        
        // --- Overflow Flag & FSM Override ---
        // Αυτός είναι ο κρίσιμος χειρισμός που ζητά η εκφώνηση
        if (stage_has_ovf) begin
            total_ovf_next = 1'b1;
            
            // Καταγράφουμε *μόνο* το πρώτο στάδιο που προκάλεσε OVF
            if (total_ovf_reg == 1'b0) begin 
                ovf_fsm_stage_next = current_stage_code;
            end
            
            // *** OVERRIDE ***
            // 1. Επιστροφή στο IDLE
            next_state = STATE_IDLE; 
            
            // 2. Θέσε την έξοδο στο 32'hFFFFFFFF για να ταιριάζει με το nn_model
            final_output_next = 32'hFFFFFFFF; 
        end

    end // always_comb

    // --- 9. Τελικές Αναθέσεις Εξόδων ---
    // Οι έξοδοι του module είναι οι τιμές των καταχωρητών.
    // Αυτό ολοκληρώνει τη Moore FSM (έξοδοι = f(κατάσταση)).
    assign final_output = final_output_reg;
    assign total_ovf = total_ovf_reg;
    assign total_zero = total_zero_reg;
    assign ovf_fsm_stage = ovf_fsm_stage_reg;
    assign zero_fsm_stage = zero_fsm_stage_reg;

endmodule
