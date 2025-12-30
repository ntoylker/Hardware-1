module nn #(
    parameter DATAWIDTH = 32
)(
    // --- Inputs ---
    input logic clk,
    input logic resetn, // Asynchronous, active-low reset
    input logic enable, // Signal to start computation
    input logic signed [DATAWIDTH-1:0] input_1,
    input logic signed [DATAWIDTH-1:0] input_2,

    // --- Outputs ---
    output logic signed [DATAWIDTH-1:0] final_output,
    output logic total_ovf,
    output logic total_zero,
    output logic [2:0] ovf_fsm_stage,
    output logic [2:0] zero_fsm_stage
);

    // --- 1. FSM State Definitions (Moore) ---
    typedef enum logic [2:0] {
        STATE_DEACTIVATED = 3'b000, // Reset State
        STATE_LOAD        = 3'b001, // Load ROM->RegFile
        STATE_IDLE        = 3'b010, // Wait for enable
        STATE_PRE_PROC    = 3'b011, // Data pre-processing
        STATE_INPUT_LAYER = 3'b100, // Input Layer (Parallel)
        STATE_OUT_LAYER   = 3'b101, // Output Layer (Serial)
        STATE_POST_PROC   = 3'b110  // Data post-processing
    } fsm_state_t;
    
    fsm_state_t current_state, next_state;

    // --- 2. Counters for Multi-Cycle States ---
    
    // Counter for STATE_LOAD.
    // We need 9 cycles (0-8)
    // 1 (Req R0,R1) + 8 (Write R0-R15) = 9 cycles
    logic [3:0] load_counter;
    
    // Step counter for STATE_OUT_LAYER (0 or 1 = 2 cycles)
    logic output_step;

    // --- 3. ALU Opcode Constants (from alu.v) ---
    localparam [3:0] OP_LSL  = 4'b0001; // LOG_SHFT_LEFT
    localparam [3:0] OP_ASR  = 4'b0010; // ARTHM_SHFT_RIGHT
    localparam [3:0] OP_ASL  = 4'b0011; // ARTHM_SHFT_LEFT

    // --- 4. Intermediate Registers (Datapath Memory) ---
    // Implementation of the "intermediate registers" option
    logic signed [DATAWIDTH-1:0] inter_1_reg, inter_1_next;
    logic signed [DATAWIDTH-1:0] inter_2_reg, inter_2_next;
    logic signed [DATAWIDTH-1:0] inter_3_reg, inter_3_next;
    logic signed [DATAWIDTH-1:0] inter_4_reg, inter_4_next;
    logic signed [DATAWIDTH-1:0] temp_result_reg, temp_result_next;
    logic signed [DATAWIDTH-1:0] inter_5_reg, inter_5_next;
    logic signed [DATAWIDTH-1:0] final_output_reg, final_output_next;
    
    // Registers for the output flags
    logic total_ovf_reg, total_ovf_next;
    logic total_zero_reg, total_zero_next;
    logic [2:0] ovf_fsm_stage_reg, ovf_fsm_stage_next;
    logic [2:0] zero_fsm_stage_reg, zero_fsm_stage_next;

    // --- 5. Wires for Module Connections ---
    
    // Control signals (will be set by always_comb)
    logic rf_write_enable_s;
    logic [7:0] rom_addr1_s, rom_addr2_s;
    logic [3:0] rf_readReg1_s, rf_readReg2_s, rf_readReg3_s, rf_readReg4_s;
    logic [3:0] rf_writeReg1_s, rf_writeReg2_s;
    logic [3:0] alu1_op_s, alu2_op_s;
    logic signed [DATAWIDTH-1:0] alu1_op1_s, alu1_op2_s, alu2_op1_s, alu2_op2_s;
    logic signed [DATAWIDTH-1:0] mac1_op1_s, mac1_op2_s, mac1_op3_s;
    logic signed [DATAWIDTH-1:0] mac2_op1_s, mac2_op2_s, mac2_op3_s;
    
    // Data signals (from the modules)
    wire [DATAWIDTH-1:0] rom_dout1, rom_dout2;
    wire [DATAWIDTH-1:0] rf_readData1, rf_readData2, rf_readData3, rf_readData4;
    wire [DATAWIDTH-1:0] alu1_result, alu2_result;
    wire alu1_ovf, alu1_zero, alu2_ovf, alu2_zero;
    wire [DATAWIDTH-1:0] mac1_result, mac2_result;
    wire mac1_zero_mul, mac1_zero_add, mac2_zero_mul, mac2_zero_add;
    wire mac1_ovf_mul, mac1_ovf_add, mac2_ovf_mul, mac2_ovf_add;
    
    // Wires for Flag logic
    logic stage_has_ovf;
    logic stage_has_zero;
    logic [2:0] current_stage_code;

    // --- 6. Instantiation of Sub-Modules ---
    
    // 6.1. The ROM (from WEIGHT_BIAS_MEMORY.v)
    WEIGHT_BIAS_MEMORY #(
        .DATAWIDTH(DATAWIDTH)
    ) u_rom (
        .clk(clk),
        .addr1(rom_addr1_s),
        .addr2(rom_addr2_s),
        .dout1(rom_dout1),
        .dout2(rom_dout2)
    );

    // 6.2. The Register File (from regfile.v)
    regfile #(
        .DATAWIDTH(DATAWIDTH)
    ) u_regfile (
        .clk(clk),
        .resetn(resetn),
        .write(rf_write_enable_s), // Controlled by FSM
        .readReg1(rf_readReg1_s),
        .readReg2(rf_readReg2_s),
        .readReg3(rf_readReg3_s),
        .readReg4(rf_readReg4_s),
        .writeReg1(rf_writeReg1_s),
        .writeReg2(rf_writeReg2_s),
        .writeData1(rom_dout1), // Data always comes from ROM...
        .writeData2(rom_dout2), // ...but is only written when write=1
        .readData1(rf_readData1),
        .readData2(rf_readData2),
        .readData3(rf_readData3),
        .readData4(rf_readData4)
    );

    // 6.3. The two ALUs (from alu.v)
    alu u_alu_1 (
        .op1(alu1_op1_s), .op2(alu1_op2_s), .alu_op(alu1_op_s), 
        .result(alu1_result), .zero(alu1_zero), .ovf(alu1_ovf)
    );
    alu u_alu_2 (
        .op1(alu2_op1_s), .op2(alu2_op2_s), .alu_op(alu2_op_s),
        .result(alu2_result), .zero(alu2_zero), .ovf(alu2_ovf)
    );

    // 6.4. The two MAC Units (from mac_unit.v)
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
    // (Sequential: Handles reset, state changes, 
    // and stores all values.)
    
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // --- Asynchronous Reset ---
            current_state     <= STATE_DEACTIVATED;
            load_counter      <= '0;
            output_step       <= '0;
            
            // Reset intermediate registers
            inter_1_reg       <= '0;
            inter_2_reg       <= '0;
            inter_3_reg       <= '0;
            inter_4_reg       <= '0;
            temp_result_reg   <= '0;
            inter_5_reg       <= '0;
            final_output_reg  <= '0;
            
            // Reset flags
            total_ovf_reg     <= 1'b0;
            total_zero_reg    <= 1'b0;
            ovf_fsm_stage_reg <= 3'b111; // 111 = "No overflow"
            zero_fsm_stage_reg<= 3'b111; // 111 = "No zero"
        
        end else begin
            // --- Synchronous Logic ---
            current_state <= next_state; // Advance to the next state

            // Update Counters
            case (current_state)
                STATE_LOAD:
                    if (load_counter == 8) // Finished the 9th cycle (0..8)
                        load_counter <= '0;
                    else
                        load_counter <= load_counter + 1;
                
                STATE_OUT_LAYER:
                    if (output_step == 1) // Finished the 2nd cycle (0..1)
                        output_step <= '0;
                    else
                        output_step <= output_step + 1;
                
                default: begin
                    load_counter <= '0;
                    output_step  <= '0;
                end
            endcase
            
            // Store Intermediate Results
            inter_1_reg       <= inter_1_next;
            inter_2_reg       <= inter_2_next;
            inter_3_reg       <= inter_3_next;
            inter_4_reg       <= inter_4_next;
            temp_result_reg   <= temp_result_next;
            inter_5_reg       <= inter_5_next;
            final_output_reg  <= final_output_next;
            
            // Latching Logic for Flags
            // We reset the flags ONLY when a new calculation begins
            if (current_state == STATE_IDLE && enable) begin
                total_ovf_reg      <= 1'b0;
                total_zero_reg     <= 1'b0;
                ovf_fsm_stage_reg  <= 3'b111;
                zero_fsm_stage_reg <= 3'b111;
            end else begin
                // Otherwise, apply the "sticky" values
                total_ovf_reg      <= total_ovf_next;
                total_zero_reg     <= total_zero_next;
                ovf_fsm_stage_reg  <= ovf_fsm_stage_next;
                zero_fsm_stage_reg <= zero_fsm_stage_next;
            end
        end
    end

    // --- 8. FSM Block 2: Combinational Logic (always_comb) ---
    // (Combinational: Decides the NEXT state and
    // controls the ENTIRE datapath based ONLY on the current_state.)
    
    always_comb begin
        
        // 8.1. Default Values (The most important step for a Moore FSM!)
        // We define everything in an "idle" state to avoid latches.
        
        next_state = current_state; // By default, stay in the same state

        // --- Control Signals (Defaults) ---
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

        // --- Intermediate Registers (Defaults) ---
        // They keep their old value
        inter_1_next = inter_1_reg;
        inter_2_next = inter_2_reg;
        inter_3_next = inter_3_reg;
        inter_4_next = inter_4_reg;
        temp_result_next = temp_result_reg;
        inter_5_next = inter_5_reg;
        final_output_next = final_output_reg;

        // --- Flags (Defaults) ---
        // They keep their old value
        total_ovf_next  = total_ovf_reg;
        total_zero_next = total_zero_reg;
        ovf_fsm_stage_next  = ovf_fsm_stage_reg;
        zero_fsm_stage_next = zero_fsm_stage_reg;
        stage_has_ovf  = 1'b0;
        stage_has_zero = 1'b0;
        current_stage_code = 3'b111; // Default "no stage"
        
        
        // 8.2. Main FSM Logic (case statement)
        case (current_state)
            
            STATE_DEACTIVATED: begin
                // Reset State. 
                // Wait for 'enable' signal to start loading process.
                if (enable) begin
                    next_state = STATE_LOAD;
                end else begin
                    next_state = STATE_DEACTIVATED;
                end
            end

            STATE_LOAD: begin
                // Cycles: 9 (load_counter 0..8)
                // Goal: Load R[0] through R[15] from ROM.
                // (The rom_bytes.data contains all 16 values, including
                // the zeros at R0, R1, R12, R13, R14, R15)
                
                // --- ROM Request (Request data for the *next* cycle) ---
                if (load_counter < 8) begin // On cycles 0-7, request R0..R15
                    rom_addr1_s = (load_counter * 2) * 4;       // R[0], R[2], ..., R[14]
                    rom_addr2_s = ((load_counter * 2) + 1) * 4; // R[1], R[3], ..., R[15]
                end
                
                // --- RegFile Write (Write data from the *previous* cycle) ---
                if (load_counter > 0) begin // On cycles 1-8, write R0..R15
                    rf_write_enable_s = 1'b1;
                    rf_writeReg1_s = ((load_counter - 1) * 2);
                    rf_writeReg2_s = (((load_counter - 1) * 2) + 1);
                end

                // --- Transition Logic ---
                if (load_counter == 8) begin
                    next_state = STATE_IDLE; // Loading finished
                end else begin
                    next_state = STATE_LOAD; // Stay here
                end
            end
            
            STATE_IDLE: begin
                // Cycles: Unknown (waits for 'enable')
                
                // --- Transition Logic ---
                if (enable) begin
                    next_state = STATE_PRE_PROC;
                end else begin
                    next_state = STATE_IDLE; // Stay here
                end
            end

            STATE_PRE_PROC: begin
                // Cycles: 1
                // `inter_1 = input_1 >>> shift_bias_1`
                // `inter_2 = input_2 >>> shift_bias_2`
                current_stage_code = STATE_PRE_PROC;
                
                // Datapath: Read 2x shift, use 2x ALU
                rf_readReg1_s = 4'h2; // shift_bias_1
                rf_readReg2_s = 4'h3; // shift_bias_2
                
                alu1_op1_s = input_1;
                alu1_op2_s = rf_readData1; // shift_bias_1
                alu1_op_s  = OP_ASR;     // ARTHM_SHFT_RIGHT

                alu2_op1_s = input_2;
                alu2_op2_s = rf_readData2; // shift_bias_2
                alu2_op_s  = OP_ASR;     // ARTHM_SHFT_RIGHT
                
                // Store for next cycle
                inter_1_next = alu1_result;
                inter_2_next = alu2_result;
                
                // Flag Logic
                stage_has_ovf  = alu1_ovf | alu2_ovf;
                stage_has_zero = alu1_zero | alu2_zero;

                // Transition Logic
                next_state = STATE_INPUT_LAYER;
            end
            
            STATE_INPUT_LAYER: begin
                // Cycles: 1
                // `inter_3 = inter_1 * weight_1 + bias_1`
                // `inter_4 = inter_2 * weight_2 + bias_2`
                current_stage_code = STATE_INPUT_LAYER;
                
                // Datapath: Read 4x values, use 2x MAC (in parallel)
                rf_readReg1_s = 4'h4; // weight_1
                rf_readReg2_s = 4'h5; // bias_1
                rf_readReg3_s = 4'h6; // weight_2
                rf_readReg4_s = 4'h7; // bias_2
                
                mac1_op1_s = inter_1_reg;  // inter_1 (from reg)
                mac1_op2_s = rf_readData1; // weight_1
                mac1_op3_s = rf_readData2; // bias_1
                
                mac2_op1_s = inter_2_reg;  // inter_2 (from reg)
                mac2_op2_s = rf_readData3; // weight_2
                mac2_op3_s = rf_readData4; // bias_2
                
                // Store for next cycle
                inter_3_next = mac1_result;
                inter_4_next = mac2_result;
                
                // Flag Logic
                stage_has_ovf  = mac1_ovf_mul | mac1_ovf_add | mac2_ovf_mul | mac2_ovf_add;
                stage_has_zero = mac1_zero_mul | mac1_zero_add | mac2_zero_mul | mac2_zero_add;

                // Transition Logic
                next_state = STATE_OUT_LAYER;
            end

            STATE_OUT_LAYER: begin
                // Cycles: 2 (controlled by 'output_step')
                // "Serial Implementation"
                current_stage_code = STATE_OUT_LAYER;
                
                if (output_step == 0) begin
                    // Step 1: `temp_result = (inter_3 * weight_3) + bias_3`
                    rf_readReg1_s = 4'h8; // weight_3
                    rf_readReg3_s = 4'hA; // bias_3
                    
                    mac1_op1_s = inter_3_reg;
                    mac1_op2_s = rf_readData1; // weight_3
                    mac1_op3_s = rf_readData3; // bias_3
                    
                    temp_result_next = mac1_result; // Store 1st step result
                    
                    // Flag Logic (Step 1)
                    stage_has_ovf  = mac1_ovf_mul | mac1_ovf_add;
                    stage_has_zero = mac1_zero_mul | mac1_zero_add;

                    next_state = STATE_OUT_LAYER; // Stay here for step 2
                
                end else begin // (output_step == 1)
                    // Step 2: `inter_5 = (inter_4 * weight_4) + temp_result`
                    rf_readReg2_s = 4'h9; // weight_4

                    mac2_op1_s = inter_4_reg;
                    mac2_op2_s = rf_readData2;    // weight_4
                    mac2_op3_s = temp_result_reg; // Result from 1st step
                    
                    inter_5_next = mac2_result; // Store final inter_5
                    
                    // Flag Logic (Step 2)
                    stage_has_ovf  = mac2_ovf_mul | mac2_ovf_add;
                    stage_has_zero = mac2_zero_mul | mac2_zero_add;

                    next_state = STATE_POST_PROC; // Go to next stage
                end
            end

            STATE_POST_PROC: begin
                // Cycles: 1
                // `output = inter_5 << shift_bias_3`
                current_stage_code = STATE_POST_PROC;
                
                // Datapath: Read 1x shift, use 1x ALU
                rf_readReg1_s = 4'hB; // shift_bias_3
                
                alu1_op1_s = inter_5_reg;
                alu1_op2_s = rf_readData1; // shift_bias_3
              	alu1_op_s  = OP_ASL; // ARITHMETIC_SHIFT_LEFT
                
                // Store in final output register
                final_output_next = alu1_result;
                
                // Flag Logic
                stage_has_ovf  = alu1_ovf;
                stage_has_zero = alu1_zero;

                // Transition Logic
                next_state = STATE_IDLE; // Return to wait
            end
            
            default: begin
                // This should never happen
                next_state = STATE_IDLE;
            end

        endcase // case (current_state)
        
        
        // 8.3. "Sticky" Flag Logic & OVERFLOW HANDLING
        
        // --- Zero Flag ---
        if (stage_has_zero) begin
            total_zero_next = 1'b1;
            // We only record the FIRST stage that caused a ZERO
            if (total_zero_reg == 1'b0) begin // If we didn't already have a ZERO
                zero_fsm_stage_next = current_stage_code;
            end
        end
        
        // --- Overflow Flag & FSM Override ---
        // This is the critical handling required by the instructions
        if (stage_has_ovf) begin
            total_ovf_next = 1'b1;
            // We only record the FIRST stage that caused an OVF
            if (total_ovf_reg == 1'b0) begin 
                ovf_fsm_stage_next = current_stage_code;
            end
            
            // *** OVERRIDE ***
            // 1. Return to IDLE
            next_state = STATE_IDLE;
            
            // 2. Set output to max POS signed 32-bit number
            //    Spec  requires max positive number (32'h7FFFFFFF).
          	// 	  all 1s except the MSB=0, 0111.1111....1111
            final_output_next = 32'h7FFFFFFF;
        end

    end // always_comb

    // --- 9. Final Output Assignments ---
    // The module outputs are the values from the registers.
    // This completes the Moore FSM (outputs = f(state)).
    assign final_output = final_output_reg;
    assign total_ovf = total_ovf_reg;
    assign total_zero = total_zero_reg;
    assign ovf_fsm_stage = ovf_fsm_stage_reg;
    assign zero_fsm_stage = zero_fsm_stage_reg;

endmodule
