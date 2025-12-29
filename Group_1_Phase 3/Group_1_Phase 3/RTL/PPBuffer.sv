//==============================================================================
//
//  Module Name:    PPBuffer
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Ping-Pong Buffer module for continuous streaming operation.
//                  This module implements double-buffering using two Simple
//                  Dual-Port RAM (SDPR) banks, allowing simultaneous read
//                  from one bank while writing to the other.
//
//                  Ping-Pong Buffer Architecture:
//                  ┌─────────────────────────────────────────────────────────┐
//                  │                        PPBuffer                         │
//                  │                                                         │
//                  │  ┌──────────────┐                                       │
//                  │  │   Bank A     │◄──── wrdata (when wren_A active)     │
//                  │  │   (SDPR)     │────► q_A ────┐                       │
//                  │  └──────────────┘              │                       │
//                  │                                ▼                       │
//                  │  ┌──────────────┐        ┌─────────┐                   │
//                  │  │   Bank B     │◄───────│   MUX   │───► q (output)    │
//                  │  │   (SDPR)     │────►   │ (q_sel) │                   │
//                  │  └──────────────┘  q_B   └─────────┘                   │
//                  │                                                         │
//                  │  ┌──────────────────────────────────────────────────┐  │
//                  │  │              PPBufferControl                      │  │
//                  │  │    (FSM controlling read/write enables)          │  │
//                  │  └──────────────────────────────────────────────────┘  │
//                  └─────────────────────────────────────────────────────────┘
//
//                  Operation:
//                  - While Block N is being written to Bank A:
//                    Block N-1 is read from Bank B
//                  - After 192 bits, roles swap:
//                    Block N+1 writes to Bank B, Block N reads from Bank A
//
//  Memory Size:    192 bits per bank (192 × 1-bit SDPR)
//  Clock Domain:   100 MHz
//
//  Authors:        Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Supervisor:     Dr. Ahmed Abou Auf
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        3.0
//  Date:           2025-12-19
//
//==============================================================================

module PPBuffer (
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic       clk,             // System clock (100 MHz)
    input  logic       resetN,          // Active-low asynchronous reset

    //--------------------------------------------------------------------------
    // Write Interface (from Interleaver)
    //--------------------------------------------------------------------------
    input  logic [7:0] wraddress,       // Write address (permuted index)
    input  logic       wrdata,          // Write data bit

    //--------------------------------------------------------------------------
    // Read Interface
    //--------------------------------------------------------------------------
    input  logic [7:0] rdaddress,       // Read address (sequential)

    //--------------------------------------------------------------------------
    // Handshaking Interface
    //--------------------------------------------------------------------------
    input  logic       valid_in,        // Input data valid
    input  logic       ready_in,        // Downstream ready
    output logic       q,               // Output data bit
    output logic       valid_out,       // Output data valid
    output logic       ready_out        // Ready for input
);

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // RAM Output Signals
    //--------------------------------------------------------------------------
    logic q_A;                          // Output from Bank A
    logic q_B;                          // Output from Bank B

    //--------------------------------------------------------------------------
    // Control Signals from FSM
    //--------------------------------------------------------------------------
    logic rden_A;                       // Read enable for Bank A
    logic rden_B;                       // Read enable for Bank B
    logic wren_A;                       // Write enable for Bank A
    logic wren_B;                       // Write enable for Bank B

    //==========================================================================
    //
    //  BUFFER CONTROL FSM INSTANCE
    //
    //  Purpose:    Control ping-pong switching between banks
    //  States:     IDLE → CLEAR → WRITE_A ↔ WRITE_B
    //  Output:     Selects which bank to read and which to write
    //
    //==========================================================================
    PPBufferControl BufferControl (
        .clk(clk),
        .resetN(resetN),
        .valid_in(valid_in),
        .q_A(q_A),
        .q_B(q_B),
        .rden_A(rden_A),
        .rden_B(rden_B),
        .wren_A(wren_A),
        .wren_B(wren_B),
        .ready_in(ready_in),
        .ready_out(ready_out),
        .valid_out(valid_out),
        .q(q)
    );

    //==========================================================================
    //
    //  BANK A - SIMPLE DUAL-PORT RAM INSTANCE
    //
    //  Purpose:    First storage bank for ping-pong operation
    //  Size:       192 × 1-bit
    //  IP Core:    SDPR (Altera/Intel Simple Dual-Port RAM)
    //
    //==========================================================================
    SDPR BankA (
        .clock(clk),
        .data(wrdata),
        .wraddress(wraddress),
        .wren(wren_A),
        .rdaddress(rdaddress),
        .rden(rden_A),
        .q(q_A)
    );

    //==========================================================================
    //
    //  BANK B - SIMPLE DUAL-PORT RAM INSTANCE
    //
    //  Purpose:    Second storage bank for ping-pong operation
    //  Size:       192 × 1-bit
    //  IP Core:    SDPR (Altera/Intel Simple Dual-Port RAM)
    //
    //==========================================================================
    SDPR BankB (
        .clock(clk),
        .data(wrdata),
        .wraddress(wraddress),
        .wren(wren_B),
        .rdaddress(rdaddress),
        .rden(rden_B),
        .q(q_B)
    );

endmodule