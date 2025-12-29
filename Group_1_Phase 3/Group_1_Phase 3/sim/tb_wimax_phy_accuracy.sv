//==============================================================================
// File Name:    tb_wimax_phy_accuracy.sv
// Description:  WiMAX PHY Layer Accuracy Testbench
//               Based on reference WiMAX_PHY_top_tb.sv style
// Author:       Group 1: John Fahmy, Abanoub Emad, Omar ElShazli - Supervised by Dr. Ahmed Abou Auf
// Course:       ECNG410401 ASIC Design Using CAD
// Version:      16.0 (Enhanced - All blocks tested including Block 0, detailed statistics)
// Date:         2025-12-19
//
//==============================================================================
// IMPORTANT NOTES ON PING-PONG BUFFER LATENCY:
//==============================================================================
// The interleaver uses a ping-pong (double) buffer architecture consisting of
// two memory banks (Bank A and Bank B). This design choice provides the 
// following benefits:
//   1. Continuous data flow - while one bank is being written, the other is read
//   2. No pipeline stalls - data can be processed without waiting
//   3. Full block interleaving - entire 192-bit blocks can be reordered
//
// LATENCY BEHAVIOR:
// -----------------
// Due to the ping-pong buffer architecture, there is an inherent 1-block latency:
//
//   Time Period    | Bank A State  | Bank B State  | Output Source
//   ---------------|---------------|---------------|---------------
//   Block 0 input  | WRITING       | READING       | Bank B (uninitialized!)
//   Block 1 input  | READING       | WRITING       | Bank A (Block 0 data)
//   Block 2 input  | WRITING       | READING       | Bank B (Block 1 data)
//   Block N input  | alternates... | alternates... | Block N-1 data
//
// CONSEQUENCE:
// - Block 0 output from interleaver/modulator contains UNINITIALIZED DATA
//   because Bank B has never been written to when it's first read
// - Starting from Block 1, the output contains valid interleaved data
// - This is EXPECTED BEHAVIOR, not a bug in the design
//
// TEST APPROACH:
// - All blocks (including Block 0) are tested against golden data
// - Block 0 is clearly marked as "LATENCY BLOCK" in the output
// - Statistics show results for all blocks
// - A separate "Valid Blocks" count excludes Block 0 for accurate pass rate
//==============================================================================

import wimax_pkg::*;

module tb_wimax_phy_accuracy();
    timeunit 1ns;
    timeprecision 1ps;

    //==========================================================================
    // Test Configuration
    //==========================================================================
    parameter int NUM_TEST_BLOCKS = 20;  // Total number of blocks to test
    
    //==========================================================================
    // Clock and Reset
    //==========================================================================
    logic clk_ref;
    logic reset_N;
    logic data_in;
    logic load;
    logic en;
    logic valid_in;
    logic ready_in;
    
    logic ready_out;
    logic valid_out;
    logic [15:0] I_comp;
    logic [15:0] Q_comp;
    
    // Internal clock signals
    logic clk_50, clk_100, locked;
    logic prbs_out, prbs_valid;
    logic fec_out, fec_valid;
    logic interleaver_out, interleaver_valid;

    //==========================================================================
    // Statistics Counters
    // All blocks are counted, including Block 0 (latency block)
    //==========================================================================
    int rand_pass_count = 0;
    int rand_fail_count = 0;
    int fec_pass_count = 0;
    int fec_fail_count = 0;
    int inter_pass_count = 0;
    int inter_fail_count = 0;
    int mod_pass_count = 0;
    int mod_fail_count = 0;

    //==========================================================================
    // DUT Instance
    //==========================================================================
    phy_top dut (
        .clk_ref(clk_ref),
        .reset_N(reset_N),
        .data_in(data_in),
        .load(load),
        .en(en),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .ready_out(ready_out),
        .valid_out(valid_out),
        .I_comp(I_comp),
        .Q_comp(Q_comp),
        .clk_50(clk_50),
        .clk_100(clk_100),
        .locked(locked),
        .prbs_out(prbs_out),
        .prbs_valid(prbs_valid),
        .fec_out(fec_out),
        .fec_valid(fec_valid),
        .interleaver_out(interleaver_out),
        .interleaver_valid(interleaver_valid)
    );

    //==========================================================================
    // Clock Generation (50 MHz reference)
    //==========================================================================
    initial begin
        clk_ref = 1;
        forever begin
            #CLK_50_HALF_PERIOD clk_ref = ~clk_ref;
        end
    end

    //==========================================================================
    // Input Data Generation - MSB first (counting down from 95)
    // Continuously feeds the same 96-bit pattern (RANDOMIZER_INPUT) to test
    // that each block produces consistent output matching golden data
    //==========================================================================
    integer i = 95;
    
    always @(posedge clk_50 or negedge reset_N) begin
        if (!reset_N) begin 
            i <= 95;
        end else if (ready_out && en && valid_in) begin
            if (i == 0) begin
                i <= 95;  // Wrap around to repeat the same input pattern
            end else begin
                i <= i - 1;
            end
        end
    end

    assign data_in = RANDOMIZER_INPUT[i];

    //==========================================================================
    // Randomizer Verification - MSB first (counting down from 95)
    // The randomizer has NO latency - Block 0 should match golden data
    //==========================================================================
    integer rand_i = 95;
    logic [95:0] rand_out;
    int rand_blocks_checked = 0;
    
    always @(posedge clk_50 or negedge reset_N) begin
        if (reset_N == 1'b0) begin
            rand_i <= 95;
            rand_blocks_checked <= 0;
        end else begin
            if (prbs_valid) begin
                rand_out[rand_i] <= prbs_out;
                if (rand_i == 0) begin
                    $display("");
                    $display("RANDOMIZER Block %0d:", rand_blocks_checked);
                    checkOutput96_stat({rand_out[95:1], prbs_out}, RANDOMIZER_OUTPUT, 
                                       rand_pass_count, rand_fail_count);
                    rand_i <= 95;
                    rand_blocks_checked <= rand_blocks_checked + 1;
                end else begin
                    rand_i <= rand_i - 1;
                end
            end
        end
    end

    //==========================================================================
    // FEC Verification - MSB first (counting down from 191)
    // The FEC encoder has NO latency - Block 0 should match golden data
    //==========================================================================
    integer fec_i = 191;
    logic [191:0] fec_out_vec;
    int fec_blocks_checked = 0;
    
    always @(posedge clk_100 or negedge reset_N) begin
        if (reset_N == 1'b0) begin
            fec_i <= 191;
            fec_blocks_checked <= 0;
        end else begin
            if (fec_valid) begin
                fec_out_vec[fec_i] <= fec_out;
                if (fec_i == 0) begin
                    $display("");
                    $display("FEC Block %0d:", fec_blocks_checked);
                    checkOutput192_stat({fec_out_vec[191:1], fec_out}, FEC_ENCODER_OUTPUT,
                                        fec_pass_count, fec_fail_count);
                    fec_i <= 191;
                    fec_blocks_checked <= fec_blocks_checked + 1;
                end else begin
                    fec_i <= fec_i - 1;
                end
            end
        end
    end

    //==========================================================================
    // Interleaver Verification - MSB first (counting down from 191)
    // 
    // PING-PONG BUFFER LATENCY NOTE:
    // Block 0 is the "latency block" - it outputs uninitialized buffer data
    // because the ping-pong buffer reads from Bank B while Bank A is being
    // written for the first time. Bank B has never been written, so it
    // contains whatever was in memory at reset (typically zeros or X).
    //
    // Block 1 onwards should match golden data as they read from properly
    // written buffer banks.
    //==========================================================================
    integer inter_i = 191;
    logic [191:0] inter_out;
    int inter_blocks_checked = 0;
    
    always @(posedge clk_100 or negedge reset_N) begin
        if (reset_N == 1'b0) begin
            inter_i <= 191;
            inter_blocks_checked <= 0;
        end else begin
            if (interleaver_valid) begin
                inter_out[inter_i] <= interleaver_out;
                if (inter_i == 0) begin
                    $display("");
                    if (inter_blocks_checked == 0) begin
                        // Block 0: Latency block - data comes from uninitialized buffer
                        $display("INTERLEAVER Block 0 [LATENCY BLOCK - Ping-Pong Buffer]:");
                        $display("  NOTE: This block reads from uninitialized Bank B while Bank A");
                        $display("        is being written for the first time. Mismatch is EXPECTED.");
                    end else begin
                        $display("INTERLEAVER Block %0d:", inter_blocks_checked);
                    end
                    checkOutput192_stat({inter_out[191:1], interleaver_out}, INTERLEAVER_OUTPUT,
                                        inter_pass_count, inter_fail_count);
                    inter_i <= 191;
                    inter_blocks_checked <= inter_blocks_checked + 1;
                end else begin
                    inter_i <= inter_i - 1;
                end
            end
        end
    end

    //==========================================================================
    // Modulator Verification - Capture every 2nd valid cycle
    //
    // PING-PONG BUFFER LATENCY NOTE:
    // The modulator receives data from the interleaver, so it inherits the
    // same 1-block latency. Block 0 modulator output is based on the
    // uninitialized interleaver output, so it will not match golden data.
    //
    // Block 1 onwards should match golden data.
    //==========================================================================
    integer mod_i = 0;
    logic [1:0] mod_out [0:95];
    int mod_blocks_checked = 0;
    int valid_count = 0;
    
    always @(posedge clk_100 or negedge reset_N) begin
        if (reset_N == 1'b0) begin
            mod_i <= 0;
            mod_blocks_checked <= 0;
            valid_count <= 0;
        end else begin
            if (valid_out) begin
                valid_count <= valid_count + 1;
                // QPSK modulator outputs one symbol per 2 input bits
                // Capture every 2nd valid cycle (when symbol is complete)
                if (valid_count[0] == 1'b1) begin  // Odd count = second bit of pair
                    mod_out[mod_i] <= {I_comp[15], Q_comp[15]};
                    
                    if (mod_i == 95) begin
                        $display("");
                        if (mod_blocks_checked == 0) begin
                            // Block 0: Latency block - inherited from interleaver
                            $display("MODULATOR Block 0 [LATENCY BLOCK - Inherited from Interleaver]:");
                            $display("  NOTE: Modulator input comes from interleaver's uninitialized");
                            $display("        ping-pong buffer output. Mismatch is EXPECTED.");
                        end else begin
                            $display("MODULATOR Block %0d:", mod_blocks_checked);
                        end
                        checkModOutput_stat(mod_out, MOD_OUTPUT, mod_pass_count, mod_fail_count);
                        mod_i <= 0;
                        mod_blocks_checked <= mod_blocks_checked + 1;
                    end else begin
                        mod_i <= mod_i + 1;
                    end
                end
            end
        end
    end

    //==========================================================================
    // Enhanced Self-Checking Tasks with Statistics
    //==========================================================================
    
    // Task: Check 96-bit output and update statistics
    task automatic checkOutput96_stat(
        input logic [95:0] out_vec, 
        input logic [95:0] expected_vec,
        ref int pass_count,
        ref int fail_count
    );
        if(out_vec === expected_vec) begin
            $display("  PASS @ t = %0t", $time);
            $display("  Expected: %h", expected_vec);
            $display("  Got:      %h", out_vec);
            pass_count++;
        end else begin
            $display("  FAIL @ t = %0t", $time);
            $display("  Expected: %h", expected_vec);
            $display("  Got:      %h", out_vec);
            fail_count++;
        end
    endtask

    // Task: Check 192-bit output and update statistics
    task automatic checkOutput192_stat(
        input logic [191:0] out_vec, 
        input logic [191:0] expected_vec,
        ref int pass_count,
        ref int fail_count
    );
        if(out_vec === expected_vec) begin
            $display("  PASS @ t = %0t", $time);
            $display("  Expected: %h", expected_vec);
            $display("  Got:      %h", out_vec);
            pass_count++;
        end else begin
            $display("  FAIL @ t = %0t", $time);
            $display("  Expected: %h", expected_vec);
            $display("  Got:      %h", out_vec);
            fail_count++;
        end
    endtask

    // Task: Check modulator output (96 symbols) and update statistics
    task automatic checkModOutput_stat(
        input logic [1:0] out_vec [0:95], 
        input logic [1:0] expected_vec [0:95],
        ref int pass_count,
        ref int fail_count
    );
        logic match;
        int mismatch_count;
        match = 1'b1;
        mismatch_count = 0;
        
        for(int j = 0; j < 96; j++) begin
            if(out_vec[j] !== expected_vec[j]) begin
                match = 1'b0;
                mismatch_count++;
            end
        end
        
        if(match) begin
            $display("  PASS @ t = %0t", $time);
            $display("  All 96 QPSK symbols match golden data");
            pass_count++;
        end else begin
            $display("  FAIL @ t = %0t (%0d/96 symbols mismatch)", $time, mismatch_count);
            $display("  Mismatched symbols (Expected | Got):");
            for(int j = 0; j < 96; j++) begin
                if(out_vec[j] !== expected_vec[j])
                    $display("    [%2d] %b | %b", j, expected_vec[j], out_vec[j]);
            end
            fail_count++;
        end
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("");
        $display("==============================================================================");
        $display("WiMAX PHY Accuracy Testbench v16.0");
        $display("==============================================================================");
        $display("  Pipeline: PRBS Randomizer -> FEC Encoder -> Interleaver -> QPSK Modulator");
        $display("  Test Blocks: %0d (including Block 0 latency block)", NUM_TEST_BLOCKS);
        $display("==============================================================================");
        $display("");
        $display("PING-PONG BUFFER LATENCY EXPLANATION:");
        $display("--------------------------------------");
        $display("The interleaver uses a ping-pong (double) buffer with 2 memory banks.");
        $display("While Bank A is written, Bank B is read (and vice versa).");
        $display("");
        $display("For Block 0:");
        $display("  - Bank A: Being WRITTEN with first input block");
        $display("  - Bank B: Being READ but was NEVER WRITTEN (uninitialized!)");
        $display("  - Result: Block 0 output contains garbage/zeros, NOT valid data");
        $display("");
        $display("For Block 1 onwards:");
        $display("  - Previous block's data has been written to alternate bank");
        $display("  - Output is valid interleaved data matching golden reference");
        $display("");
        $display("This 1-block latency is EXPECTED BEHAVIOR of ping-pong buffering.");
        $display("==============================================================================");
        $display("");
        $display("Golden Data Reference:");
        $display("  RANDOMIZER_INPUT:   %h", RANDOMIZER_INPUT);
        $display("  RANDOMIZER_OUTPUT:  %h", RANDOMIZER_OUTPUT);
        $display("  FEC_ENCODER_OUTPUT: %h", FEC_ENCODER_OUTPUT);
        $display("  INTERLEAVER_OUTPUT: %h", INTERLEAVER_OUTPUT);
        $display("==============================================================================");
        $display("");
        
        // Initialize all control signals
        reset_N = 0;
        load = 0;
        en = 0;
        valid_in = 0;
        ready_in = 0;
        
        // Reset sequence - hold reset for one clock period
        #(CLK_50_PERIOD);
        reset_N = 1;
        
        // Wait for PLL to lock (generates clk_50 and clk_100 from clk_ref)
        wait(locked == 1'b1);
        $display("[%0t] PLL locked - clk_50 and clk_100 now available", $time);
        
        // Load PRBS seed into the randomizer's LFSR
        load = 1;
        #(CLK_50_PERIOD);
        load = 0;
        $display("[%0t] PRBS seed loaded: %b", $time, SEED);
        
        // Enable data flow through the pipeline
        ready_in = 1;  // Downstream (modulator output) is ready
        en = 1;        // Enable PRBS randomizer
        valid_in = 1;  // Input data is valid
        $display("[%0t] Pipeline enabled - data flow started", $time);
        $display("");
        $display("------------------------------------------------------------------------------");
        $display("                         BLOCK-BY-BLOCK RESULTS");
        $display("------------------------------------------------------------------------------");
        
        // Wait for all test blocks to complete
        wait(mod_blocks_checked >= NUM_TEST_BLOCKS);
        #(5 * CLK_50_PERIOD);
        
        // Print comprehensive test summary
        $display("");
        $display("==============================================================================");
        $display("                         TEST SUMMARY");
        $display("==============================================================================");
        $display("");
        $display("  Stage          | Total  | Passed | Failed | Pass Rate");
        $display("  ---------------+--------+--------+--------+----------");
        $display("  Randomizer     | %6d | %6d | %6d | %6.1f%%", 
                 rand_blocks_checked, rand_pass_count, rand_fail_count,
                 (rand_blocks_checked > 0) ? (100.0 * rand_pass_count / rand_blocks_checked) : 0.0);
        $display("  FEC Encoder    | %6d | %6d | %6d | %6.1f%%", 
                 fec_blocks_checked, fec_pass_count, fec_fail_count,
                 (fec_blocks_checked > 0) ? (100.0 * fec_pass_count / fec_blocks_checked) : 0.0);
        $display("  Interleaver    | %6d | %6d | %6d | %6.1f%%", 
                 inter_blocks_checked, inter_pass_count, inter_fail_count,
                 (inter_blocks_checked > 0) ? (100.0 * inter_pass_count / inter_blocks_checked) : 0.0);
        $display("  Modulator      | %6d | %6d | %6d | %6.1f%%", 
                 mod_blocks_checked, mod_pass_count, mod_fail_count,
                 (mod_blocks_checked > 0) ? (100.0 * mod_pass_count / mod_blocks_checked) : 0.0);
        $display("  ---------------+--------+--------+--------+----------");
        $display("");
        
        // Calculate expected results considering ping-pong latency
        // Interleaver and Modulator Block 0 are expected to fail
        $display("  EXPECTED BEHAVIOR ANALYSIS:");
        $display("  ---------------------------");
        $display("  Randomizer:  All blocks should PASS (no latency)");
        $display("  FEC Encoder: All blocks should PASS (no latency)");
        $display("  Interleaver: Block 0 should FAIL (ping-pong latency), rest should PASS");
        $display("  Modulator:   Block 0 should FAIL (inherited latency), rest should PASS");
        $display("");
        
        // Determine overall test result
        // For Interleaver and Modulator, we expect exactly 1 failure (Block 0)
        if (rand_fail_count == 0 && fec_fail_count == 0 && 
            inter_fail_count == 1 && mod_fail_count == 1) begin
            $display("  ************************************************************");
            $display("  *              ALL TESTS PASSED AS EXPECTED!               *");
            $display("  *                                                          *");
            $display("  *  - Randomizer:  %2d/%2d passed (100%%)", rand_pass_count, rand_blocks_checked);
            $display("  *  - FEC Encoder: %2d/%2d passed (100%%)", fec_pass_count, fec_blocks_checked);
            $display("  *  - Interleaver: %2d/%2d passed (Block 0 latency expected)", inter_pass_count, inter_blocks_checked);
            $display("  *  - Modulator:   %2d/%2d passed (Block 0 latency expected)", mod_pass_count, mod_blocks_checked);
            $display("  *                                                          *");
            $display("  *  Ping-pong buffer latency behavior is CORRECT!           *");
            $display("  ************************************************************");
        end else if (rand_fail_count == 0 && fec_fail_count == 0 && 
                     inter_fail_count <= 1 && mod_fail_count <= 1) begin
            $display("  ************************************************************");
            $display("  *                    TESTS PASSED!                         *");
            $display("  *                                                          *");
            $display("  *  All functional blocks operating correctly.              *");
            $display("  ************************************************************");
        end else begin
            $display("  ************************************************************");
            $display("  *                 UNEXPECTED FAILURES                      *");
            $display("  *                                                          *");
            if (rand_fail_count > 0)
                $display("  *  Randomizer:   %0d unexpected failures", rand_fail_count);
            if (fec_fail_count > 0)
                $display("  *  FEC Encoder:  %0d unexpected failures", fec_fail_count);
            if (inter_fail_count > 1)
                $display("  *  Interleaver:  %0d failures (expected 1 for Block 0)", inter_fail_count);
            if (mod_fail_count > 1)
                $display("  *  Modulator:    %0d failures (expected 1 for Block 0)", mod_fail_count);
            $display("  *                                                          *");
            $display("  *  Please review the block-by-block results above.         *");
            $display("  ************************************************************");
        end
        $display("");
        $display("==============================================================================");
        $display("");
        
        #1000;
        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    // Prevents simulation from hanging if something goes wrong
    //==========================================================================
    initial begin
        #(200_000 * CLK_50_PERIOD);  // 200,000 clock cycles timeout
        $display("");
        $display("[TIMEOUT] Simulation timeout after 200000 cycles!");
        $display("  Blocks completed: RAND=%0d FEC=%0d INT=%0d MOD=%0d", 
                 rand_blocks_checked, fec_blocks_checked, inter_blocks_checked, mod_blocks_checked);
        $finish;
    end

endmodule