//==============================================================================
//
//  Module Name:    interleaver
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Core interleaver module implementing the two-step
//                  permutation algorithm specified in IEEE 802.16-2007.
//                  The interleaver reorders bits to distribute burst errors
//                  across multiple code words, improving FEC effectiveness.
//
//                  Two-Step Permutation Algorithm:
//                  ┌─────────────────────────────────────────────────────────┐
//                  │  Input Index (k) → First Permutation (m) → Output (j)  │
//                  │                                                         │
//                  │  Step 1: m = (Ncbps/d) × (k mod d) + floor(k/d)        │
//                  │          - Distributes adjacent bits across d groups   │
//                  │          - For d=16: bits 16 apart become adjacent     │
//                  │                                                         │
//                  │  Step 2: j = s × floor(m/s) +                          │
//                  │              (m + Ncbps - floor(d×m/Ncbps)) mod s      │
//                  │          - Ensures adjacent coded bits alternate       │
//                  │            between more and less significant bits      │
//                  │            of the constellation point                  │
//                  └─────────────────────────────────────────────────────────┘
//
//                  Example Mapping (QPSK, Ncbps=192):
//                  k=0   → m=0   → j=0
//                  k=1   → m=12  → j=12
//                  k=2   → m=24  → j=24
//                  ...pattern continues for all 192 bits
//
//  Standard:       IEEE 802.16-2007 Section 8.4.9.3
//  Block Size:     Ncbps = 192 bits (for QPSK modulation)
//  Parameters:     Ncpc = 2 (QPSK), s = 1, d = 16
//  Latency:        Combinational (single cycle)
//
//  Authors:        Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Supervisor:     Dr. Ahmed Abou Auf
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        4.0
//  Date:           2025-12-19
//
//==============================================================================

module interleaver #(
    //--------------------------------------------------------------------------
    // Design Parameters
    //--------------------------------------------------------------------------
    parameter Ncbps = 192,              // Coded bits per OFDM symbol
    parameter Ncpc  = 2,                // Coded bits per subcarrier (QPSK = 2)
    parameter s     = Ncpc/2,           // Permutation parameter s = 1
    parameter d     = 16                // Permutation parameter d = 16
)
(
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic                     clk,           // System clock (100 MHz)
    input  logic                     resetN,        // Active-low async reset

    //--------------------------------------------------------------------------
    // Control Interface
    //--------------------------------------------------------------------------
    input  logic                     ready_buffer,  // Buffer ready for data
    input  logic                     valid_fec,     // Valid data from FEC

    //--------------------------------------------------------------------------
    // Data Interface
    //--------------------------------------------------------------------------
    input  logic                     data_in,       // Input data bit
    output logic                     data_out,      // Output data (pass-through)
    output logic [$clog2(Ncbps)-1:0] data_out_index,// Permuted address index

    //--------------------------------------------------------------------------
    // Handshaking Interface
    //--------------------------------------------------------------------------
    output logic                     ready_interleaver,  // Ready for input
    output logic                     valid_interleaver   // Output is valid
);

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // Input Counter and Intermediate Indices
    //--------------------------------------------------------------------------
    logic [$clog2(Ncbps)-1:0] k;        // Input bit index (0 to 191)
    logic [$clog2(Ncbps)-1:0] m;        // First permutation result
    logic [$clog2(Ncbps)-1:0] j;        // Second permutation result (output)

    //--------------------------------------------------------------------------
    // Enable Signal
    //--------------------------------------------------------------------------
    logic                     interleave_en;  // Enable interleaving

    //==========================================================================
    //
    //  INPUT INDEX COUNTER
    //
    //  Purpose:    Track current input bit position within block
    //  Range:      0 to 191 (Ncbps - 1)
    //  Operation:  Increment on each valid input, wrap at 191
    //
    //==========================================================================
    always_ff @(posedge clk or negedge resetN) begin
        if(resetN == 1'b0) begin
            k <= '0;
        end else if(interleave_en == 1'b1) begin
            if(k == 8'd191) k <= '0;
            else            k <= k + 1'b1;
        end
    end

    //==========================================================================
    //
    //  TWO-STEP PERMUTATION LOGIC
    //
    //  Implements IEEE 802.16-2007 equations for interleaving:
    //
    //  First Permutation (Equation 111):
    //  m(k) = (Ncbps/d) × (k mod d) + floor(k/d)
    //       = 12 × (k mod 16) + floor(k/16)   for QPSK
    //
    //  Second Permutation (Equation 112):
    //  j(m) = s × floor(m/s) + (m + Ncbps - floor(d×m/Ncbps)) mod s
    //       = floor(m/1) + (m + 192 - floor(16×m/192)) mod 1   for QPSK
    //       Simplifies to: j = m for QPSK (s=1)
    //
    //  Note: For QPSK with s=1, the second permutation has no effect
    //        since (anything mod 1) = 0
    //
    //==========================================================================
    always_comb begin
        // First permutation: distribute across frequency domain
        m = ((Ncbps/d) * (k % d)) + k/d;

        // Second permutation: alternate MSB/LSB reliability
        j = (s * (m/s)) + ((m + Ncbps - ((d * m)/Ncbps)) % s);

        // Output assignments
        data_out_index = j;
        data_out = data_in;
    end

    //==========================================================================
    //
    //  CONTROL SIGNAL GENERATION
    //
    //  interleave_en:  Active when FEC provides valid data AND buffer ready
    //  valid_interleaver: Mirrors enable (output valid when processing)
    //  ready_interleaver: Always ready (combinational path)
    //
    //==========================================================================
    always_comb begin
        if((valid_fec == 1'b1) && (ready_buffer == 1'b1)) begin
            interleave_en     = 1'b1;
            valid_interleaver = 1'b1;
        end else begin
            interleave_en     = 1'b0;
            valid_interleaver = 1'b0;
        end
        ready_interleaver     = 1'b1;
    end

endmodule