//==============================================================================
//
//  Module Name:    interleaver_top
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Top-level wrapper for the WiMAX interleaver subsystem.
//                  This module integrates the interleaver core logic with a
//                  ping-pong buffer to enable continuous streaming operation.
//
//                  System Architecture:
//                  ┌─────────────────────────────────────────────────────────┐
//                  │                    interleaver_top                      │
//                  │                                                         │
//                  │  ┌──────────────┐         ┌────────────────────────┐   │
//                  │  │              │         │                        │   │
//                  │  │  Interleaver │─────────►    Ping-Pong Buffer    │   │
//                  │  │    (Core)    │  Index  │     (Dual SDPR)        │   │
//                  │  │              │         │                        │   │
//                  │  └──────────────┘         └────────────────────────┘   │
//                  │        ▲                            │                  │
//                  │        │                            │                  │
//                  └────────┼────────────────────────────┼──────────────────┘
//                           │                            │
//                      data_in                       data_out
//                      valid_in                      valid_out
//
//                  The interleaver reorders bits within a 192-bit block to
//                  spread burst errors across multiple symbols, improving
//                  the effectiveness of the FEC decoder.
//
//  Standard:       IEEE 802.16-2007 Section 8.4.9.3
//  Block Size:     Ncbps = 192 bits (for QPSK modulation)
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

module interleaver_top #(
    //--------------------------------------------------------------------------
    // Design Parameters
    //--------------------------------------------------------------------------
    parameter Ncbps = 192,              // Coded bits per OFDM symbol
    parameter Ncpc  = 2,                // Coded bits per subcarrier (QPSK = 2)
    parameter s     = Ncpc/2,           // Permutation parameter s = 1
    parameter d     = 16                // Permutation parameter d = 16
) (
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic clk,                   // System clock (100 MHz)
    input  logic reset_N,               // Active-low asynchronous reset

    //--------------------------------------------------------------------------
    // Data Input Interface (Upstream - from FEC Encoder)
    //--------------------------------------------------------------------------
    input  logic data_in,               // Input data bit
    input  logic valid_in,              // Input data valid indicator
    output logic ready_out,             // Ready to accept input data

    //--------------------------------------------------------------------------
    // Data Output Interface (Downstream - to Modulator)
    //--------------------------------------------------------------------------
    input  logic ready_in,              // Downstream module ready signal
    output logic data_out,              // Interleaved output data bit
    output logic valid_out              // Output data valid indicator
);

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // Interleaver Core to Ping-Pong Buffer Interface
    //--------------------------------------------------------------------------
    logic [7:0] data_out_index;         // Permuted address from interleaver
    logic       ready_interleaver;      // Ready signal from interleaver
    logic       valid_interleaver;      // Valid signal from interleaver
    logic       data_interleaved;       // Data from interleaver

    //--------------------------------------------------------------------------
    // Read Address Counter
    //--------------------------------------------------------------------------
    logic [7:0] rdaddress;              // Sequential read address (0-191)

    //==========================================================================
    //
    //  INTERLEAVER CORE INSTANCE
    //
    //  Purpose:    Compute permuted write address for each input bit
    //  Operation:  Two-step permutation per IEEE 802.16-2007
    //              Step 1: m = (Ncbps/d) * (k mod d) + floor(k/d)
    //              Step 2: j = s * floor(m/s) + (m + Ncbps - floor(d*m/Ncbps)) mod s
    //
    //==========================================================================
    interleaver Interleaver_inst (
        .clk(clk),
        .resetN(reset_N),
        .ready_buffer(ready_out),
        .valid_fec(valid_in),
        .data_in(data_in),
        .data_out(data_interleaved),
        .data_out_index(data_out_index),
        .ready_interleaver(ready_interleaver),
        .valid_interleaver(valid_interleaver)
    );

    //==========================================================================
    //
    //  PING-PONG BUFFER INSTANCE
    //
    //  Purpose:    Double-buffering for continuous streaming
    //  Operation:  Write to one buffer while reading from the other
    //  Memory:     Dual SDPR (Simple Dual-Port RAM) banks
    //
    //==========================================================================
    PPBuffer PingPongBuffer_inst (
        .clk(clk),
        .resetN(reset_N),
        .wraddress(data_out_index),
        .wrdata(data_interleaved),
        .rdaddress(rdaddress),
        .valid_in(valid_interleaver),
        .ready_in(ready_in),
        .q(data_out),
        .valid_out(valid_out),
        .ready_out(ready_out)
    );

    //==========================================================================
    //
    //  READ ADDRESS COUNTER
    //
    //  Purpose:    Generate sequential read addresses for output
    //  Operation:  Increment from 0 to 191, then wrap to 0
    //  Trigger:    Increments when valid input is received
    //
    //==========================================================================
    always_ff @(posedge clk or negedge reset_N) begin
        if(reset_N == 1'b0) begin
            rdaddress <= '0;
        end else if((valid_in) == 1'b1) begin
            if(rdaddress == 191) begin
                rdaddress <= '0;
            end else begin
                rdaddress <= rdaddress + 1'b1;
            end
        end
    end

endmodule