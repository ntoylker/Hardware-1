//
// Αρχείο: mac_unit.sv
// Περιγραφή: Μονάδα Multiply-Accumulate (MAC) για την Άσκηση 4.
//            Υλοποιεί την πράξη: (op1 * op2) + op3
//            Χρησιμοποιεί δύο (2) 'alu' modules σειριακά.
//

module mac_unit (
    // --- Είσοδοι ---
    // Όπως ορίζονται στον πίνακα
    input signed [31:0] op1, // Πρώτη είσοδος στον πολλαπλασιασμό
    input signed [31:0] op2, // Δεύτερη είσοδος στον πολλαπλασιασμό
    input signed [31:0] op3, // Είσοδος στην πρόσθεση (bias)

    // --- Έξοδοι ---
    // Όπως ορίζονται στον πίνακα
    output signed [31:0] total_result, // Το τελικό αποτέλεσμα
    output logic         zero_mul,     // 1 αν (op1 * op2) == 0
    output logic         ovf_mul,      // 1 αν ο πολλαπλασιασμός υπερχείλισε
    output logic         zero_add,     // 1 αν το total_result == 0
    output logic         ovf_add       // 1 αν η πρόσθεση υπερχείλισε
);

    // --- 1. Σταθερές για τις Πράξεις της ALU ---
    // Αυτές οι τιμές πρέπει να ταιριάζουν με το 'alu.sv'
    localparam [3:0] ALUOP_SUM = 4'b0100; // Κωδικός Πρόσθεσης
    localparam [3:0] ALUOP_MUL = 4'b0110; // Κωδικός Πολλαπλασιασμού

    // --- 2. Ενδιάμεσα Σήματα ---
    // Αυτό το wire θα συνδέσει την έξοδο της 1ης ALU (MUL)
    // με την είσοδο της 2ης ALU (ADD).
    wire signed [31:0] mul_result_wire;

    // --- 3. Σύνδεση των Modules ---

    // Βήμα Α: Πολλαπλασιασμός (op1 * op2)
    // "η πρώτη θα εκτελεί πάντα την πράξη του πολλαπλασιασμού"
    alu u_alu_mul (
        .op1(op1),
        .op2(op2),
        .alu_op(ALUOP_MUL),

        // Έξοδοι Πολλαπλασιασμού
        .result(mul_result_wire), // Το αποτέλεσμα πάει στο επόμενο βήμα
        .zero(zero_mul),          // Έξοδος 'zero_mul' του MAC
        .ovf(ovf_mul)             // Έξοδος 'ovf_mul' του MAC
    );

    // Βήμα Β: Πρόσθεση ( [αποτέλεσμα πολλαπλασιασμού] + op3 )
    // "η δεύτερη πάντα την πράξη της πρόσθεσης"
    alu u_alu_add (
        .op1(mul_result_wire), // Είσοδος 1 = Το αποτέλεσμα του u_alu_mul
        .op2(op3),
        .alu_op(ALUOP_SUM),

        // Τελικές Έξοδοι
        .result(total_result),    // Έξοδος 'total_result' του MAC
        .zero(zero_add),          // Έξοδος 'zero_add' του MAC
        .ovf(ovf_add)             // Έξοδος 'ovf_add' του MAC
    );

endmodule
