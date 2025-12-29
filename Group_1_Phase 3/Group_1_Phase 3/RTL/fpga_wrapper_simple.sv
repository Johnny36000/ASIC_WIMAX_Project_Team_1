//==============================================================================
//
//  Module Name:    fpga_wrapper_simple
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    FPGA wrapper module for the DE0-CV development board that
//                  provides hardware verification of the WiMAX PHY layer.
//                  This module interfaces the PHY processing pipeline with
//                  board I/O and performs golden data verification.
//
//                  System Block Diagram:
//                  ┌──────────────────────────────────────────────────────────┐
//                  │                   fpga_wrapper_simple                    │
//                  │                                                          │
//                  │  ┌─────────┐     ┌───────────────────────────────────┐  │
//                  │  │ Button  │────►│                                   │  │
//                  │  │Debounce │     │            phy_top                │  │
//                  │  └─────────┘     │   (PRBS→FEC→Interleaver→QPSK)    │  │
//                  │                  │                                   │  │
//                  │  ┌─────────┐     └───────────────────────────────────┘  │
//                  │  │ Golden  │                    │                       │
//                  │  │  Data   │◄───────────────────┘                       │
//                  │  │ Compare │                                            │
//                  │  └────┬────┘                                            │
//                  │       │                                                 │
//                  │       ▼                                                 │
//                  │  ┌─────────┐                                            │
//                  │  │  LED    │───► LEDR[9:0]                              │
//                  │  │ Status  │                                            │
//                  │  └─────────┘                                            │
//                  └──────────────────────────────────────────────────────────┘
//
//                  Verification Features:
//                  - Multi-packet verification (configurable, default 5)
//                  - Golden data comparison at each processing stage
//                  - Latched pass/fail status for reliable LED indication
//                  - Single-shot and continuous operation modes
//
//                  LED Assignments:
//                  ┌────────┬──────────────────────────────────────────────┐
//                  │  LED   │                  Function                    │
//                  ├────────┼──────────────────────────────────────────────┤
//                  │ LEDR[0]│ PRBS Pass (ON=All pass, OFF=Any fail)       │
//                  │ LEDR[1]│ FEC Pass (ON=All pass, OFF=Any fail)        │
//                  │ LEDR[2]│ Interleaver Pass (ON=All pass, OFF=Any fail)│
//                  │ LEDR[3]│ Modulator Pass (ON=All pass, OFF=Any fail)  │
//                  │ LEDR[4]│ PRBS Verification Complete                  │
//                  │ LEDR[5]│ FEC Verification Complete                   │
//                  │ LEDR[6]│ Interleaver Verification Complete           │
//                  │ LEDR[7]│ Modulator Verification Complete             │
//                  │ LEDR[8]│ Enable Active                               │
//                  │ LEDR[9]│ PLL Locked                                  │
//                  └────────┴──────────────────────────────────────────────┘
//
//  Target Board:   Terasic DE0-CV (Cyclone V FPGA)
//
//  Authors:        Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Supervisor:     Dr. Ahmed Abou Auf
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        6.0
//  Date:           2025-12-20
//
//==============================================================================

import wimax_pkg::*;

module fpga_wrapper_simple (
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic        CLOCK_50,       // 50 MHz board oscillator
    input  logic        KEY0,           // Reset button (active-low)
    input  logic        KEY1,           // Load/Start button (active-low)

    //--------------------------------------------------------------------------
    // Control Interface
    //--------------------------------------------------------------------------
    input  logic        SW0,            // Mode select (0=single-shot, 1=continuous)

    //--------------------------------------------------------------------------
    // Status LED Interface
    //--------------------------------------------------------------------------
    output logic [9:0]  LEDR            // Status LEDs (active-high)
);

    //==========================================================================
    //
    //  CONFIGURATION PARAMETER
    //
    //==========================================================================
    parameter int NUM_PACKETS = 5;      // Number of packets to verify

    //==========================================================================
    //
    //  GOLDEN DATA REFERENCES
    //
    //  These constants are imported from wimax_pkg and represent the
    //  expected output at each processing stage for verification.
    //
    //==========================================================================
    const logic [95:0]  PRBS_INPUT         = RANDOMIZER_INPUT;
    const logic [95:0]  PRBS_OUTPUT        = RANDOMIZER_OUTPUT;
    const logic [191:0] FEC_ENCODER_OUT    = FEC_ENCODER_OUTPUT;
    const logic [191:0] INTER_OUTPUT       = INTERLEAVER_OUTPUT;
    const logic [1:0]   MODULATOR_OUT [0:95] = MOD_OUTPUT;

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // PLL Signals
    //--------------------------------------------------------------------------
    logic clk_50;                       // 50 MHz clock from PLL
    logic clk_100;                      // 100 MHz clock from PLL
    logic pll_locked;                   // PLL lock indicator

    //--------------------------------------------------------------------------
    // Randomizer Interface Signals
    //--------------------------------------------------------------------------
    logic       randomizer_data_in;     // Input data to randomizer
    logic       randomizer_valid_in;    // Input valid to randomizer
    logic       randomizer_ready_out;   // Ready output from randomizer
    logic [6:0] randomizer_in_counter;  // Input bit counter
    logic       randomizer_data_out;    // Output data from randomizer
    logic       randomizer_valid_out;   // Output valid from randomizer
    logic [6:0] randomizer_out_counter; // Output bit counter
    logic       randomizer_block_error; // Block error flag
    logic [3:0] randomizer_packet_count;// Verified packet counter

    //--------------------------------------------------------------------------
    // FEC Encoder Signals
    //--------------------------------------------------------------------------
    logic       FEC_data_out;           // Output data from FEC
    logic       FEC_valid_out;          // Output valid from FEC
    logic [7:0] FEC_counter;            // Output bit counter
    logic       FEC_block_error;        // Block error flag
    logic [3:0] FEC_packet_count;       // Verified packet counter

    //--------------------------------------------------------------------------
    // Interleaver Signals
    //--------------------------------------------------------------------------
    logic       interleaver_data_out;   // Output data from interleaver
    logic       interleaver_valid_out;  // Output valid from interleaver
    logic [7:0] interleaver_counter;    // Output bit counter
    logic       interleaver_block_error;// Block error flag
    logic [3:0] interleaver_packet_count;// Verified packet counter

    //--------------------------------------------------------------------------
    // Modulator Signals
    //--------------------------------------------------------------------------
    logic        mod_ready_in;          // Ready signal to modulator
    logic [15:0] mod_I_comp;            // I component from modulator
    logic [15:0] mod_Q_comp;            // Q component from modulator
    logic        mod_valid_out;         // Valid output from modulator
    logic [6:0]  mod_counter;           // Symbol counter
    logic        mod_block_error;       // Block error flag
    logic        mod_valid_count;       // Toggle for 2-bit symbol capture
    logic [3:0]  mod_packet_count;      // Verified packet counter

    //--------------------------------------------------------------------------
    // Latched Pass/Fail Status Registers
    // Start as PASS (1), set to FAIL (0) if any packet fails
    //--------------------------------------------------------------------------
    logic prbs_pass_latched;            // PRBS cumulative pass status
    logic fec_pass_latched;             // FEC cumulative pass status
    logic interleaver_pass_latched;     // Interleaver cumulative pass status
    logic modulator_pass_latched;       // Modulator cumulative pass status

    //--------------------------------------------------------------------------
    // Verification Complete Flags
    //--------------------------------------------------------------------------
    logic prbs_verified;                // PRBS verification complete
    logic fec_verified;                 // FEC verification complete
    logic interleaver_verified;         // Interleaver verification complete
    logic modulator_verified;           // Modulator verification complete
    logic all_verified;                 // All stages verified

    //--------------------------------------------------------------------------
    // Control Signals
    //--------------------------------------------------------------------------
    logic       load;                   // Load/initialize signal
    logic       en;                     // Enable operation
    logic       reset_N;                // Active-low reset
    logic       transmission_started;   // Transmission has begun

    //--------------------------------------------------------------------------
    // Button Debounce Signals
    //--------------------------------------------------------------------------
    logic [19:0] debounce_cnt;          // Debounce counter
    logic        key1_stable;           // Stable button state
    logic        key1_debounced;        // Debounced button output
    logic        key1_prev;             // Previous button state
    logic        key1_pressed;          // Button press edge detect

    //==========================================================================
    //
    //  ALL VERIFIED FLAG
    //
    //==========================================================================
    assign all_verified = prbs_verified && fec_verified &&
                          interleaver_verified && modulator_verified;

    //==========================================================================
    //
    //  RESET SIGNAL ASSIGNMENT
    //
    //==========================================================================
    assign reset_N = KEY0;

    //==========================================================================
    //
    //  BUTTON DEBOUNCE LOGIC
    //
    //  Debounces KEY1 to prevent multiple triggers from mechanical bounce.
    //  Uses a 500,000 cycle counter (~10ms at 50MHz) for stable detection.
    //
    //==========================================================================
    always_ff @(posedge CLOCK_50 or negedge reset_N) begin
        if (!reset_N) begin
            debounce_cnt <= 20'd0;
            key1_stable <= 1'b1;
            key1_debounced <= 1'b1;
        end else begin
            if (KEY1 != key1_stable) begin
                if (debounce_cnt < 500_000) begin
                    debounce_cnt <= debounce_cnt + 20'd1;
                end else begin
                    key1_stable <= KEY1;
                    key1_debounced <= KEY1;
                    debounce_cnt <= 20'd0;
                end
            end else begin
                debounce_cnt <= 20'd0;
            end
        end
    end

    //==========================================================================
    //
    //  EDGE DETECTION AND CONTROL LOGIC
    //
    //  Detects falling edge of debounced button for single-pulse load signal.
    //  Manages enable signal based on operation mode (single-shot vs continuous).
    //
    //==========================================================================
    always_ff @(posedge clk_50 or negedge reset_N) begin
        if (!reset_N) begin
            key1_prev <= 1'b1;
            key1_pressed <= 1'b0;
            load <= 1'b0;
            en <= 1'b0;
            transmission_started <= 1'b0;
        end else begin
            key1_prev <= key1_debounced;
            key1_pressed <= key1_prev & ~key1_debounced;

            if (key1_pressed) begin
                load <= 1'b1;
                transmission_started <= 1'b1;
            end else begin
                load <= 1'b0;
            end

            // Enable logic with single-shot termination
            if (transmission_started) begin
                if (SW0) begin
                    // Continuous mode: always enabled
                    en <= 1'b1;
                end else begin
                    // Single-shot mode: disable after all verified
                    if (all_verified) begin
                        en <= 1'b0;
                    end else begin
                        en <= 1'b1;
                    end
                end
            end
        end
    end

    //==========================================================================
    //
    //  PHY TOP INSTANCE
    //
    //  Main WiMAX PHY processing pipeline
    //
    //==========================================================================
    phy_top WiMAX_PHY_U0 (
        .clk_ref          (CLOCK_50),
        .reset_N          (reset_N),
        .data_in          (randomizer_data_in),
        .load             (load),
        .en               (en),
        .valid_in         (randomizer_valid_in),
        .ready_in         (mod_ready_in),
        .ready_out        (randomizer_ready_out),
        .valid_out        (mod_valid_out),
        .clk_50           (clk_50),
        .clk_100          (clk_100),
        .locked           (pll_locked),
        .prbs_out         (randomizer_data_out),
        .prbs_valid       (randomizer_valid_out),
        .fec_out          (FEC_data_out),
        .fec_valid        (FEC_valid_out),
        .interleaver_out  (interleaver_data_out),
        .interleaver_valid(interleaver_valid_out),
        .I_comp           (mod_I_comp),
        .Q_comp           (mod_Q_comp)
    );

    //==========================================================================
    //
    //  CONTROL SIGNAL GENERATION
    //
    //==========================================================================
    always_comb begin
        mod_ready_in = reset_N;
        randomizer_valid_in = reset_N;
    end

    //==========================================================================
    //
    //  PRBS INPUT SERIALIZATION
    //
    //  Continuously feeds golden input data to the randomizer.
    //  Counter wraps from 95 to 0 to repeat the same test pattern.
    //
    //==========================================================================
    always_ff @(posedge clk_50 or negedge reset_N) begin
        if (~reset_N) begin
            randomizer_in_counter <= 7'd95;
        end else if (randomizer_ready_out && en && randomizer_valid_in) begin
            if (randomizer_in_counter == 7'd0) begin
                randomizer_in_counter <= 7'd95;
            end else begin
                randomizer_in_counter <= randomizer_in_counter - 1'b1;
            end
        end
    end

    assign randomizer_data_in = PRBS_INPUT[randomizer_in_counter];

    //==========================================================================
    //
    //  PRBS OUTPUT VERIFICATION
    //
    //  Compares randomizer output against golden data.
    //  Verifies NUM_PACKETS packets; LED goes OFF if ANY packet fails.
    //
    //==========================================================================
    always_ff @(posedge clk_50 or negedge reset_N) begin
        if (~reset_N) begin
            randomizer_out_counter   <= 7'd95;
            randomizer_block_error   <= 1'b0;
            randomizer_packet_count  <= 4'd0;
            prbs_pass_latched        <= 1'b1;
            prbs_verified            <= 1'b0;
        end else begin
            if (randomizer_valid_out && !prbs_verified) begin
                // Compare current bit with golden data
                if (randomizer_data_out !== PRBS_OUTPUT[randomizer_out_counter]) begin
                    randomizer_block_error <= 1'b1;
                end

                // Check if packet complete
                if (randomizer_out_counter == 7'd0) begin
                    if (randomizer_block_error) begin
                        prbs_pass_latched <= 1'b0;
                    end

                    if (randomizer_packet_count == NUM_PACKETS - 1) begin
                        prbs_verified <= 1'b1;
                    end else begin
                        randomizer_packet_count <= randomizer_packet_count + 1'b1;
                    end

                    randomizer_out_counter <= 7'd95;
                    randomizer_block_error <= 1'b0;
                end else begin
                    randomizer_out_counter <= randomizer_out_counter - 1'b1;
                end
            end
        end
    end

    //==========================================================================
    //
    //  FEC OUTPUT VERIFICATION
    //
    //  Compares FEC encoder output against golden data.
    //  Operates at 100 MHz clock domain.
    //
    //==========================================================================
    always_ff @(posedge clk_100 or negedge reset_N) begin
        if (~reset_N) begin
            FEC_counter         <= 8'd191;
            FEC_block_error     <= 1'b0;
            FEC_packet_count    <= 4'd0;
            fec_pass_latched    <= 1'b1;
            fec_verified        <= 1'b0;
        end else begin
            if (FEC_valid_out && !fec_verified) begin
                if (FEC_data_out !== FEC_ENCODER_OUT[FEC_counter]) begin
                    FEC_block_error <= 1'b1;
                end

                if (FEC_counter == 8'd0) begin
                    if (FEC_block_error) begin
                        fec_pass_latched <= 1'b0;
                    end

                    if (FEC_packet_count == NUM_PACKETS - 1) begin
                        fec_verified <= 1'b1;
                    end else begin
                        FEC_packet_count <= FEC_packet_count + 1'b1;
                    end

                    FEC_counter <= 8'd191;
                    FEC_block_error <= 1'b0;
                end else begin
                    FEC_counter <= FEC_counter - 1'b1;
                end
            end
        end
    end

    //==========================================================================
    //
    //  INTERLEAVER OUTPUT VERIFICATION
    //
    //  Compares interleaver output against golden data.
    //  Operates at 100 MHz clock domain.
    //
    //==========================================================================
    always_ff @(posedge clk_100 or negedge reset_N) begin
        if (~reset_N) begin
            interleaver_counter         <= 8'd191;
            interleaver_block_error     <= 1'b0;
            interleaver_packet_count    <= 4'd0;
            interleaver_pass_latched    <= 1'b1;
            interleaver_verified        <= 1'b0;
        end else begin
            if (interleaver_valid_out && !interleaver_verified) begin
                if (interleaver_data_out !== INTER_OUTPUT[interleaver_counter]) begin
                    interleaver_block_error <= 1'b1;
                end

                if (interleaver_counter == 8'd0) begin
                    if (interleaver_block_error) begin
                        interleaver_pass_latched <= 1'b0;
                    end

                    if (interleaver_packet_count == NUM_PACKETS - 1) begin
                        interleaver_verified <= 1'b1;
                    end else begin
                        interleaver_packet_count <= interleaver_packet_count + 1'b1;
                    end

                    interleaver_counter <= 8'd191;
                    interleaver_block_error <= 1'b0;
                end else begin
                    interleaver_counter <= interleaver_counter - 1'b1;
                end
            end
        end
    end

    //==========================================================================
    //
    //  MODULATOR OUTPUT VERIFICATION
    //
    //  Compares modulator I/Q outputs against golden data.
    //  QPSK outputs one symbol per 2 input bits - captures every 2nd valid.
    //  Only compares sign bits (MSB) for simplified verification.
    //
    //==========================================================================
    always_ff @(posedge clk_100 or negedge reset_N) begin
        if (~reset_N) begin
            mod_counter             <= 7'd0;
            mod_block_error         <= 1'b0;
            mod_valid_count         <= 1'b0;
            mod_packet_count        <= 4'd0;
            modulator_pass_latched  <= 1'b1;
            modulator_verified      <= 1'b0;
        end else begin
            if (mod_valid_out && !modulator_verified) begin
                mod_valid_count <= ~mod_valid_count;

                // Capture every 2nd valid cycle (when symbol is complete)
                if (mod_valid_count == 1'b1) begin
                    // Compare sign bits with golden data
                    if ((mod_I_comp[15] !== MODULATOR_OUT[mod_counter][1]) ||
                        (mod_Q_comp[15] !== MODULATOR_OUT[mod_counter][0])) begin
                        mod_block_error <= 1'b1;
                    end

                    if (mod_counter == 7'd95) begin
                        if (mod_block_error) begin
                            modulator_pass_latched <= 1'b0;
                        end

                        if (mod_packet_count == NUM_PACKETS - 1) begin
                            modulator_verified <= 1'b1;
                        end else begin
                            mod_packet_count <= mod_packet_count + 1'b1;
                        end

                        mod_counter <= 7'd0;
                        mod_block_error <= 1'b0;
                    end else begin
                        mod_counter <= mod_counter + 1'b1;
                    end
                end
            end
        end
    end

    //==========================================================================
    //
    //  LED OUTPUT ASSIGNMENTS
    //
    //  Active-HIGH LEDs:
    //  - Pass/Fail LEDs: ON = All packets passed, OFF = Any packet failed
    //  - Verification LEDs: ON = Verification complete for that stage
    //
    //==========================================================================
    assign LEDR[0] = prbs_pass_latched;
    assign LEDR[1] = fec_pass_latched;
    assign LEDR[2] = interleaver_pass_latched;
    assign LEDR[3] = modulator_pass_latched;
    assign LEDR[4] = prbs_verified;
    assign LEDR[5] = fec_verified;
    assign LEDR[6] = interleaver_verified;
    assign LEDR[7] = modulator_verified;
    assign LEDR[8] = en;
    assign LEDR[9] = pll_locked;

endmodule