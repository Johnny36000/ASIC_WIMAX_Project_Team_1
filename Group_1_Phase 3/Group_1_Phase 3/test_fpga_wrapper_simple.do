##==============================================================================
## QuestaSim/ModelSim DO File - FPGA Wrapper Multi-Packet Test
## Tests LATCHED Pass/Fail LED Behavior with 5 Packets
## To run: do test_fpga_wrapper_simple.do
##==============================================================================

echo "================================================================================"
echo "WiMAX PHY - FPGA Wrapper Simple Testbench v6.0"
echo "Multi-Packet Verification (5 packets per stage)"
echo ""
echo "LED Assignment:"
echo "  LEDR[0] = PRBS Pass     (ON = All packets pass)"
echo "  LEDR[1] = FEC Pass      (ON = All packets pass)"
echo "  LEDR[2] = Intlv Pass    (ON = All packets pass)"
echo "  LEDR[3] = Mod Pass      (ON = All packets pass)"
echo "================================================================================"

##==============================================================================
## Clean up previous simulation
##==============================================================================
quit -sim

# Suppress errors if libraries don't exist
catch {vdel -all -lib work}
catch {vdel -all -lib altera_mf}
catch {vdel -all -lib altera_lnsim}

##==============================================================================
## Create libraries
##==============================================================================
echo "Creating work libraries..."
vlib work
vmap work work
vlib altera_mf
vmap altera_mf altera_mf
vlib altera_lnsim
vmap altera_lnsim altera_lnsim

##==============================================================================
## Detect Project Layout
##==============================================================================
set rtl_path ""
set sim_path ""
set ip_path ""

if {[file isdirectory "[pwd]/RTL"] && [file isdirectory "[pwd]/sim"] && [file isdirectory "[pwd]/IP"]} {
    set rtl_path "[pwd]/RTL"
    set sim_path "[pwd]/sim"
    set ip_path "[pwd]/IP"
    echo "Found subdirectory layout (RTL/, sim/, IP/)"
} elseif {[file exists "[pwd]/fpga_wrapper_simple.sv"]} {
    set rtl_path "[pwd]"
    set sim_path "[pwd]"
    set ip_path "[pwd]"
    echo "Found flat layout"
} else {
    echo "ERROR: Could not find source files in [pwd]"
    echo "Please run this script from the project root directory"
    return
}

##==============================================================================
## Compile Order
##==============================================================================

echo "Compiling Altera IP simulation libraries..."
vlog -work altera_mf $ip_path/altera_mf.v
vlog -sv -work altera_lnsim $ip_path/altera_lnsim.sv

echo "Compiling IP cores..."
vlog -work work $ip_path/MY_PLL_0002.v
vlog -work work $ip_path/MY_PLL.v

if {[file exists "$ip_path/SDPR.v"]} {
    vlog -work work $ip_path/SDPR.v
}
if {[file exists "$ip_path/FEC_DPR.v"]} {
    vlog -work work $ip_path/FEC_DPR.v
}

echo "Compiling package..."
vlog -sv -work work [pwd]/wimax_pkg.sv

echo "Compiling RTL files..."
vlog -sv -work work $rtl_path/prbs_randomizer.sv
vlog -sv -work work $rtl_path/fec_encoder.sv
vlog -sv -work work $rtl_path/interleaver.sv
vlog -sv -work work $rtl_path/PPBuffer.sv
vlog -sv -work work $rtl_path/PPBufferControl.sv
vlog -sv -work work $rtl_path/interleaver_top.sv
vlog -sv -work work $rtl_path/modulator_qpsk.sv
vlog -sv -work work $rtl_path/phy_top.sv
vlog -sv -work work $rtl_path/fpga_wrapper_simple.sv

echo "Compiling testbench..."
vlog -sv -work work $sim_path/tb_fpga_wrapper_simple.sv

##==============================================================================
## Start Simulation
##==============================================================================
echo "Starting simulation..."
vsim -voptargs=+acc work.tb_fpga_wrapper_simple -L altera_mf -L altera_lnsim

##==============================================================================
## Waveform Setup
##==============================================================================

# Clock and Reset
add wave -divider "Clock and Reset"
add wave -noupdate /tb_fpga_wrapper_simple/CLOCK_50
add wave -noupdate /tb_fpga_wrapper_simple/KEY0
add wave -noupdate /tb_fpga_wrapper_simple/dut/reset_N

# Control Inputs
add wave -divider "Control Inputs"
add wave -noupdate /tb_fpga_wrapper_simple/KEY1
add wave -noupdate /tb_fpga_wrapper_simple/SW0
add wave -noupdate /tb_fpga_wrapper_simple/dut/load
add wave -noupdate /tb_fpga_wrapper_simple/dut/en
add wave -noupdate /tb_fpga_wrapper_simple/dut/transmission_started

# PASS/FAIL LEDs (Main Focus)
add wave -divider "=== PASS/FAIL LEDs (ON=Pass, OFF=Fail) ==="
add wave -noupdate -color {Spring Green} /tb_fpga_wrapper_simple/LEDR[0]
add wave -noupdate -color {Spring Green} /tb_fpga_wrapper_simple/LEDR[1]
add wave -noupdate -color {Spring Green} /tb_fpga_wrapper_simple/LEDR[2]
add wave -noupdate -color {Spring Green} /tb_fpga_wrapper_simple/LEDR[3]

add wave -divider "Verification Complete Flags"
add wave -noupdate -color {Cyan} /tb_fpga_wrapper_simple/LEDR[4]
add wave -noupdate -color {Cyan} /tb_fpga_wrapper_simple/LEDR[5]
add wave -noupdate -color {Cyan} /tb_fpga_wrapper_simple/LEDR[6]
add wave -noupdate -color {Cyan} /tb_fpga_wrapper_simple/LEDR[7]

add wave -divider "System Status"
add wave -noupdate -color {Yellow} /tb_fpga_wrapper_simple/LEDR[8]
add wave -noupdate -color {Orange} /tb_fpga_wrapper_simple/LEDR[9]

add wave -divider "All LEDs (Binary)"
add wave -noupdate -radix binary /tb_fpga_wrapper_simple/LEDR

# PLL
add wave -divider "PLL"
add wave -noupdate /tb_fpga_wrapper_simple/dut/pll_locked
add wave -noupdate /tb_fpga_wrapper_simple/dut/clk_50
add wave -noupdate /tb_fpga_wrapper_simple/dut/clk_100

# Randomizer Verification
add wave -divider "Randomizer Verification"
add wave -noupdate /tb_fpga_wrapper_simple/dut/randomizer_valid_out
add wave -noupdate /tb_fpga_wrapper_simple/dut/randomizer_data_out
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/dut/randomizer_out_counter
add wave -noupdate /tb_fpga_wrapper_simple/dut/randomizer_block_error
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/dut/randomizer_packet_count
add wave -noupdate -color {Spring Green} /tb_fpga_wrapper_simple/dut/prbs_pass_latched
add wave -noupdate /tb_fpga_wrapper_simple/dut/prbs_verified

# FEC Verification
add wave -divider "FEC Verification"
add wave -noupdate /tb_fpga_wrapper_simple/dut/FEC_valid_out
add wave -noupdate /tb_fpga_wrapper_simple/dut/FEC_data_out
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/dut/FEC_counter
add wave -noupdate /tb_fpga_wrapper_simple/dut/FEC_block_error
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/dut/FEC_packet_count
add wave -noupdate -color {Spring Green} /tb_fpga_wrapper_simple/dut/fec_pass_latched
add wave -noupdate /tb_fpga_wrapper_simple/dut/fec_verified

# Interleaver Verification
add wave -divider "Interleaver Verification"
add wave -noupdate /tb_fpga_wrapper_simple/dut/interleaver_valid_out
add wave -noupdate /tb_fpga_wrapper_simple/dut/interleaver_data_out
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/dut/interleaver_counter
add wave -noupdate /tb_fpga_wrapper_simple/dut/interleaver_block_error
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/dut/interleaver_packet_count
add wave -noupdate -color {Spring Green} /tb_fpga_wrapper_simple/dut/interleaver_pass_latched
add wave -noupdate /tb_fpga_wrapper_simple/dut/interleaver_verified

# Modulator Verification
add wave -divider "Modulator Verification"
add wave -noupdate /tb_fpga_wrapper_simple/dut/mod_valid_out
add wave -noupdate -radix decimal /tb_fpga_wrapper_simple/dut/mod_I_comp
add wave -noupdate -radix decimal /tb_fpga_wrapper_simple/dut/mod_Q_comp
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/dut/mod_counter
add wave -noupdate /tb_fpga_wrapper_simple/dut/mod_block_error
add wave -noupdate /tb_fpga_wrapper_simple/dut/mod_valid_count
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/dut/mod_packet_count
add wave -noupdate -color {Spring Green} /tb_fpga_wrapper_simple/dut/modulator_pass_latched
add wave -noupdate /tb_fpga_wrapper_simple/dut/modulator_verified

# PHY Top Internal Signals
add wave -divider "PHY Top (WiMAX_PHY_U0)"
add wave -noupdate /tb_fpga_wrapper_simple/dut/WiMAX_PHY_U0/locked
add wave -noupdate /tb_fpga_wrapper_simple/dut/WiMAX_PHY_U0/prbs_valid
add wave -noupdate /tb_fpga_wrapper_simple/dut/WiMAX_PHY_U0/fec_valid
add wave -noupdate /tb_fpga_wrapper_simple/dut/WiMAX_PHY_U0/interleaver_valid
add wave -noupdate /tb_fpga_wrapper_simple/dut/WiMAX_PHY_U0/valid_out

# Testbench Counters
add wave -divider "TB Packet Counters"
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/rand_blocks_captured
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/fec_blocks_captured
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/inter_blocks_captured
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/mod_blocks_captured

add wave -divider "TB Statistics"
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/rand_pass
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/rand_fail
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/fec_pass
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/fec_fail
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/inter_pass
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/inter_fail
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/mod_pass
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/mod_fail

add wave -divider "Test Status"
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/test_number
add wave -noupdate -radix unsigned /tb_fpga_wrapper_simple/test_errors

# Configure wave window
configure wave -namecolwidth 350
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

##==============================================================================
## Run Simulation
##==============================================================================
echo ""
echo "================================================================================"
echo "Running simulation with 5 packets per stage..."
echo ""
echo "Expected behavior:"
echo "  - 5 packets will be processed through each stage"
echo "  - LED stays ON only if ALL 5 packets pass"
echo "  - LED goes OFF if ANY packet fails"
echo "  - Pipeline stops after all verifications complete (single-shot mode)"
echo "================================================================================"
echo ""

# Run the simulation to completion
run -all

# Zoom waveform to show all activity
wave zoom full

echo ""
echo "================================================================================"
echo "Simulation complete!"
echo ""
echo "EXPECTED RESULT:"
echo "  All 4 pass LEDs (LEDR[0:3]) should be ON if all 5 packets matched"
echo "  Verification flags (LEDR[4:7]) should all be ON"
echo "  Enable (LEDR[8]) should be OFF (pipeline stopped)"
echo "  PLL Lock (LEDR[9]) should be ON"
echo ""
echo "Check the transcript window for detailed packet-by-packet results."
echo "================================================================================"
