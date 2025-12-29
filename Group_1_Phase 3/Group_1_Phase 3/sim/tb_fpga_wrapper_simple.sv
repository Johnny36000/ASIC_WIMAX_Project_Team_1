//==============================================================================
// File Name:    tb_fpga_wrapper_simple.sv
// Description:  Testbench for fpga_wrapper_simple with multi-packet verification
//               Verifies LATCHED pass/fail LED behavior per doctor's requirements
// Author:       Group 1: John Fahmy, Abanoub Emad, Omar ElShazli
//               Supervised by Dr. Ahmed Abou Auf
// Course:       ECNG410401 ASIC Design Using CAD
// Version:      6.0 (Multi-packet verification - 5 packets)
// Date:         2025-12-20
//
// Notes:
//   - v6.0: Multi-packet verification:
//           - Captures NUM_PACKETS (5) consecutive packets per stage
//           - Reports pass/fail for each packet
//           - Final LED status shows if ALL packets passed
//==============================================================================

// Time unit declarations
timeunit 1ns;
timeprecision 1ps;

module tb_fpga_wrapper_simple;

    import wimax_pkg::*;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLOCK_PERIOD = 20;  // 50 MHz = 20 ns period
    localparam CLK_HALF_PERIOD = CLOCK_PERIOD / 2;
    localparam NUM_PACKETS = 5;    // Number of packets to verify (must match wrapper)
    
    // Debounce cycles for simulation
    localparam DEBOUNCE_CYCLES = 600_000;
    
    //==========================================================================
    // DUT Signals
    //==========================================================================
    logic        CLOCK_50;
    logic        KEY0;           // Reset (active-low)
    logic        KEY1;           // Load/Start (active-low)
    logic        SW0;            // Continuous mode
    logic [9:0]  LEDR;
    
    //==========================================================================
    // Testbench Signals
    //==========================================================================
    int          test_errors = 0;
    int          test_number;
    logic [3:0]  led_state_saved;
    
    // Block capture counters
    int          rand_blocks_captured = 0;
    int          fec_blocks_captured = 0;
    int          inter_blocks_captured = 0;
    int          mod_blocks_captured = 0;
    
    // Statistics
    int          rand_pass = 0, rand_fail = 0;
    int          fec_pass = 0, fec_fail = 0;
    int          inter_pass = 0, inter_fail = 0;
    int          mod_pass = 0, mod_fail = 0;
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        CLOCK_50 = 1;
        forever begin
            #CLK_HALF_PERIOD CLOCK_50 = ~CLOCK_50;
        end
    end
    
    //==========================================================================
    // DUT Instance
    //==========================================================================
    fpga_wrapper_simple #(
        .NUM_PACKETS(NUM_PACKETS)
    ) dut (
        .CLOCK_50(CLOCK_50),
        .KEY0(KEY0),
        .KEY1(KEY1),
        .SW0(SW0),
        .LEDR(LEDR)
    );
    
    //==========================================================================
    // Helper Tasks
    //==========================================================================
    
    task automatic apply_reset();
        $display("\n[%0t] Applying reset...", $time);
        KEY0 = 0;  // Active-low reset
        repeat(10) @(posedge CLOCK_50);
        KEY0 = 1;  // Release reset
        $display("[%0t] Reset released", $time);
    endtask
    
    task automatic wait_pll_lock();
        $display("[%0t] Waiting for PLL lock...", $time);
        wait(LEDR[9] == 1);
        $display("[%0t] PLL locked (LEDR[9] = 1)", $time);
        repeat(10) @(posedge CLOCK_50);
    endtask
    
    task automatic press_key1();
        $display("[%0t] Pressing KEY1 (load/start)...", $time);
        KEY1 = 0;  // Active-low
        repeat(DEBOUNCE_CYCLES) @(posedge CLOCK_50);
        KEY1 = 1;  // Release
        $display("[%0t] KEY1 released", $time);
    endtask

    //==========================================================================
    // Randomizer Output Verification Monitor
    // Captures NUM_PACKETS packets
    //==========================================================================
    integer rand_i = 95;
    logic [95:0] rand_out_captured;
    
    always @(posedge dut.clk_50) begin
        if (KEY0 == 1'b0) begin
            rand_i = 95;
        end else begin
            if (dut.randomizer_valid_out && rand_blocks_captured < NUM_PACKETS) begin
                rand_out_captured[rand_i] = dut.randomizer_data_out;
                if (rand_i == 0) begin
                    rand_blocks_captured = rand_blocks_captured + 1;
                    $display("");
                    $display("[%0t] RANDOMIZER Packet %0d of %0d:", $time, rand_blocks_captured, NUM_PACKETS);
                    check_output_96(rand_out_captured, RANDOMIZER_OUTPUT, "RANDOMIZER", 
                                    rand_pass, rand_fail);
                    rand_i = 95;
                end else begin
                    rand_i = rand_i - 1;
                end
            end
        end
    end

    //==========================================================================
    // FEC Output Verification Monitor
    // Captures NUM_PACKETS packets
    //==========================================================================
    integer fec_i = 191;
    logic [191:0] fec_out_captured;
    
    always @(posedge dut.clk_100) begin
        if (KEY0 == 1'b0) begin
            fec_i = 191;
        end else begin
            if (dut.FEC_valid_out && fec_blocks_captured < NUM_PACKETS) begin
                fec_out_captured[fec_i] = dut.FEC_data_out;
                if (fec_i == 0) begin
                    fec_blocks_captured = fec_blocks_captured + 1;
                    $display("");
                    $display("[%0t] FEC Packet %0d of %0d:", $time, fec_blocks_captured, NUM_PACKETS);
                    check_output_192(fec_out_captured, FEC_ENCODER_OUTPUT, "FEC",
                                     fec_pass, fec_fail);
                    fec_i = 191;
                end else begin
                    fec_i = fec_i - 1;
                end
            end
        end
    end

    //==========================================================================
    // Interleaver Output Verification Monitor
    // Captures NUM_PACKETS packets
    //==========================================================================
    integer inter_i = 191;
    logic [191:0] inter_out_captured;
    
    always @(posedge dut.clk_100) begin
        if (KEY0 == 1'b0) begin
            inter_i = 191;
        end else begin
            if (dut.interleaver_valid_out && inter_blocks_captured < NUM_PACKETS) begin
                inter_out_captured[inter_i] = dut.interleaver_data_out;
                if (inter_i == 0) begin
                    inter_blocks_captured = inter_blocks_captured + 1;
                    $display("");
                    $display("[%0t] INTERLEAVER Packet %0d of %0d:", $time, inter_blocks_captured, NUM_PACKETS);
                    check_output_192(inter_out_captured, INTERLEAVER_OUTPUT, "INTERLEAVER",
                                     inter_pass, inter_fail);
                    inter_i = 191;
                end else begin
                    inter_i = inter_i - 1;
                end
            end
        end
    end

    //==========================================================================
    // Modulator Output Verification Monitor
    // QPSK outputs one symbol per 2 input bits - capture every 2nd valid cycle
    // Captures NUM_PACKETS packets
    //==========================================================================
    integer mod_i = 0;
    logic [1:0] mod_out_captured [0:95];
    logic mod_valid_toggle = 0;
    
    always @(posedge dut.clk_100) begin
        if (KEY0 == 1'b0) begin
            mod_i = 0;
            mod_valid_toggle = 0;
        end else begin
            if (dut.mod_valid_out && mod_blocks_captured < NUM_PACKETS) begin
                mod_valid_toggle = ~mod_valid_toggle;
                
                // Capture every 2nd valid cycle (when QPSK symbol is complete)
                if (mod_valid_toggle == 1'b1) begin
                    mod_out_captured[mod_i] = {dut.mod_I_comp[15], dut.mod_Q_comp[15]};
                    
                    if (mod_i == 95) begin
                        mod_blocks_captured = mod_blocks_captured + 1;
                        $display("");
                        $display("[%0t] MODULATOR Packet %0d of %0d:", $time, mod_blocks_captured, NUM_PACKETS);
                        check_mod_output(mod_out_captured, MOD_OUTPUT, "MODULATOR",
                                         mod_pass, mod_fail);
                        mod_i = 0;
                    end else begin
                        mod_i = mod_i + 1;
                    end
                end
            end
        end
    end

    //==========================================================================
    // Verification Functions
    //==========================================================================
    
    task automatic check_output_96(
        input logic [95:0] actual,
        input logic [95:0] expected,
        input string stage_name,
        ref int pass_count,
        ref int fail_count
    );
        integer bit_idx;
        integer error_count;
        begin
            error_count = 0;
            for (bit_idx = 95; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                if (actual[bit_idx] !== expected[bit_idx]) begin
                    if (error_count < 5) begin
                        $display("  Mismatch at bit %0d: Expected %b, Got %b", 
                                 bit_idx, expected[bit_idx], actual[bit_idx]);
                    end
                    error_count = error_count + 1;
                end
            end
            
            if (error_count == 0) begin
                $display("  PASS: All 96 bits match expected output");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: %0d bit mismatches found", error_count);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    task automatic check_output_192(
        input logic [191:0] actual,
        input logic [191:0] expected,
        input string stage_name,
        ref int pass_count,
        ref int fail_count
    );
        integer bit_idx;
        integer error_count;
        begin
            error_count = 0;
            for (bit_idx = 191; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                if (actual[bit_idx] !== expected[bit_idx]) begin
                    if (error_count < 5) begin
                        $display("  Mismatch at bit %0d: Expected %b, Got %b", 
                                 bit_idx, expected[bit_idx], actual[bit_idx]);
                    end
                    error_count = error_count + 1;
                end
            end
            
            if (error_count == 0) begin
                $display("  PASS: All 192 bits match expected output");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: %0d bit mismatches found", error_count);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    task automatic check_mod_output(
        input logic [1:0] actual [0:95],
        input logic [1:0] expected [0:95],
        input string stage_name,
        ref int pass_count,
        ref int fail_count
    );
        integer sym_idx;
        integer error_count;
        begin
            error_count = 0;
            for (sym_idx = 0; sym_idx < 96; sym_idx = sym_idx + 1) begin
                if (actual[sym_idx] !== expected[sym_idx]) begin
                    if (error_count < 5) begin
                        $display("  Symbol %0d mismatch: Expected %b, Got %b", 
                                 sym_idx, expected[sym_idx], actual[sym_idx]);
                    end
                    error_count = error_count + 1;
                end
            end
            
            if (error_count == 0) begin
                $display("  PASS: All 96 symbols match expected output");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: %0d symbol mismatches found", error_count);
                fail_count = fail_count + 1;
            end
        end
    endtask

    //==========================================================================
    // LED Status Display
    //==========================================================================
    task automatic display_led_status();
        $display("");
        $display("[%0t] ============ LED STATUS ============", $time);
        $display("  Pass/Fail LEDs (ON=Pass, OFF=Fail):");
        $display("    LEDR[0] (PRBS Pass)        = %s", LEDR[0] ? "ON  [PASS]" : "OFF [FAIL]");
        $display("    LEDR[1] (FEC Pass)         = %s", LEDR[1] ? "ON  [PASS]" : "OFF [FAIL]");
        $display("    LEDR[2] (Interleaver Pass) = %s", LEDR[2] ? "ON  [PASS]" : "OFF [FAIL]");
        $display("    LEDR[3] (Modulator Pass)   = %s", LEDR[3] ? "ON  [PASS]" : "OFF [FAIL]");
        $display("  Verification Complete Flags:");
        $display("    LEDR[4] (PRBS Verified)    = %0d", LEDR[4]);
        $display("    LEDR[5] (FEC Verified)     = %0d", LEDR[5]);
        $display("    LEDR[6] (Intlv Verified)   = %0d", LEDR[6]);
        $display("    LEDR[7] (Mod Verified)     = %0d", LEDR[7]);
        $display("  System Status:");
        $display("    LEDR[8] (Enable Active)    = %0d", LEDR[8]);
        $display("    LEDR[9] (PLL Locked)       = %0d", LEDR[9]);
        $display("  ======================================");
        $display("");
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        // Initialize
        test_errors = 0;
        test_number = 0;
        KEY0 = 1;
        KEY1 = 1;
        SW0 = 0;
        
        $display("");
        $display("================================================================================");
        $display("WiMAX PHY - FPGA Wrapper Simple Testbench v6.0");
        $display("================================================================================");
        $display("Multi-Packet Verification: %0d packets per stage", NUM_PACKETS);
        $display("");
        $display("Testing LATCHED Pass/Fail LED Behavior");
        $display("  LED ON  = ALL packets match golden data (PASS)");
        $display("  LED OFF = ANY packet does NOT match golden data (FAIL)");
        $display("================================================================================");
        
        //======================================================================
        // TEST 1: Reset and Initialization
        //======================================================================
        test_number = 1;
        $display("\n[TEST %0d] Reset and Initialization", test_number);
        $display("----------------------------------------------------------------------");
        
        apply_reset();
        wait_pll_lock();
        
        $display("[%0t] Checking initial LED state...", $time);
        display_led_status();
        
        // After reset, pass LEDs should be ON (assuming pass until proven otherwise)
        // Verification complete flags should be OFF
        if (LEDR[7:4] == 4'b0000) begin
            $display("[%0t] PASS: Verification flags are all OFF after reset", $time);
        end else begin
            $display("[%0t] FAIL: Some verification flags are ON after reset", $time);
            test_errors++;
        end
        
        if (LEDR[9] == 1) begin
            $display("[%0t] PASS: PLL locked after reset", $time);
        end else begin
            $display("[%0t] FAIL: PLL not locked after reset", $time);
            test_errors++;
        end
        
        //======================================================================
        // TEST 2: Start Transmission and Verify Multiple Packets
        //======================================================================
        test_number = 2;
        $display("\n[TEST %0d] Start Transmission - Verifying %0d Packets", test_number, NUM_PACKETS);
        $display("----------------------------------------------------------------------");
        
        SW0 = 0;  // Single-shot mode (stops after NUM_PACKETS)
        
        repeat(100) @(posedge CLOCK_50);
        
        $display("[%0t] Starting transmission (pressing KEY1)...", $time);
        press_key1();
        
        $display("[%0t] Waiting for %0d packets to be verified...", $time, NUM_PACKETS);
        
        // Wait for all verification complete flags to be set
        fork
            begin
                wait(LEDR[4] == 1);
                $display("[%0t] PRBS verification complete (%0d packets)", $time, NUM_PACKETS);
            end
            begin
                wait(LEDR[5] == 1);
                $display("[%0t] FEC verification complete (%0d packets)", $time, NUM_PACKETS);
            end
            begin
                wait(LEDR[6] == 1);
                $display("[%0t] Interleaver verification complete (%0d packets)", $time, NUM_PACKETS);
            end
            begin
                wait(LEDR[7] == 1);
                $display("[%0t] Modulator verification complete (%0d packets)", $time, NUM_PACKETS);
            end
        join
        
        // Wait for everything to settle
        repeat(1000) @(posedge CLOCK_50);
        
        $display("");
        $display("[%0t] All verifications complete!", $time);
        display_led_status();
        
        //======================================================================
        // TEST 3: Verify Final Pass/Fail LED Status
        //======================================================================
        test_number = 3;
        $display("\n[TEST %0d] Verify Final Pass/Fail LED Status", test_number);
        $display("----------------------------------------------------------------------");
        
        // Check each LED
        if (LEDR[0] == 1) begin
            $display("[%0t] PRBS:        ALL %0d packets PASSED", $time, rand_pass);
        end else begin
            $display("[%0t] PRBS:        FAILED (%0d pass, %0d fail)", $time, rand_pass, rand_fail);
            test_errors++;
        end
        
        if (LEDR[1] == 1) begin
            $display("[%0t] FEC:         ALL %0d packets PASSED", $time, fec_pass);
        end else begin
            $display("[%0t] FEC:         FAILED (%0d pass, %0d fail)", $time, fec_pass, fec_fail);
            test_errors++;
        end
        
        if (LEDR[2] == 1) begin
            $display("[%0t] Interleaver: ALL %0d packets PASSED", $time, inter_pass);
        end else begin
            $display("[%0t] Interleaver: FAILED (%0d pass, %0d fail)", $time, inter_pass, inter_fail);
            test_errors++;
        end
        
        if (LEDR[3] == 1) begin
            $display("[%0t] Modulator:   ALL %0d packets PASSED", $time, mod_pass);
        end else begin
            $display("[%0t] Modulator:   FAILED (%0d pass, %0d fail)", $time, mod_pass, mod_fail);
            test_errors++;
        end
        
        //======================================================================
        // TEST 4: Verify Enable Signal Disabled (Single-Shot Mode)
        //======================================================================
        test_number = 4;
        $display("\n[TEST %0d] Verify Single-Shot Mode (Enable Signal)", test_number);
        $display("----------------------------------------------------------------------");
        
        if (LEDR[8] == 0) begin
            $display("[%0t] PASS: Enable signal is OFF (pipeline stopped after %0d packets)", $time, NUM_PACKETS);
        end else begin
            $display("[%0t] INFO: Enable signal is still ON", $time);
        end
        
        //======================================================================
        // TEST 5: Verify LEDs Remain Latched
        //======================================================================
        test_number = 5;
        $display("\n[TEST %0d] Verify LEDs Remain Latched", test_number);
        $display("----------------------------------------------------------------------");
        
        led_state_saved = LEDR[3:0];
        
        $display("[%0t] Waiting 5000 clock cycles...", $time);
        repeat(5000) @(posedge CLOCK_50);
        
        if (LEDR[3:0] == led_state_saved) begin
            $display("[%0t] PASS: LEDs remain latched (no state change)", $time);
        end else begin
            $display("[%0t] FAIL: LED state changed unexpectedly", $time);
            test_errors++;
        end
        
        //======================================================================
        // TEST 6: Verify Reset Clears State
        //======================================================================
        test_number = 6;
        $display("\n[TEST %0d] Verify Reset Clears State", test_number);
        $display("----------------------------------------------------------------------");
        
        led_state_saved = LEDR[3:0];  // Save for final summary
        
        apply_reset();
        wait_pll_lock();
        
        if (LEDR[7:4] == 4'b0000) begin
            $display("[%0t] PASS: Verification flags cleared after reset", $time);
        end else begin
            $display("[%0t] FAIL: Verification flags not cleared after reset", $time);
            test_errors++;
        end

        //======================================================================
        // Final Summary
        //======================================================================
        $display("\n================================================================================");
        $display("TEST SUMMARY");
        $display("================================================================================");
        $display("");
        $display("  Packets Verified: %0d per stage", NUM_PACKETS);
        $display("");
        $display("  Stage        | Captured | Passed | Failed | LED Status");
        $display("  -------------|----------|--------|--------|------------");
        $display("  Randomizer   |    %2d    |   %2d   |   %2d   | %s", 
                 rand_blocks_captured, rand_pass, rand_fail, led_state_saved[0] ? "ON [PASS]" : "OFF [FAIL]");
        $display("  FEC          |    %2d    |   %2d   |   %2d   | %s", 
                 fec_blocks_captured, fec_pass, fec_fail, led_state_saved[1] ? "ON [PASS]" : "OFF [FAIL]");
        $display("  Interleaver  |    %2d    |   %2d   |   %2d   | %s", 
                 inter_blocks_captured, inter_pass, inter_fail, led_state_saved[2] ? "ON [PASS]" : "OFF [FAIL]");
        $display("  Modulator    |    %2d    |   %2d   |   %2d   | %s", 
                 mod_blocks_captured, mod_pass, mod_fail, led_state_saved[3] ? "ON [PASS]" : "OFF [FAIL]");
        $display("");
        $display("  Test errors: %0d", test_errors);
        $display("");
        
        if (test_errors == 0 && led_state_saved == 4'b1111) begin
            $display("  ************************************************************");
            $display("  *         ALL TESTS PASSED - All 4 LEDs are ON            *");
            $display("  *                                                          *");
            $display("  *  All %0d packets verified successfully for each stage    *", NUM_PACKETS);
            $display("  ************************************************************");
        end else if (led_state_saved == 4'b1111) begin
            $display("  ************************************************************");
            $display("  *      VERIFICATION PASSED - Some test issues detected     *");
            $display("  ************************************************************");
        end else begin
            $display("  ************************************************************");
            $display("  *                 SOME TESTS FAILED                        *");
            $display("  ************************************************************");
        end
        
        $display("");
        $display("================================================================================");
        $display("Simulation complete at time %0t", $time);
        $display("================================================================================");
        
        #1000;
        $finish;
    end
    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #100_000_000;  // 100ms timeout (more time for 5 packets)
        $display("\n[%0t] ERROR: Simulation timeout!", $time);
        $display("  Packets captured: RAND=%0d FEC=%0d INT=%0d MOD=%0d", 
                 rand_blocks_captured, fec_blocks_captured, inter_blocks_captured, mod_blocks_captured);
        display_led_status();
        $finish;
    end

endmodule