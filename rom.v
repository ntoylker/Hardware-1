module WEIGHT_BIAS_MEMORY #(parameter DATAWIDTH = 32) (
 input clk,
 input [7:0] addr1,
 input [7:0] addr2,
 output reg [DATAWIDTH-1:0] dout1,
 output reg [DATAWIDTH-1:0] dout2
 );
  
  reg [7:0] ROM [511:0];

  initial begin
    $readmemb("rom_bytes.data", ROM);
  end

    // ΜΠΟΡΕΙ ΝΑ ΔΙΑΒΑΖΕΙ ΔΥΟ ΔΙΑΦΟΡΕΤΙΚΑ ΔΕΔΟΜΕΝΑ ΤΑΥΤΟΧΡΟΝΑ ΣΤΟΝ ΙΔΙΟ ΚΥΚΛΟ ΡΟΛΟΓΙΟΥ 
  always @(posedge clk)
    /* 
      Σύγχρονη (Synchronous): Οι έξοδοι dout1 και dout2 δεν αλλάζουν αμέσως. Ενημερώνονται έναν κύκλο
      ρολογιού μετά την αλλαγή των addr1 και addr2, στην επόμενη θετική ακμή του ρολογιού (@(posedge clk)
    */
    begin
      // αν του δωσω addr=0 θα επιστρεψει τα bytes 0-1-2-3 μέσω της dout
      dout1 <= {ROM[addr1], ROM[addr1 + 1], ROM[addr1 + 2], ROM[addr1 + 3]};
      dout2 <= {ROM[addr2], ROM[addr2 + 1], ROM[addr2 + 2], ROM[addr2 + 3]};
  end

endmodule

