module regfile #(
    // Parameter for data width, defaults to 32 bits
    parameter DATAWIDTH = 32
)(
    // --- Inputs ---
    input logic clk,
    input logic resetn, // Active-low asynchronous reset
    
    // Write Enable Signal
    input logic write,

    // Read Ports (4)
    input logic [3:0] readReg1,
    input logic [3:0] readReg2,
    input logic [3:0] readReg3,
    input logic [3:0] readReg4,

    // Write Ports (2)
    input logic [3:0] writeReg1,
    input logic [3:0] writeReg2,
    input logic [DATAWIDTH-1:0] writeData1,
    input logic [DATAWIDTH-1:0] writeData2,

    // --- Outputs ---
    output logic [DATAWIDTH-1:0] readData1,
    output logic [DATAWIDTH-1:0] readData2,
    output logic [DATAWIDTH-1:0] readData3,
    output logic [DATAWIDTH-1:0] readData4
);

    // --- 1. Main Storage Array ---
    // This is the 16-entry register file memory.
    logic [DATAWIDTH-1:0] registers [16];

    // --- 2. Write Logic (Sequential) ---
    // This block handles the actual data storage (writes).
    // It is sequential: sensitive to the positive clock edge (sync write)
    // and the negative reset edge (async reset).
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Asynchronous reset: Clear all 16 registers to zero.
            for (int i = 0; i < 16; i++) begin
                registers[i] <= '0; // '0' is shorthand for (DATAWIDTH)'h0
            end
        end else begin
            // Synchronous write: On posedge clk, if write is enabled.
            if (write) begin
                registers[writeReg1] <= writeData1;
                registers[writeReg2] <= writeData2;
                
                // Note: If writeReg1 == writeReg2,
                // the value from writeData2 will be stored (last assignment wins).
            end
        end
    end

    // --- 3. Read Logic (Combinational) ---
    // Reading is combinational (asynchronous read).
    // Outputs change immediately when a read address changes
    // or when a write occurs to the same address (bypass logic).
    
    // This implements the "write-first" or "bypass" logic
    // required by the instructions.
    
    // This block is always active and describes the combinational logic.
    // Outputs are updated immediately when any input in the sensitivity list changes.
    always_comb begin
        // 1. Default values (read from the storage array)
        readData1 = registers[readReg1];
        readData2 = registers[readReg2];
        readData3 = registers[readReg3];
        readData4 = registers[readReg4];

        // 2. Implement Write-First Bypass Logic
        // If the write signal is active...
        if (write) begin
            
            // --- Check for Write Port 1 ---
            // If readReg1 matches writeReg1, bypass the memory
            // and send writeData1 directly to the output.
            if (writeReg1 == readReg1) begin
                readData1 = writeData1;
            end
            if (writeReg1 == readReg2) begin
                readData2 = writeData1;
            end
            if (writeReg1 == readReg3) begin
                readData3 = writeData1;
            end
            if (writeReg1 == readReg4) begin
                readData4 = writeData1;
            end
            
            // --- Check for Write Port 2 ---
            // These checks run after Port 1's checks.
            // This gives writeData2 priority if writeReg1 == writeReg2.
            if (writeReg2 == readReg1) begin
                readData1 = writeData2;
            end
            if (writeReg2 == readReg2) begin
                readData2 = writeData2;
            end
            if (writeReg2 == readReg3) begin
                readData3 = writeData2;
            end
            if (writeReg2 == readReg4) begin
                readData4 = writeData2;
            end
        end
    end

endmodule
