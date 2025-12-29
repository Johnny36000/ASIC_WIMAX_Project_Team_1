//==============================================================================
//
//  Module Name:    fec_encoder
//  Project:        WiMAX IEEE 802.16-2007 PHY Layer Transmitter
//
//  Description:    Forward Error Correction (FEC) Encoder implementing a
//                  tail-biting convolutional code. This module encodes the
//                  randomized data to add redundancy for error detection
//                  and correction at the receiver.
//
//                  Encoder Architecture:
//                  ┌──────────────────────────────────────────────────────────┐
//                  │                    Shift Register                        │
//                  │   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐        │
//                  │   │SR5│◄──│SR4│◄──│SR3│◄──│SR2│◄──│SR1│◄──│SR0│◄── d   │
//                  │   └─┬─┘   └─┬─┘   └─┬─┘   └─┬─┘   └─┬─┘   └─┬─┘        │
//                  │     │       │       │       │       │       │          │
//                  │     │       │       │       │       │       │          │
//                  │   ┌─▼───────▼───────▼───────┴───────┴───────▼─┐        │
//                  │   │    G1 = 171 (octal): XOR(d,0,3,4,5)       │──► X   │
//                  │   └───────────────────────────────────────────┘        │
//                  │     │       │       │       │       │                  │
//                  │   ┌─▼───────┴───────▼───────▼───────▼─────────┐        │
//                  │   │    G2 = 133 (octal): XOR(d,0,1,3,4)       │──► Y   │
//                  │   └───────────────────────────────────────────┘        │
//                  └──────────────────────────────────────────────────────────┘
//
//                  Tail-Biting Operation:
//                  - The encoder initializes its shift register with the last
//                    6 bits of the input block (bits 90-95)
//                  - This ensures the final state equals the initial state
//                  - Eliminates the rate loss from tail bits in regular codes
//
//                  Dual-Clock Domain:
//                  - Input stage operates at 50 MHz (receives 96-bit blocks)
//                  - Output stage operates at 100 MHz (outputs 192-bit blocks)
//                  - Rate 1/2 coding doubles the data rate
//
//  Standard:       IEEE 802.16-2007 Section 8.4.9.2
//  Code Rate:      1/2 (96 input bits → 192 output bits)
//  Constraint:     K = 7 (6-bit shift register)
//  Polynomials:    G1 = 171 octal (X output)
//                  G2 = 133 octal (Y output)
//
//  Authors:        Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//  Supervisor:     Dr. Ahmed Abou Auf
//  Course:         ECNG410401 ASIC Design Using CAD
//
//  Version:        6.0
//  Date:           2025-12-19
//
//==============================================================================

module fec_encoder
    import wimax_pkg::*;
(
    //--------------------------------------------------------------------------
    // Clock and Reset Interface
    //--------------------------------------------------------------------------
    input  logic        clk_50mhz,      // 50 MHz clock (input stage)
    input  logic        clk_100mhz,     // 100 MHz clock (output stage)
    input  logic        rst_n,          // Active-low asynchronous reset

    //--------------------------------------------------------------------------
    // Data Input Interface (Upstream - from PRBS Randomizer)
    //--------------------------------------------------------------------------
    input  logic        i_valid,        // Input data valid indicator
    input  logic        i_data,         // Input data bit
    output logic        i_ready,        // Ready to accept input data

    //--------------------------------------------------------------------------
    // Data Output Interface (Downstream - to Interleaver)
    //--------------------------------------------------------------------------
    output logic        o_valid,        // Output data valid indicator
    output logic        o_data,         // Encoded output data bit
    input  logic        o_ready         // Downstream module ready signal
);

    //==========================================================================
    //
    //  LOCAL PARAMETERS
    //
    //==========================================================================
    localparam BUFFER_SIZE  = 96;       // Input block size in bits
    localparam BUFFER_SIZE2 = 192;      // Output block size (rate 1/2)

    //==========================================================================
    //
    //  INTERNAL SIGNAL DECLARATIONS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // Shift Registers for Tail-Biting Convolutional Encoding
    // Two registers for ping-pong operation between blocks
    //--------------------------------------------------------------------------
    logic [5:0] shift_register;         // Shift register for odd blocks
    logic [5:0] shift_register2;        // Shift register for even blocks

    //--------------------------------------------------------------------------
    // Counter Signals
    //--------------------------------------------------------------------------
    int         counter_input;          // Input bit counter (0 to 95)
    int         counter_output;         // Output bit counter (0 to 191)

    //--------------------------------------------------------------------------
    // Control Flags
    //--------------------------------------------------------------------------
    logic       tail_flag_done;         // Indicates tail bits captured
    logic       Ping_Pong_flag;         // Ping-pong buffer select
    logic       FEC_encoder_out_valid;  // Output valid indicator

    //--------------------------------------------------------------------------
    // Input FSM State Definition
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,                           // Waiting for valid input
        BUFFERING_INPUT,                // Collecting 96-bit input block
        PINGPONG                        // Ping-pong processing mode
    } input_state_type;
    input_state_type input_state;

    //--------------------------------------------------------------------------
    // Output FSM State Definition
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {
        OUTPUT_IDLE,                    // Waiting for encoding to start
        X,                              // Outputting X (G1) encoded bit
        Y                               // Outputting Y (G2) encoded bit
    } output_state_type;
    output_state_type output_state;

    //--------------------------------------------------------------------------
    // Dual-Port RAM Interface Signals
    //--------------------------------------------------------------------------
    logic [7:0] address_a;              // Write port address
    logic [7:0] address_b;              // Read port address
    logic [0:0] data_a;                 // Write data
    logic [0:0] data_b;                 // Read data (unused)
    logic       wren_a;                 // Write enable for port A
    logic       wren_b;                 // Write enable for port B
    logic [0:0] q_a;                    // Read data from port A
    logic [0:0] q_b;                    // Read data from port B

    //==========================================================================
    //
    //  DUAL-PORT RAM INSTANCE
    //
    //  Purpose:    Store input data for encoding with simultaneous read/write
    //  IP Core:    FEC_DPR (Altera/Intel FPGA RAM IP)
    //  Note:       Must use unregistered output version for correct timing
    //
    //==========================================================================
    FEC_DPR fec_encoder_DPR (
        .address_a(address_a),
        .address_b(address_b),
        .clock(clk_50mhz),
        .data_a(data_a),
        .data_b(data_b),
        .wren_a(wren_a),
        .wren_b(wren_b),
        .q_a(q_a),
        .q_b(q_b)
    );

    //==========================================================================
    //
    //  RAM SIGNAL ASSIGNMENTS
    //
    //==========================================================================

    //--------------------------------------------------------------------------
    // Write Address: Ping-pong between address ranges 0-95 and 96-191
    //--------------------------------------------------------------------------
    assign address_a = Ping_Pong_flag ? (counter_input + 8'd96) : counter_input;

    //--------------------------------------------------------------------------
    // Read Address: Sequential read from output counter
    //--------------------------------------------------------------------------
    assign address_b = counter_output[7:0];

    //--------------------------------------------------------------------------
    // Write Control Signals
    //--------------------------------------------------------------------------
    assign wren_a    = i_valid;         // Write when input is valid
    assign data_a[0] = i_data;          // Write input data
    assign wren_b    = 1'b0;            // Port B is read-only

    //--------------------------------------------------------------------------
    // Output Valid Signal Assignment
    //--------------------------------------------------------------------------
    assign o_valid = FEC_encoder_out_valid;

    //==========================================================================
    //
    //  READY SIGNAL LOGIC
    //
    //  The encoder is ready to accept input when:
    //  - In BUFFERING_INPUT state and buffer not full
    //  - In PINGPONG state and still accepting new block
    //
    //==========================================================================
    assign i_ready = ((input_state == BUFFERING_INPUT && counter_input < BUFFER_SIZE) ||
                      (input_state == PINGPONG && counter_input < BUFFER_SIZE));

    //==========================================================================
    //
    //  INPUT FSM (50 MHz CLOCK DOMAIN)
    //
    //  State Machine Operation:
    //  IDLE            → Wait for valid input, reset counters
    //  BUFFERING_INPUT → Collect 96-bit block, capture tail bits (90-95)
    //  PINGPONG        → Process current block while buffering next
    //
    //==========================================================================
    always_ff @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            //------------------------------------------------------------------
            // Asynchronous Reset
            //------------------------------------------------------------------
            counter_input    <= 0;
            shift_register   <= 6'b0;
            shift_register2  <= 6'b0;
            counter_output   <= 0;
            tail_flag_done   <= 1'b0;
            Ping_Pong_flag   <= 1'b0;
            input_state      <= IDLE;
        end
        else if (!o_ready) begin
            //------------------------------------------------------------------
            // Downstream Not Ready - Return to IDLE
            //------------------------------------------------------------------
            input_state <= IDLE;
        end
        else begin
            case (input_state)
                //--------------------------------------------------------------
                // IDLE State: Wait for valid input
                //--------------------------------------------------------------
                IDLE: begin
                    if (!i_valid) begin
                        counter_input    <= 0;
                        counter_output   <= 0;
                        tail_flag_done   <= 1'b0;
                        shift_register   <= 6'b0;
                        shift_register2  <= 6'b0;
                        Ping_Pong_flag   <= 1'b0;
                        input_state      <= IDLE;
                    end
                    else begin
                        counter_input <= counter_input + 1;
                        input_state   <= BUFFERING_INPUT;
                    end
                end

                //--------------------------------------------------------------
                // BUFFERING_INPUT State: Collect 96-bit block
                //--------------------------------------------------------------
                BUFFERING_INPUT: begin
                    // Capture tail bits (last 6 bits of block)
                    if (counter_input >= 90 && counter_input <= 95) begin
                        shift_register[counter_input - 90] <= i_data;
                    end

                    if (counter_input < BUFFER_SIZE - 1) begin
                        counter_input <= counter_input + 1;
                    end
                    else begin
                        // Block complete, transition to PINGPONG
                        counter_input    <= 0;
                        input_state      <= PINGPONG;
                        tail_flag_done   <= 1'b1;
                        counter_output   <= counter_output + 1;
                        Ping_Pong_flag   <= 1'b1;
                    end
                end

                //--------------------------------------------------------------
                // PINGPONG State: Process and buffer simultaneously
                //--------------------------------------------------------------
                PINGPONG: begin
                    // Output block complete
                    if (counter_output == BUFFER_SIZE2) begin
                        shift_register   <= 6'b0;
                        shift_register2  <= 6'b0;
                        counter_output   <= 0;
                        counter_input    <= 0;
                        Ping_Pong_flag   <= 1'b0;
                        input_state      <= IDLE;
                    end

                    // Capture tail bits for next block
                    if (counter_input >= 90 && counter_input <= 95) begin
                        if (!Ping_Pong_flag) begin
                            shift_register[counter_input - 90] <= i_data;
                        end else begin
                            shift_register2[counter_input - 90] <= i_data;
                        end
                    end

                    // Shift register updates based on Ping_Pong_flag
                    if (counter_output < BUFFER_SIZE && Ping_Pong_flag) begin
                        shift_register  <= {q_b[0], shift_register[5:1]};
                        counter_output  <= counter_output + 1;
                        if (counter_input < BUFFER_SIZE - 1) begin
                            counter_input <= counter_input + 1;
                        end
                    end
                    else if (!Ping_Pong_flag && counter_output >= BUFFER_SIZE && counter_output < BUFFER_SIZE2) begin
                        shift_register2 <= {q_b[0], shift_register2[5:1]};
                        counter_output  <= counter_output + 1;
                        if (counter_input < BUFFER_SIZE - 1) begin
                            counter_input <= counter_input + 1;
                        end
                    end
                    else if (counter_output == BUFFER_SIZE2) begin
                        counter_output <= 0;
                        counter_input  <= counter_input + 1;
                    end

                    if ((counter_output == BUFFER_SIZE || counter_output == BUFFER_SIZE2) && !i_valid) begin
                        counter_output <= 0;
                        input_state    <= PINGPONG;
                    end

                    if (counter_input == BUFFER_SIZE - 1) begin
                        Ping_Pong_flag <= ~Ping_Pong_flag;
                        counter_input  <= 0;

                        if (counter_output < BUFFER_SIZE2 - 1) begin
                            counter_output <= counter_output + 1;
                        end else begin
                            counter_output <= 0;
                        end
                    end

                    if (counter_output == BUFFER_SIZE2 - 1) begin
                        counter_output <= 0;
                    end
                end

                default: input_state <= IDLE;
            endcase
        end
    end

    //==========================================================================
    //
    //  COMBINATIONAL OUTPUT LOGIC (ENCODING)
    //
    //  Generator Polynomials:
    //  G1 = 171 octal = 1111001 binary → XOR(d, SR0, SR3, SR4, SR5) → X output
    //  G2 = 133 octal = 1011011 binary → XOR(d, SR0, SR1, SR3, SR4) → Y output
    //
    //==========================================================================
    always_comb begin
        if (Ping_Pong_flag) begin
            // Use shift_register for current block
            if ((output_state == OUTPUT_IDLE && tail_flag_done) || output_state == X) begin
                o_data = q_b[0] ^ shift_register[0] ^ shift_register[3] ^ shift_register[4] ^ shift_register[5];
            end
            else if (output_state == Y) begin
                o_data = q_b[0] ^ shift_register[0] ^ shift_register[1] ^ shift_register[3] ^ shift_register[4];
            end
            else begin
                o_data = 1'b0;
            end
        end
        else begin
            // Use shift_register2 for current block
            if ((output_state == OUTPUT_IDLE && tail_flag_done) || output_state == X) begin
                o_data = q_b[0] ^ shift_register2[0] ^ shift_register2[3] ^ shift_register2[4] ^ shift_register2[5];
            end
            else if (output_state == Y) begin
                o_data = q_b[0] ^ shift_register2[0] ^ shift_register2[1] ^ shift_register2[3] ^ shift_register2[4];
            end
            else begin
                o_data = 1'b0;
            end
        end
    end

    //==========================================================================
    //
    //  OUTPUT VALID GENERATION
    //
    //==========================================================================
    assign FEC_encoder_out_valid = (input_state == PINGPONG) ? 1'b1 : 1'b0;

    //==========================================================================
    //
    //  OUTPUT FSM (100 MHz CLOCK DOMAIN)
    //
    //  Alternates between X and Y outputs at double the input rate
    //
    //==========================================================================
    always_ff @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            output_state <= OUTPUT_IDLE;
        end
        else begin
            if (tail_flag_done) begin
                case (output_state)
                    OUTPUT_IDLE: begin
                        if (counter_output == 1) begin
                            output_state <= Y;
                        end else begin
                            output_state <= OUTPUT_IDLE;
                        end
                    end

                    X: begin
                        if (counter_output <= BUFFER_SIZE2) begin
                            output_state <= Y;
                        end else begin
                            output_state <= X;
                        end
                    end

                    Y: begin
                        if (!FEC_encoder_out_valid && (counter_output == BUFFER_SIZE + 1 || counter_output == BUFFER_SIZE2 + 1)) begin
                            output_state <= OUTPUT_IDLE;
                        end else begin
                            output_state <= Y;
                        end

                        if (counter_output < BUFFER_SIZE2 && FEC_encoder_out_valid) begin
                            output_state <= X;
                        end else begin
                            output_state <= OUTPUT_IDLE;
                        end
                    end

                    default: output_state <= OUTPUT_IDLE;
                endcase
            end
        end
    end

endmodule