//
// Αρχείο: regfile.sv
// Περιγραφή: Άσκηση 3 - Αρχείο Καταχωρητών (Register File)
//             16xDATAWIDTH, 4-read ports, 2-write ports.
//

module regfile #(
    // "Οπου ως DATAWIDTH ορίζεται παράμετρος ... ίση με 32 bits από προεπιλογή"
    parameter DATAWIDTH = 32
)(
    // --- Είσοδοι ---
    input logic clk,
    input logic resetn, // "ενεργό χαμηλό σήμα επαναφοράς (active low reset)"
    
    // Σήμα Ελέγχου Εγγραφής
    input logic write,

    // Θύρες Ανάγνωσης (4)
    input logic [3:0] readReg1,
    input logic [3:0] readReg2,
    input logic [3:0] readReg3,
    input logic [3:0] readReg4,

    // Θύρες Εγγραφής (2)
    input logic [3:0] writeReg1,
    input logic [3:0] writeReg2,
    input logic [DATAWIDTH-1:0] writeData1,
    input logic [DATAWIDTH-1:0] writeData2,

    // --- Έξοδοι ---
    output logic [DATAWIDTH-1:0] readData1,
    output logic [DATAWIDTH-1:0] readData2,
    output logic [DATAWIDTH-1:0] readData3,
    output logic [DATAWIDTH-1:0] readData4
);

    // --- 1. Ο Κύριος Χώρος Αποθήκευσης ---
    // "Υλοποιήστε ένα αρχείο καταχωρητών 16xDATAWIDTH-bit"
    logic [DATAWIDTH-1:0] registers [16];

    // --- 2. Λογική Εγγραφής (Sequential Logic) ---
  	// flip flop logic
    // Αυτό το block χειρίζεται την *αποθήκευση* των δεδομένων.
  	// Είναι σύγχρονο στο ρολόι (posedge clk), ξυπναει παντα στην θετικη ακμη του ρολογιου
  	// και ελεγχει αν ηρθε write signal. Αν ηρθε, κανει το γραψιμο και ξανακοιμαται.
    // Ασύγχρονο στον μηδενισμό (negedge resetn).
    
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // "Οι καταχωρητές θα πρέπει να αρχικοποιούνται στην τιμή μηδέν, ασύγχρονα"
            // Χρησιμοποιούμε for-loop για να μηδενίσουμε όλους τους 16 καταχωρητές.
            for (int i = 0; i < 16; i++) begin
                registers[i] <= '0; // '0' = (DATAWIDTH)'h0
            end
        end else begin
            // "ανάλογα με το σήμα write εγγράψτε τα δεδομένα"
            if (write) begin
                registers[writeReg1] <= writeData1;
                registers[writeReg2] <= writeData2;
                
                // Σημείωση: Αν writeReg1 == writeReg2, 
                // η τιμή του writeData2 θα επικρατήσει (last assignment wins).
            end
        end
    end

    // --- 3. Λογική Ανάγνωσης (Combinational Logic) ---
    // Η ανάγνωση είναι συνδυαστική (asynchronous read).
    // Οι έξοδοι αλλάζουν *αμέσως* μόλις αλλάξει μια διεύθυνση ανάγνωσης
    // ή όταν συμβαίνει μια εγγραφή στην ίδια διεύθυνση (write-through/bypass).
    
    // "δώστε προτεραιότητα στην εγγραφή του 'writeData'"
    // Αυτό υλοποιεί τη λογική "bypass" ή "write-first".
    
  
    /* Το παρακατω κομματι κωδικα παραμενει παντα ενεργό. Αποτελει την συνδυαστικη
    λογικη του κυκλωματος. ΜΕ ΤΟ ΠΟΥ ΑΛΛΑΞΕΙ ΟΠΟΙΑΔΗΠΟΤΕ ΕΙΣΟΔΟΣ, τρεχει αυτο το κομματι κωδικα και
    μεσω των λογικων πυλων, ανανεώνονται οι εξοδοι */ 
    always_comb begin
        // 1. Προκαθορισμένες τιμές (διάβασε από τη μνήμη)
        readData1 = registers[readReg1];
        readData2 = registers[readReg2];
        readData3 = registers[readReg3];
        readData4 = registers[readReg4];

        // 2. Έλεγχος Προτεραιότητας Εγγραφής (Bypass)
        // Αν το 'write' είναι ενεργό...
        if (write) begin
            
            // --- Έλεγχος για τη Θύρα Εγγραφής 1 ---
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
            
            // --- Έλεγχος για τη Θύρα Εγγραφής 2 ---
            // (Αυτά εκτελούνται 'μετά' τα παραπάνω, δίνοντας 
            // προτεραιότητα στο writeData2 αν π.χ. writeReg1==writeReg2)
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
