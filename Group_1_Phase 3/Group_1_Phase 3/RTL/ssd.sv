//==============================================================================
//
//  Module Name:    ssd
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Seven-Segment Display (SSD) decoder for the DE0-CV FPGA
//                  development board. This module converts a 4-bit binary
//                  input to the corresponding 7-segment display pattern.
//
//                  Seven-Segment Display Layout:
//                       ─────
//                      │  a  │
//                       ─────
//                     f│     │b
//                       ─────
//                      │  g  │
//                       ─────
//                     e│     │c
//                       ─────
//                      │  d  │
//                       ─────
//
//                  Segment Encoding: [6:0] = [g:a]
//                  Active-LOW outputs (0 = segment ON, 1 = segment OFF)
//                  This is standard for common-anode displays on DE0-CV
//
//                  Character Map:
//                  ┌───────┬─────────────┬───────────────────────────────────┐
//                  │ Input │   Display   │ Segments (a b c d e f g)          │
//                  ├───────┼─────────────┼───────────────────────────────────┤
//                  │ 0x0   │      0      │ ● ● ● ● ● ● ○ (1000000)           │
//                  │ 0x1   │      1      │ ○ ● ● ○ ○ ○ ○ (1111001)           │
//                  │ 0x2   │      2      │ ● ● ○ ● ● ○ ● (0100100)           │
//                  │ 0x3   │      3      │ ● ● ● ● ○ ○ ● (0110000)           │
//                  │ 0x4   │      4      │ ○ ● ● ○ ○ ● ● (0011001)           │
//                  │ 0x5   │      5      │ ● ○ ● ● ○ ● ● (0010010)           │
//                  │ 0x6   │      6      │ ● ○ ● ● ● ● ● (0000010)           │
//                  │ 0x7   │      7      │ ● ● ● ○ ○ ○ ○ (1111000)           │
//                  │ 0x8   │      8      │ ● ● ● ● ● ● ● (0000000)           │
//                  │ 0x9   │      9      │ ● ● ● ● ○ ● ● (0010000)           │
//                  │ 0xA   │      A      │ ● ● ● ○ ● ● ● (0001000)           │
//                  │ 0xB   │      b      │ ○ ○ ● ● ● ● ● (0000011)           │
//                  │ 0xC   │      C      │ ● ○ ○ ● ● ● ○ (1000110)           │
//                  │ 0xD   │      d      │ ○ ● ● ● ● ○ ● (0100001)           │
//                  │ 0xE   │      E      │ ● ○ ○ ● ● ● ● (0000110)           │
//                  │ 0xF   │      F      │ ● ○ ○ ○ ● ● ● (0001110)           │
//                  └───────┴─────────────┴───────────────────────────────────┘
//                  ● = ON (0), ○ = OFF (1)
//
//  Target Board:   Terasic DE0-CV (Cyclone V FPGA)
//  Display Type:   Common-anode 7-segment display (active-low)
//
//  Author:         Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        2.0
//  Date:           2025-12-15
//
//==============================================================================

module ssd (
    //--------------------------------------------------------------------------
    // Input Interface
    //--------------------------------------------------------------------------
    input  logic [3:0] BCD,             // 4-bit binary input (0-F)

    //--------------------------------------------------------------------------
    // Output Interface
    //--------------------------------------------------------------------------
    output logic [6:0] SSD              // 7-segment output [6:0] = [g:a]
);

    //==========================================================================
    //
    //  COMBINATIONAL DECODER LOGIC
    //
    //  Converts 4-bit binary input to 7-segment display pattern.
    //  Output is active-LOW: 0 turns segment ON, 1 turns segment OFF.
    //
    //==========================================================================
    always_comb begin
        case (BCD)
            //------------------------------------------------------------------
            // Numeric Digits (0-9)
            //------------------------------------------------------------------
            4'h0: SSD = 7'b1000000;     // "0" - segments: a,b,c,d,e,f ON
            4'h1: SSD = 7'b1111001;     // "1" - segments: b,c ON
            4'h2: SSD = 7'b0100100;     // "2" - segments: a,b,g,e,d ON
            4'h3: SSD = 7'b0110000;     // "3" - segments: a,b,g,c,d ON
            4'h4: SSD = 7'b0011001;     // "4" - segments: f,g,b,c ON
            4'h5: SSD = 7'b0010010;     // "5" - segments: a,f,g,c,d ON
            4'h6: SSD = 7'b0000010;     // "6" - segments: a,f,g,e,d,c ON
            4'h7: SSD = 7'b1111000;     // "7" - segments: a,b,c ON
            4'h8: SSD = 7'b0000000;     // "8" - segments: all ON
            4'h9: SSD = 7'b0010000;     // "9" - segments: a,b,c,d,f,g ON

            //------------------------------------------------------------------
            // Hexadecimal Letters (A-F)
            //------------------------------------------------------------------
            4'hA: SSD = 7'b0001000;     // "A" - segments: a,b,c,e,f,g ON
            4'hB: SSD = 7'b0000011;     // "b" - segments: c,d,e,f,g ON (lowercase)
            4'hC: SSD = 7'b1000110;     // "C" - segments: a,d,e,f ON
            4'hD: SSD = 7'b0100001;     // "d" - segments: b,c,d,e,g ON (lowercase)
            4'hE: SSD = 7'b0000110;     // "E" - segments: a,d,e,f,g ON
            4'hF: SSD = 7'b0001110;     // "F" - segments: a,e,f,g ON

            //------------------------------------------------------------------
            // Default Case (Invalid Input)
            //------------------------------------------------------------------
            default: SSD = 7'b1111111;  // All segments OFF
        endcase
    end

endmodule