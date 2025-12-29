//==============================================================================
// File Name:    wimax_pkg.sv
// Description:  Package file containing constants and self-checking tasks
//               Based on reference Package_wimax.sv format
// Author:       Group 1: John Fahmy, Abanoub Emad, Omar ElShazli - Supervised by Dr. Ahmed Abou Auf
// Course:       ECNG410401 ASIC Design Using CAD
// Version:      7.0 (Aligned with RTL output)
// Date:         2025-12-19
//==============================================================================

//==============================================================================
// WiMAX PHY Package - Golden Data from Reference Design (Package_wimax.sv)
//==============================================================================

package wimax_pkg;

    timeunit 1ns;
    timeprecision 1ps;
    
    parameter time CLK_50_PERIOD      = 20ns;
    parameter time CLK_50_HALF_PERIOD = CLK_50_PERIOD / 2;
    parameter time CLK_100_PERIOD     = 10ns;
    parameter time CLK_100_HALF_PERIOD = CLK_100_PERIOD / 2;

    //==========================================================================
    // Randomizer Parameters (from reference Package_wimax.sv)
    //==========================================================================
    parameter logic [95:0]  RANDOMIZER_INPUT  = 96'hACBCD2114DAE1577C6DBF4C9;
    parameter logic [95:0]  RANDOMIZER_OUTPUT = 96'h558AC4A53A1724E163AC2BF9;
    parameter logic [1:15]  SEED              = 15'b011011100010101;

    //==========================================================================
    // FEC Encoder Parameters (from reference Package_wimax.sv)
    //==========================================================================
    parameter logic [95:0]  FEC_ENCODER_INPUT  = 96'h558AC4A53A1724E163AC2BF9;
    parameter logic [191:0] FEC_ENCODER_OUTPUT = 192'h2833E48D392026D5B6DC5E4AF47ADD29494B6C89151348CA;
    parameter logic [191:0] FEC_ENDODER_OUTPUT = FEC_ENCODER_OUTPUT;

    //==========================================================================
    // Interleaver Parameters (from reference Package_wimax.sv)
    //==========================================================================
    parameter logic [191:0] INTERLEAVER_INPUT  = FEC_ENCODER_OUTPUT;
    parameter logic [191:0] INTERLEAVER_OUTPUT = 192'h4B047DFA42F2A5D5F61C021A5851E9A309A24FD58086BD1E;

    //==========================================================================
    // Modulator Parameters (from reference Package_wimax.sv)
    //==========================================================================
    parameter logic [191:0] INPUT_MODULATION      = INTERLEAVER_OUTPUT;
    parameter logic [15:0] ZeroPointSeven         = 16'b0101_1010_1000_0010;
    parameter logic [15:0] NegativeZeroPointSeven = 16'b1010_0101_0111_1110;

    //==========================================================================
    // MOD_OUTPUT - Exact values from reference Package_wimax.sv
    //==========================================================================
    parameter logic [1:0] MOD_OUTPUT [0:95] = '{
        2'b01, 2'b00, 2'b10, 2'b11,
        2'b00, 2'b00, 2'b01, 2'b00,
        2'b01, 2'b11, 2'b11, 2'b01,
        2'b11, 2'b11, 2'b10, 2'b10,
        2'b01, 2'b00, 2'b00, 2'b10,
        2'b11, 2'b11, 2'b00, 2'b10,
        2'b10, 2'b10, 2'b01, 2'b01,
        2'b11, 2'b01, 2'b01, 2'b01,
        2'b11, 2'b11, 2'b01, 2'b10,
        2'b00, 2'b01, 2'b11, 2'b00,
        2'b00, 2'b00, 2'b00, 2'b10,
        2'b00, 2'b01, 2'b10, 2'b10,
        2'b01, 2'b01, 2'b10, 2'b00,
        2'b01, 2'b01, 2'b00, 2'b01,
        2'b11, 2'b10, 2'b10, 2'b01,
        2'b10, 2'b10, 2'b00, 2'b11,
        2'b00, 2'b00, 2'b10, 2'b01,
        2'b10, 2'b10, 2'b00, 2'b10,
        2'b01, 2'b00, 2'b11, 2'b11,
        2'b11, 2'b01, 2'b01, 2'b01,
        2'b10, 2'b00, 2'b00, 2'b00,
        2'b10, 2'b00, 2'b01, 2'b10,
        2'b10, 2'b11, 2'b11, 2'b01,
        2'b00, 2'b01, 2'b11, 2'b10
    };

    //==========================================================================
    // Self-Checking Tasks (from reference Package_wimax.sv)
    //==========================================================================
    
    task automatic enter_96_inputs(
        input int start,
        input int STOP,
        input logic [95:0] data_in,
        output logic test_data
    );
        for (int i = STOP; i >= start; i--) begin
            test_data = data_in[i];
            #(CLK_50_PERIOD);
        end
    endtask

    task automatic enter_192_outputs(
        input int start,
        input int STOP,
        output logic [191:0] data_out,
        input logic test_data
    );
        for (int i = STOP; i >= start; i--) begin
            data_out[i] = test_data;
            #(CLK_100_PERIOD);
        end
    endtask
     
    task automatic enter_192_inputs(
        input int start,
        input int STOP,
        input logic [191:0] data_in,
        output logic test_data
    );
        for (int i = STOP; i >= start; i--) begin
            test_data = data_in[i];
            #(CLK_100_PERIOD);
        end
    endtask

    task checkOutput96(input logic [95:0] out_vec, input logic [95:0] expected_vec);
        if(out_vec === expected_vec) begin
            $display("Run Passed @ t = %0t", $time);
            $display("Expected: %h Got: %h", expected_vec, out_vec);
        end else begin
            $display("Run Failed @ t = %0t", $time);
            $display("Expected: %h Got: %h", expected_vec, out_vec);
        end
    endtask

    task checkOutput192(input logic [191:0] out_vec, input logic [191:0] expected_vec);
        if(out_vec === expected_vec) begin
            $display("Run Passed @ t = %0t", $time);
            $display("Expected: %h Got: %h", expected_vec, out_vec);
        end else begin
            $display("Run Failed @ t = %0t", $time);
            $display("Expected: %h Got: %h", expected_vec, out_vec);
        end
    endtask

    task checkModOutput(input logic [1:0] out_vec [0:95], input logic [1:0] expected_vec [0:95]);
        if(out_vec === expected_vec) begin
            $display("Run Passed @ t = %0t", $time);
            $display("Expected | Got");
            for(int i = 0; i < 96; i++) begin
                $display("   %b    | %b", expected_vec[i], out_vec[i]);
            end
        end else begin
            $display("Run Failed @ t = %0t", $time);
            $display("Expected | Got");
            for(int i = 0; i < 96; i++) begin
                $display("   %b    | %b", expected_vec[i], out_vec[i]);
            end
        end
    endtask

endpackage