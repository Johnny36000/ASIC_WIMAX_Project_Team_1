//==============================================================================
//
//  Module Name:    PPBufferControl
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Finite State Machine (FSM) controller for the Ping-Pong
//                  Buffer. This module manages the switching between dual
//                  memory banks to enable continuous streaming operation.
//
//                  State Machine Diagram:
//                  ┌──────────────────────────────────────────────────────────┐
//                  │                                                          │
//                  │                         ┌───────┐                        │
//                  │            Reset ──────►│ IDLE  │                        │
//                  │                         └───┬───┘                        │
//                  │                             │                            │
//                  │                             ▼                            │
//                  │                         ┌───────┐                        │
//                  │                         │ CLEAR │◄───────┐              │
//                  │                         └───┬───┘        │              │
//                  │                             │ clear_done │              │
//                  │                             │ && valid   │              │
//                  │                             ▼            │              │
//                  │                         ┌─────────┐      │              │
//                  │          bit=191 ┌─────►│ WRITE_A │──────┤              │
//                  │          valid   │      └────┬────┘      │ bit=191     │
//                  │                  │           │           │ valid       │
//                  │                  │ bit=191   │           │              │
//                  │                  │ valid     ▼           │              │
//                  │                  │      ┌─────────┐      │              │
//                  │                  └──────│ WRITE_B │◄─────┘              │
//                  │                         └─────────┘                      │
//                  │                                                          │
//                  └──────────────────────────────────────────────────────────┘
//
//                  Bank Control Logic:
//                  State     | Bank A        | Bank B
//                  ----------|---------------|---------------
//                  WRITE_A   | Write enabled | Read enabled
//                  WRITE_B   | Read enabled  | Write enabled
//
//  Block Size:     192 bits per bank
//  Clock Domain:   100 MHz
//
//  Authors:        Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Supervisor:     Dr. Ahmed Abou Auf
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        4.0
//  Date:           2025-12-19
//
//==============================================================================

module PPBufferControl (
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic clk,                   // System clock (100 MHz)
    input  logic resetN,                // Active-low asynchronous reset

    //--------------------------------------------------------------------------
    // Bank A Control Interface
    //--------------------------------------------------------------------------
    output logic wren_A,                // Write enable for Bank A
    output logic rden_A,                // Read enable for Bank A
    input  logic q_A,                   // Data output from Bank A

    //--------------------------------------------------------------------------
    // Bank B Control Interface
    //--------------------------------------------------------------------------
    output logic wren_B,                // Write enable for Bank B
    output logic rden_B,                // Read enable for Bank B
    input  logic q_B,                   // Data output from Bank B

    //--------------------------------------------------------------------------
    // Handshaking Interface
    //--------------------------------------------------------------------------
    input  logic valid_in,              // Input data valid
    input  logic ready_in,              // Downstream ready
    output logic ready_out,             // Ready for input
    output logic valid_out,             // Output data valid
    output logic q                      // Selected output data
);

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // Output Multiplexer Control
    //--------------------------------------------------------------------------
    logic       q_sel;                  // 0: select q_A, 1: select q_B

    //--------------------------------------------------------------------------
    // Bit Counter Signals (counts 0 to 191)
    //--------------------------------------------------------------------------
    logic       bit_counter_resetN;     // Counter reset (active-low)
    logic [7:0] bit_counter;            // Current bit count
    logic       count_en;               // Counter enable

    //--------------------------------------------------------------------------
    // Clear Phase Counter Signals
    //--------------------------------------------------------------------------
    logic       clear_counter_resetN;   // Clear counter reset (active-low)
    logic       clear_counter;          // Clear phase complete flag
    logic       clear_count_en;         // Clear counter enable

    //==========================================================================
    //
    //  FSM STATE DEFINITION
    //
    //==========================================================================
    typedef enum logic [1:0] {
        IDLE,                           // Initial state after reset
        CLEAR,                          // Initialization/clear phase
        WRITE_A,                        // Writing to Bank A, reading from B
        WRITE_B                         // Writing to Bank B, reading from A
    } BufferControlState_t;

    BufferControlState_t state, state_next;

    //==========================================================================
    //
    //  STATE REGISTER
    //
    //  Sequential logic for state transitions
    //
    //==========================================================================
    always_ff @(posedge clk or negedge resetN) begin
        if(resetN == 1'b0) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end

    //==========================================================================
    //
    //  NEXT STATE LOGIC
    //
    //  Combinational logic determining next state based on current state
    //  and input conditions
    //
    //==========================================================================
    always_comb begin
        case(state)
            //------------------------------------------------------------------
            // IDLE: Immediately transition to CLEAR on reset release
            //------------------------------------------------------------------
            IDLE: begin
                state_next = CLEAR;
            end

            //------------------------------------------------------------------
            // CLEAR: Wait for clear complete and valid input
            //------------------------------------------------------------------
            CLEAR: begin
                if((clear_counter && valid_in) == 1'b1)  begin
                    state_next = WRITE_A;
                end else begin
                    state_next = CLEAR;
                end
            end

            //------------------------------------------------------------------
            // WRITE_A: Switch to WRITE_B after 192 bits
            //------------------------------------------------------------------
            WRITE_A: begin
                if((bit_counter == 8'd191) && (valid_in && ready_in)) begin
                    state_next = WRITE_B;
                end else begin
                    state_next = WRITE_A;
                end
            end

            //------------------------------------------------------------------
            // WRITE_B: Switch to WRITE_A after 192 bits
            //------------------------------------------------------------------
            WRITE_B: begin
                if((bit_counter == 8'd191) && (valid_in && ready_in)) begin
                    state_next = WRITE_A;
                end else begin
                    state_next = WRITE_B;
                end
            end
        endcase
    end

    //==========================================================================
    //
    //  OUTPUT LOGIC
    //
    //  Combinational logic generating control signals based on current state
    //
    //==========================================================================
    always_comb begin
        case(state)
            //------------------------------------------------------------------
            // IDLE: All controls disabled
            //------------------------------------------------------------------
            IDLE: begin
                rden_A             = 1'b0;
                rden_B             = 1'b0;
                wren_A             = 1'b0;
                wren_B             = 1'b0;
                q_sel              = 1'b0;

                bit_counter_resetN = 1'b0;
                count_en           = 1'b0;
                clear_count_en     = 1'b0;
                clear_counter_resetN = 1'b0;

                ready_out          = 1'b0;
            end

            //------------------------------------------------------------------
            // CLEAR: Initialize both banks
            //------------------------------------------------------------------
            CLEAR: begin
                rden_A             = 1'b1;
                rden_B             = 1'b1;
                wren_A             = 1'b1;
                wren_B             = 1'b1;
                q_sel              = 1'b0;

                bit_counter_resetN = 1'b0;
                count_en           = 1'b0;
                clear_count_en     = 1'b1;
                clear_counter_resetN = 1'b1;

                ready_out          = (clear_counter == 1'b1);
            end

            //------------------------------------------------------------------
            // WRITE_A: Write to Bank A, Read from Bank B
            //------------------------------------------------------------------
            WRITE_A: begin
                rden_A             = 1'b0;
                rden_B             = 1'b1;
                wren_A             = 1'b1;
                wren_B             = 1'b0;
                q_sel              = 1'b1;      // Select Bank B output

                bit_counter_resetN = 1'b1;
                count_en           = 1'b1;
                clear_count_en     = 1'b0;
                clear_counter_resetN = 1'b0;

                ready_out          = 1'b1;
            end

            //------------------------------------------------------------------
            // WRITE_B: Write to Bank B, Read from Bank A
            //------------------------------------------------------------------
            WRITE_B: begin
                rden_A             = 1'b1;
                rden_B             = 1'b0;
                wren_A             = 1'b0;
                wren_B             = 1'b1;
                q_sel              = 1'b0;      // Select Bank A output

                bit_counter_resetN = 1'b1;
                count_en           = 1'b1;
                clear_count_en     = 1'b0;
                clear_counter_resetN = 1'b0;

                ready_out          = 1'b1;
            end
        endcase

        //----------------------------------------------------------------------
        // Output Data Multiplexer
        //----------------------------------------------------------------------
        if (q_sel == 1'b1) begin
            q = q_B;
        end else begin
            q = q_A;
        end
    end

    //==========================================================================
    //
    //  BIT COUNTER
    //
    //  Counts bits within a 192-bit block (0 to 191)
    //  Generates valid_out when block completes
    //
    //==========================================================================
    always_ff @(posedge clk or negedge bit_counter_resetN) begin
        if(bit_counter_resetN == 1'b0) begin
            bit_counter <= '0;
            valid_out <= 1'b0;
        end else if(count_en == 1'b1) begin
            if(bit_counter == 191) begin
                bit_counter <= '0;
                valid_out <= 1'b1;
            end else begin
                bit_counter <= bit_counter + 1'b1;
            end
        end
    end

    //==========================================================================
    //
    //  CLEAR PHASE COUNTER
    //
    //  Simple counter for initialization timing
    //  Sets clear_counter high after 2 cycles
    //
    //==========================================================================
    always_ff @(posedge clk or negedge clear_counter_resetN) begin
        if(clear_counter_resetN == 1'b0) begin
            clear_counter <= '0;
        end else if(clear_count_en == 1'b1) begin
            if(clear_counter == 1) clear_counter <= '1;
            else                   clear_counter <= clear_counter + 1'b1;
        end
    end

endmodule