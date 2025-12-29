//==============================================================================
//
//  Module Name:    modulator_qpsk
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Quadrature Phase Shift Keying (QPSK) Modulator with Gray
//                  mapping. This module maps pairs of input bits to complex
//                  constellation symbols on the I/Q plane.
//
//                  QPSK Constellation (Gray Coded):
//                                    Q
//                                    │
//                         10         │         00
//                    (-0.707,+0.707) │    (+0.707,+0.707)
//                              ●     │     ●
//                                    │
//                  ──────────────────┼──────────────────── I
//                                    │
//                              ●     │     ●
//                    (-0.707,-0.707) │    (+0.707,-0.707)
//                         11         │         01
//                                    │
//
//                  Gray Mapping Table:
//                  ┌────────────┬────────────┬────────────┐
//                  │ Input (b0b1)│  I-comp    │  Q-comp    │
//                  ├────────────┼────────────┼────────────┤
//                  │     00     │  +0.707    │  +0.707    │
//                  │     01     │  +0.707    │  -0.707    │
//                  │     10     │  -0.707    │  +0.707    │
//                  │     11     │  -0.707    │  -0.707    │
//                  └────────────┴────────────┴────────────┘
//
//                  Fixed-Point Format:
//                  - Q15 format (1 sign bit, 15 fractional bits)
//                  - +0.707 ≈ 23170 = 0x5A82 = 0101_1010_1000_0010
//                  - -0.707 ≈ -23170 = 0xA57E = 1010_0101_0111_1110
//
//  Standard:       IEEE 802.16-2007 Section 8.4.9.4.3
//  Modulation:     QPSK with Gray mapping
//  Output Format:  16-bit Q15 fixed-point
//  Clock Domain:   100 MHz
//
//  Authors:        Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Supervisor:     Dr. Ahmed Abou Auf
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        7.0
//  Date:           2025-12-19
//
//==============================================================================

module modulator_qpsk
    import wimax_pkg::*;
(
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic        clk,            // System clock (100 MHz)
    input  logic        rst_n,          // Active-low asynchronous reset

    //--------------------------------------------------------------------------
    // Data Input Interface (Upstream - from Interleaver)
    //--------------------------------------------------------------------------
    input  logic        i_valid,        // Input data valid indicator
    input  logic        i_data,         // Input data bit
    output logic        i_ready,        // Ready to accept input data

    //--------------------------------------------------------------------------
    // Data Output Interface (Downstream - to DAC/Testbench)
    //--------------------------------------------------------------------------
    output logic        o_valid,        // Output data valid indicator
    output logic [15:0] I_comp,         // In-phase component (Q15)
    output logic [15:0] Q_comp,         // Quadrature component (Q15)
    input  logic        o_ready         // Downstream module ready signal
);

    //==========================================================================
    //
    //  CONSTELLATION POINT CONSTANTS
    //
    //  Q15 Fixed-Point Representation:
    //  - Full scale = ±1.0 = ±32768
    //  - 0.707 × 32768 = 23170.475... ≈ 23170
    //  - These values satisfy |I|² + |Q|² = 1 (unit power constraint)
    //
    //==========================================================================
    localparam logic [15:0] POS_A = 16'b0101_1010_1000_0010;  // +23170 ≈ +0.707
    localparam logic [15:0] NEG_A = 16'b1010_0101_0111_1110;  // -23170 ≈ -0.707

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================
    logic bit_count;                    // Bit pair counter (toggle each bit)
    logic b0;                           // Stored first bit of pair

    //==========================================================================
    //
    //  BIT COLLECTION LOGIC
    //
    //  Operation:
    //  - bit_count = 1: Waiting for first bit (b0)
    //  - bit_count = 0: Have first bit, waiting for second bit (b1)
    //  - On second bit: Output symbol based on {b0, b1}
    //
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            bit_count <= 1'b1;
            b0        <= 1'b0;
        end else begin
            if (o_ready == 1'b1 && i_valid == 1'b1) begin
                if (bit_count == 1'b1) begin
                    b0        <= i_data;
                    bit_count <= ~bit_count;
                end else if (bit_count == 1'b0) begin
                    bit_count <= ~bit_count;
                end
            end
        end
    end

    //==========================================================================
    //
    //  I/Q MAPPING LOGIC
    //
    //  Maps bit pair {b0, i_data} to constellation point using Gray coding:
    //  - b0 determines I sign (0 = positive, 1 = negative)
    //  - b1 determines Q sign (0 = positive, 1 = negative)
    //
    //  Symbol is output when second bit (b1) arrives
    //
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            I_comp  <= 16'b0;
            Q_comp  <= 16'b0;
            o_valid <= 1'b0;
        end else if ((o_ready == 1'b1) && (i_valid == 1'b1) && (bit_count == 1'b0)) begin
            case ({b0, i_data})
                2'b00: begin I_comp <= POS_A; Q_comp <= POS_A; end
                2'b01: begin I_comp <= POS_A; Q_comp <= NEG_A; end
                2'b10: begin I_comp <= NEG_A; Q_comp <= POS_A; end
                2'b11: begin I_comp <= NEG_A; Q_comp <= NEG_A; end
            endcase
            o_valid <= 1'b1;
        end
    end

    //==========================================================================
    //
    //  READY SIGNAL LOGIC
    //
    //  Modulator is ready when reset is not active AND downstream is ready
    //
    //==========================================================================
    assign i_ready = (rst_n && o_ready);

endmodule