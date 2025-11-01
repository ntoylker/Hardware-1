// Κώδικας για την ALU
module alu (
    input signed [31:0] op1,     // Είσοδος 1 (signed)
    input signed [31:0] op2,     // Είσοδος 2 (signed)
    input [3:0] alu_op,          // 4-bit κωδικός πράξης
    output wire zero,            // Έξοδος: 1 αν το result είναι 0
    output reg [31:0] result,    // Έξοδος: Το 32-bit αποτέλεσμα
    output reg ovf               // Έξοδος: 1 αν υπάρχει υπερχείλιση
);

    /* ΣΤΑΘΕΡΕΣ ΓΙΑ ΤΙΣ ΠΡΑΞΕΙΣ ΤΗΣ ALU */
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

    // Ενδιάμεσα σήματα για τον υπολογισμό της υπερχείλισης (overflow)
    // Αυτά είναι χρήσιμα για να κρατήσουμε τον 'always' block καθαρό.
    wire signed [31:0] add_res = op1 + op2;
    wire signed [31:0] sub_res = op1 - op2;
    wire signed [63:0] mul_res = op1 * op2; // Ο πολλαπλασιασμός 32x32 δίνει 64-bit αποτέλεσμα

    // Λογική Υπερχείλισης
    // 1. Πρόσθεση: Υπερχείλιση συμβαίνει αν οι τελεστές έχουν ίδιο πρόσημο
    //    και το αποτέλεσμα έχει διαφορετικό πρόσημο.
    wire add_ovf = (op1[31] == op2[31]) && (add_res[31] != op1[31]);

    // 2. Αφαίρεση: Υπερχείλιση συμβαίνει αν οι τελεστές έχουν διαφορετικό πρόσημο
    //    και το αποτέλεσμα έχει το πρόσημο του op2 (του αφαιρετέου).
    wire sub_ovf = (op1[31] != op2[31]) && (sub_res[31] != op1[31]);

    // 3. Πολλαπλασιασμός: Υπερχείλιση συμβαίνει αν το 64-bit αποτέλεσμα δεν
    //    "χωράει" σε 32 bits (δηλ. τα άνω 32 bits δεν είναι απλή επέκταση προσήμου).
    //    Ελέγχουμε αν *όλα* τα bits [63:31] είναι ίδια.
    wire mul_ovf = |(mul_res[63:32] ^ {32{mul_res[31]}});


    /* Ο ΠΟΛΥΠΛΕΚΤΗΣ (ΥΛΟΠΟΙΗΣΗ ΜΕ CASE) */
    // Αυτό το block υλοποιεί τη συνδυαστική λογική της ALU.
    // Εκτελείται "πάντα" (@) όταν αλλάξει οποιαδήποτε είσοδος (*).
    always @(*) begin
        // Χρησιμοποιούμε 'case' για να επιλέξουμε την πράξη βάσει του alu_op
        case (alu_op)
            ALUOP_AND:  begin
                result = op1 & op2;
                ovf = 1'b0; // Δεν ορίζεται υπερχείλιση
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
                result = mul_res[31:0]; // Κρατάμε μόνο τα κάτω 32 bits
                ovf = mul_ovf;
            end
            
            // Σημείωση: Οι τελεστές ολίσθησης σε Verilog χρησιμοποιούν 
            // αυτόματα μόνο τα 5 χαμηλότερα bits του op2 (αφού ο op1 είναι 32-bit).
            
            ALUOP_LOG_SHFT_RIGHT:   begin
                // Χρησιμοποιούμε $unsigned για να γίνει σίγουρα λογική (όχι αριθμητική) ολίσθηση
                result = $unsigned(op1) >> op2; 
                ovf = 1'b0;
            end
            ALUOP_ARTHM_SHFT_RIGHT: begin
                // Επειδή ο op1 είναι 'signed', ο τελεστής '>>>' θα κάνει αριθμητική ολίσθηση
                result = op1 >>> op2; 
                ovf = 1'b0;
            end
            ALUOP_LOG_SHFT_LEFT:    begin
                result = op1 << op2;
                ovf = 1'b0;
            end
            ALUOP_ARTHM_SHFT_LEFT:  begin
                // Η αριθμητική αριστερή ολίσθηση είναι ίδια με τη λογική
                result = op1 << op2;
                ovf = 1'b0;
            end
            
            // Είναι καλή πρακτική να έχουμε 'default' για να αποφύγουμε latches
            default: begin
                result = 32'bx; // 'x' = άγνωστη/αδιάφορη τιμή
                ovf = 1'bx;
            end
        endcase
    end

    /* ΣΗΜΑ 'ZERO' */
    // Η έξοδος 'zero' είναι 1 *μόνο* αν το τελικό αποτέλεσμα (result) είναι 0.
    // Αυτό υλοποιείται εύκολα με μια continuous assignment εκτός του always block.
    assign zero = (result == 32'b0);

endmodule
