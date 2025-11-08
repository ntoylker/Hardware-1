module alu (
    input signed [31:0] op1,	// Εισοδος 1 (signed)
    input signed [31:0] op2,	// Εισοδος 2 (signed)
    input [3:0] alu_op,         // 4-bit κωδικος πραξης
    output wire zero,           // Εξοδος:1 αν το result ειναι 0
    output reg [31:0] result,   // Εξοδος:Το 32-bit αποτελεσμα
    output reg ovf				// Εξοδος:1 αν υπαρχει υπερχειλιση
);

    /* ΣΤΑΘΕΡΕΣ ΓΙΑ ΤΙΣ ΠΡΑΞΕΙΣ ΤΗΣ ALU*/
    // ΛΟΓΙΚΕΣ ΠΡΑΞΕΙΣ
    parameter[3:0] ALUOP_AND  = 4'b1000;
    parameter[3:0] ALUOP_OR   = 4'b1001;
    parameter[3:0] ALUOP_NOR  = 4'b1010;
    parameter[3:0] ALUOP_NAND = 4'b1011;
    parameter[3:0] ALUOP_XOR  = 4'b1100;
    // ΠΡΟΣΗΜΑΣΜΕΝΕΣ ΠΡΑΞΕΙΣ
    parameter[3:0] ALUOP_SUM  = 4'b0100;
    parameter[3:0] ALUOP_SUB  = 4'b0101;
    parameter[3:0] ALUOP_MUL  = 4'b0110;
    // ΟΛΙΣΘΗΣΕΙΣ (Shifts)
    parameter[3:0] ALUOP_LOG_SHFT_RIGHT   = 4'b0000;
    parameter[3:0] ALUOP_LOG_SHFT_LEFT    = 4'b0001;
    parameter[3:0] ALUOP_ARTHM_SHFT_RIGHT = 4'b0010;
    parameter[3:0] ALUOP_ARTHM_SHFT_LEFT  = 4'b0011;

    // Ενδιαμεσα σηματα για τον υπολογισμο της υπερχειλισης (overflow)
    // Αυτα ειναι χρησιμα για να κρατησουμε το 'always' block καθαρο.
    wire signed [31:0] add_res = op1 + op2;
    wire signed [31:0] sub_res = op1 - op2;
    wire signed [63:0] mul_res = op1 * op2; // 32x32 δινει 64-bit αποτελεσμα

    // Λογικη Υπερχειλισης
    // 1. Προσθεση: Υπερχειλιση συμβαινει αν οι τελεστες εχουν ιδιο προσημο
    // και το αποτελεσμα εχει διαφορετικο προσημο.
    wire add_ovf = (op1[31] == op2[31]) && (add_res[31] != op1[31]);

    // 2. Αφαιρεση: Υπερχειλιση συμβαινει αν οι τελεστες εχουν διαφορετικο προσημο
    // και το αποτελεσμα εχει το προσημο του op2 (του αφαιρετεου).
    wire sub_ovf = (op1[31] != op2[31]) && (sub_res[31] != op1[31]);

    // 3. Πολλαπλασιασμος: Υπερχειλιση συμβαινει αν το 64-bit αποτελεσμα δεν
    // "χωραει" σε 32 bits (δηλ. τα ανω 32 bits δεν ειναι απλη επεκταση προσημου).
    // Ελεγχουμε αν ολα τα bits [63:31] ειναι ιδια.
    wire mul_ovf = |(mul_res[63:32] ^ {32{mul_res[31]}});


    /* Ο ΠΟΛΥΠΛΕΚΤΗΣ (ΥΛΟΠΟΙΗΣΗ ΜΕ CASE) */
    // Αυτο το block υλοποιει τη συνδυαστικη λογικη της ALU.
    // Εκτελειται παντα (@) οταν αλλαξει οποιαδηποτε εισοδος (*).
    always @(*) begin
        // Χρησιμοποιουμε 'case' για να επιλεξουμε την πραξη βασει του alu_op
        case (alu_op)
            ALUOP_AND:  begin
                result = op1 & op2;
                ovf = 1'b0; // Δεν οριζεται υπερχειλιση
            end
            ALUOP_OR:   begin
                result = op1 | op2;
                ovf = 1'b0;
            end
            ALUOP_NOR:  begin
                result = ~(op1 | op2);
                ovf = 1'b0;
            end
            ALUOP_NAND: begin
                result = ~(op1 & op2);
                ovf = 1'b0;
            end
            ALUOP_XOR:  begin
                result = op1 ^ op2;
                ovf = 1'b0;
            end
          
            ALUOP_SUM:  begin
                result = add_res;
                ovf = add_ovf;
            end
            ALUOP_SUB:  begin
                result = sub_res;
                ovf = sub_ovf;
            end
            ALUOP_MUL:  begin
                result = mul_res[31:0]; // Κραταμε μονο τα κατω 32 bits
                ovf = mul_ovf;
            end
            
            ALUOP_LOG_SHFT_RIGHT:   begin
                // Χρησιμοποιουμε $unsigned για να γινει σιγουρα ΛΟΓΙΚΗ (οχι αριθμητικη) ολισθηση
                result = $unsigned(op1) >> op2; 
                ovf = 1'b0;
            end
            ALUOP_ARTHM_SHFT_RIGHT: begin
                // Επειδη ο op1 ειναι 'signed', ο τελεστης '>>>' θα κανει αριθμητικη ολισθηση
                result = op1 >>> op2; 
                ovf = 1'b0;
            end
            ALUOP_LOG_SHFT_LEFT:    begin
                result = op1 << op2;
                ovf = 1'b0;
            end
            ALUOP_ARTHM_SHFT_LEFT:  begin
                // Η αριθμητικη αριστερη ολισθηση ειναι ιδια με τη λογικη
                result = op1 << op2;
                ovf = 1'b0;
            end
            
            // Ειναι καλη πρακτικη να εχουμε 'default' για να αποφυγουμε latches
            default: begin
                result = 32'bx; // 'x' = αγνωστη/αδιαφορη τιμη
                ovf = 1'bx;
            end
        endcase
    end

    /* ΣΗΜΑ 'ZERO' */
    //Η εξοδος 'zero' ειναι 1 μονο αν το τελικο αποτελεσμα (result) ειναι 0.
    //Αυτο υλοποιειται ευκολα με μια continuous assignment εκτος του always block.
    assign zero = (result == 32'b0);

endmodule
