//==============================================================================
//
//  Module Name:    prbs_randomizer
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Pseudo-Random Binary Sequence (PRBS) Randomizer for the
//                  WiMAX physical layer. This module performs data whitening
//                  by XORing input data with a pseudo-random sequence generated
//                  by a Linear Feedback Shift Register (LFSR).
//
//                  The randomizer ensures that the transmitted signal has a
//                  uniform spectral distribution, which helps with:
//                  - Clock recovery at the receiver
//                  - Avoiding spectral lines in the transmitted signal
//                  - Improving error correction performance
//
//                  LFSR Architecture:
//                  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
//                  │15 │14 │13 │12 │11 │10 │ 9 │ 8 │ 7 │ 6 │ 5 │ 4 │ 3 │ 2 │ 1 │
//                  └─┬─┴─┬─┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴─┬─┘
//                    │   │                                                   │
//                    │   └─────────────────────►XOR──────────────────────────┘
//                    │                           │
//                    └───────────────────────────┼───────────────────►XOR──► Output
//                                                │                     ▲
//                                                └─────────────────────┘
//                                                                      │
//                                                               Data Input
//
//                  The LFSR automatically resets to the initial seed every
//                  96 bits to align with FEC block boundaries.
//
//  Standard:       IEEE 802.16-2007 Section 8.4.9.1
//  Polynomial:     1 + x^14 + x^15 (primitive polynomial)
//  Initial Seed:   Defined in wimax_pkg (typically 15'b100101010000000)
//
//  Authors:        Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Supervisor:     Dr. Ahmed Abou Auf
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        3.0
//  Date:           2025-12-19
//
//==============================================================================

module prbs_randomizer
    import wimax_pkg::*;
(
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic        clk,            // System clock (50 MHz)
    input  logic        rst_n,          // Active-low asynchronous reset

    //--------------------------------------------------------------------------
    // Control Interface
    //--------------------------------------------------------------------------
    input  logic        load,           // Load LFSR with initial seed
    input  logic        en,             // Enable PRBS operation

    //--------------------------------------------------------------------------
    // Data Input Interface (Upstream - from Testbench/Data Source)
    //--------------------------------------------------------------------------
    input  logic        i_valid,        // Input data valid indicator
    input  logic        i_data,         // Input data bit
    output logic        i_ready,        // Ready to accept input data

    //--------------------------------------------------------------------------
    // Data Output Interface (Downstream - to FEC Encoder)
    //--------------------------------------------------------------------------
    output logic        o_valid,        // Output data valid indicator
    output logic        o_data,         // Randomized output data bit
    input  logic        o_ready         // Downstream module ready signal
);

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // LFSR State Registers
    // Note: [1:15] indexing used to match IEEE 802.16 specification notation
    //--------------------------------------------------------------------------
    logic [1:15] r_reg;                 // Current LFSR state
    logic [1:15] r_next;                // Next LFSR state

    //--------------------------------------------------------------------------
    // Processing Signals
    //--------------------------------------------------------------------------
    logic        lfsr_xor;              // XOR of feedback taps
    logic [6:0]  counter;               // Bit counter (0-95 for 96-bit blocks)

    //==========================================================================
    //
    //  LFSR FEEDBACK LOGIC
    //
    //  The feedback polynomial is 1 + x^14 + x^15, which means:
    //  - Tap positions 14 and 15 are XORed together
    //  - The result is fed back to position 1 (MSB after shift)
    //
    //==========================================================================
    always_comb begin
        lfsr_xor = r_reg[15] ^ r_reg[14];
        r_next   = {lfsr_xor, r_reg[1:14]};
    end

    //==========================================================================
    //
    //  MAIN SEQUENTIAL LOGIC
    //
    //  State Machine Operation:
    //  1. On reset: Clear all registers
    //  2. On load:  Initialize LFSR with seed, prepare for operation
    //  3. On enable with valid input:
    //     a. Advance LFSR to next state
    //     b. XOR input data with LFSR output
    //     c. Increment bit counter
    //     d. Reset LFSR when 96-bit block completes
    //
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            //------------------------------------------------------------------
            // Asynchronous Reset - Clear all state
            //------------------------------------------------------------------
            r_reg   <= '0;
            i_ready <= 1'b0;
            o_valid <= 1'b0;
            counter <= '0;
            o_data  <= '0;
        end
        else if (load) begin
            //------------------------------------------------------------------
            // Load Operation - Initialize LFSR with seed
            //------------------------------------------------------------------
            r_reg   <= SEED;
            i_ready <= 1'b1;
            o_valid <= 1'b0;
        end
        else if (en && i_valid) begin
            //------------------------------------------------------------------
            // Normal Processing - Randomize input data
            //------------------------------------------------------------------
            r_reg   <= r_next;
            i_ready <= 1'b1;
            o_valid <= 1'b1;
            o_data  <= i_data ^ lfsr_xor;

            //------------------------------------------------------------------
            // Block Boundary Counter Logic
            // Reset LFSR every 96 bits to align with FEC block boundaries
            //------------------------------------------------------------------
            if (counter == 7'd95) begin
                counter <= 7'd0;
                r_reg   <= SEED;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule