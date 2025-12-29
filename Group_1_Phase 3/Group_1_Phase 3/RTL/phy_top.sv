//==============================================================================
//
//  Module Name:    phy_top
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Top-level integration module for the WiMAX PHY Layer
//                  transmitter pipeline. This module instantiates and connects
//                  all processing stages in the correct order to implement the
//                  complete physical layer processing chain.
//
//                  Processing Pipeline:
//                  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
//                  │   PRBS      │───►│     FEC     │───►│ Interleaver │───►│    QPSK     │
//                  │ Randomizer  │    │   Encoder   │    │             │    │  Modulator  │
//                  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
//                      @50MHz            50/100MHz          @100MHz           @100MHz
//
//                  The module also includes a Phase-Locked Loop (PLL) to
//                  generate the required 50 MHz and 100 MHz clock domains
//                  from a 50 MHz reference clock input.
//
//  Standards:      IEEE 802.16-2007 (WiMAX)
//
//  Authors:        Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Supervisor:     Dr. Ahmed Abou Auf
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        3.0
//  Date:           2025-12-19
//
//==============================================================================

module phy_top
    import wimax_pkg::*;
(
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic        clk_ref,            // Reference clock input (50 MHz)
    input  logic        reset_N,            // Active-low asynchronous reset

    //--------------------------------------------------------------------------
    // PRBS Control Interface
    //--------------------------------------------------------------------------
    input  logic        load,               // Load initial seed into PRBS LFSR
    input  logic        en,                 // Enable PRBS processing

    //--------------------------------------------------------------------------
    // Data Input Interface (Serial Bit Stream)
    //--------------------------------------------------------------------------
    input  logic        valid_in,           // Input data valid indicator
    input  logic        data_in,            // Serial data input (1-bit)
    output logic        ready_out,          // Ready to accept new input data

    //--------------------------------------------------------------------------
    // Data Output Interface (I/Q Symbols)
    //--------------------------------------------------------------------------
    output logic        valid_out,          // Output data valid indicator
    output logic [15:0] I_comp,             // In-phase component (Q15 format)
    output logic [15:0] Q_comp,             // Quadrature component (Q15 format)
    input  logic        ready_in,           // Downstream module ready signal

    //--------------------------------------------------------------------------
    // PLL Status Interface
    //--------------------------------------------------------------------------
    output logic        clk_50,             // Generated 50 MHz clock output
    output logic        clk_100,            // Generated 100 MHz clock output
    output logic        locked,             // PLL lock status indicator

    //--------------------------------------------------------------------------
    // Debug/Monitoring Interface
    //--------------------------------------------------------------------------
    output logic        prbs_out,           // PRBS randomizer data output
    output logic        prbs_valid,         // PRBS randomizer valid output
    output logic        fec_out,            // FEC encoder data output
    output logic        fec_valid,          // FEC encoder valid output
    output logic        interleaver_out,    // Interleaver data output
    output logic        interleaver_valid   // Interleaver valid output
);

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // PRBS Randomizer to FEC Encoder Interface Signals
    //--------------------------------------------------------------------------
    logic               ready_in_fec;       // FEC ready signal to randomizer
    logic               valid_out_to_fec;   // Randomizer valid to FEC
    logic               data_out_to_fec;    // Randomizer data to FEC

    //--------------------------------------------------------------------------
    // FEC Encoder to Interleaver Interface Signals
    //--------------------------------------------------------------------------
    logic               valid_out_fec;      // FEC valid output
    logic               data_out_fec;       // FEC data output

    //--------------------------------------------------------------------------
    // Interleaver to Modulator Interface Signals
    //--------------------------------------------------------------------------
    logic               valid_out_interleaver;  // Interleaver valid output
    logic               ready_out_interleaver;  // Interleaver ready output
    logic               data_out_interleaver;   // Interleaver data output
    logic               ready_interleaver;      // Modulator ready to interleaver

    //==========================================================================
    //
    //  PLL INSTANCE
    //
    //  Purpose:        Generate 50 MHz and 100 MHz clocks from reference
    //  IP Core:        MY_PLL (Altera/Intel FPGA PLL IP)
    //  Reset:          Active-high (inverted from system active-low reset)
    //
    //==========================================================================
    MY_PLL PLL_inst (
        .refclk   (clk_ref),            // Reference clock input (50 MHz)
        .rst      (~reset_N),           // PLL reset (active-high)
        .outclk_0 (clk_50),             // 50 MHz output clock
        .outclk_1 (clk_100),            // 100 MHz output clock
        .locked   (locked)              // PLL lock indicator
    );

    //==========================================================================
    //
    //  PRBS RANDOMIZER INSTANCE
    //
    //  Purpose:        Randomize input data to achieve spectral whitening
    //  Standard:       IEEE 802.16-2007 Section 8.4.9.1
    //  Clock Domain:   50 MHz
    //  Polynomial:     1 + x^14 + x^15
    //
    //==========================================================================
    prbs_randomizer randomizer_U0 (
        .clk         (clk_50),              // 50 MHz clock
        .rst_n       (reset_N),             // Active-low reset
        .load        (load),                // Load LFSR seed
        .en          (en),                  // Enable operation
        .i_valid     (valid_in),            // Input valid from testbench
        .i_data      (data_in),             // Input data from testbench
        .i_ready     (ready_out),           // Ready output to testbench
        .o_valid     (valid_out_to_fec),    // Valid output to FEC
        .o_data      (data_out_to_fec),     // Data output to FEC
        .o_ready     (ready_in_fec)         // Ready input from FEC
    );

    //--------------------------------------------------------------------------
    // PRBS Debug Output Assignments
    //--------------------------------------------------------------------------
    assign prbs_out   = data_out_to_fec;
    assign prbs_valid = valid_out_to_fec;

    //==========================================================================
    //
    //  FEC ENCODER INSTANCE
    //
    //  Purpose:        Perform Forward Error Correction encoding
    //  Standard:       IEEE 802.16-2007 Section 8.4.9.2
    //  Type:           Tail-Biting Convolutional Encoder (Rate 1/2)
    //  Clock Domains:  50 MHz input, 100 MHz output
    //  Polynomials:    G1 = 171 octal, G2 = 133 octal
    //
    //==========================================================================
    fec_encoder fec_encoder_U1 (
        .clk_50mhz   (clk_50),               // 50 MHz input clock
        .clk_100mhz  (clk_100),              // 100 MHz output clock
        .rst_n       (reset_N),              // Active-low reset
        .i_valid     (valid_out_to_fec),     // Valid from randomizer
        .i_data      (data_out_to_fec),      // Data from randomizer
        .i_ready     (ready_in_fec),         // Ready to randomizer
        .o_valid     (valid_out_fec),        // Valid to interleaver
        .o_data      (data_out_fec),         // Data to interleaver
        .o_ready     (ready_out_interleaver) // Ready from interleaver
    );

    //--------------------------------------------------------------------------
    // FEC Debug Output Assignments
    //--------------------------------------------------------------------------
    assign fec_out   = data_out_fec;
    assign fec_valid = valid_out_fec;

    //==========================================================================
    //
    //  INTERLEAVER INSTANCE
    //
    //  Purpose:        Reorder bits to spread burst errors
    //  Standard:       IEEE 802.16-2007 Section 8.4.9.3
    //  Type:           Two-step block interleaver with Ping-Pong buffer
    //  Clock Domain:   100 MHz
    //  Block Size:     192 bits (for QPSK)
    //
    //==========================================================================
    interleaver_top interleaver_U2 (
        .clk         (clk_100),              // 100 MHz clock
        .reset_N     (reset_N),              // Active-low reset
        .valid_in    (valid_out_fec),        // Valid from FEC
        .ready_in    (ready_interleaver),    // Ready from modulator
        .data_in     (data_out_fec),         // Data from FEC
        .valid_out   (valid_out_interleaver),// Valid to modulator
        .ready_out   (ready_out_interleaver),// Ready to FEC
        .data_out    (data_out_interleaver)  // Data to modulator
    );

    //--------------------------------------------------------------------------
    // Interleaver Debug Output Assignments
    //--------------------------------------------------------------------------
    assign interleaver_out   = data_out_interleaver;
    assign interleaver_valid = valid_out_interleaver;

    //==========================================================================
    //
    //  QPSK MODULATOR INSTANCE
    //
    //  Purpose:        Map bit pairs to I/Q constellation symbols
    //  Standard:       IEEE 802.16-2007 Section 8.4.9.4.3
    //  Type:           QPSK with Gray mapping
    //  Clock Domain:   100 MHz
    //  Output Format:  16-bit Q15 fixed-point (±0.707)
    //
    //==========================================================================
    modulator_qpsk qpsk_MOD_U3 (
        .clk         (clk_100),              // 100 MHz clock
        .rst_n       (reset_N),              // Active-low reset
        .i_valid     (valid_out_interleaver),// Valid from interleaver
        .i_data      (data_out_interleaver), // Data from interleaver
        .i_ready     (ready_interleaver),    // Ready to interleaver
        .o_valid     (valid_out),            // Valid to output
        .I_comp      (I_comp),               // I component output
        .Q_comp      (Q_comp),               // Q component output
        .o_ready     (ready_in)              // Ready from output
    );

endmodule