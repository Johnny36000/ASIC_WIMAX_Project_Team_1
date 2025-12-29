#===============================================================================
# QuestaSim Test Script - Accuracy Mode with Golden Data Verification
# Aligned with working WiMAX_PHY_top_tb.sv approach
# To run: do test_accuracy.do
#===============================================================================

echo "=========================================="
echo "WiMAX PHY Accuracy Test - Golden Data Verification"
echo "Aligned with working module verification approach"
echo "=========================================="
echo ""

# Compile first
do compile.do

echo ""
echo "Starting Accuracy Test..."
echo ""

#===============================================================================
# NUM_TEST_BLOCKS Configuration:
# - Set the number of 96-bit data blocks to process through the pipeline
# - Block 0 of Interleaver/Modulator contains uninitialized ping-pong buffer data
#   (this is expected behavior due to 1-block latency of double buffering)
# - Blocks 1 onwards should match golden data
# - Recommended: 20 blocks for thorough testing
#===============================================================================
set NUM_BLOCKS 20

# Start simulation with the accuracy testbench
vsim -voptargs=+acc work.tb_wimax_phy_accuracy -L altera_mf -L altera_lnsim -G NUM_TEST_BLOCKS=$NUM_BLOCKS

# Configure waveform
echo "Configuring waveform viewer..."

#===============================================================================
# Clock and Reset - matching fixed testbench signals
#===============================================================================
add wave -divider "Clock & Reset"
add wave -noupdate /tb_wimax_phy_accuracy/clk_ref
add wave -noupdate /tb_wimax_phy_accuracy/reset_N
add wave -noupdate /tb_wimax_phy_accuracy/locked

#===============================================================================
# Control Signals
#===============================================================================
add wave -divider "Control Signals"
add wave -noupdate /tb_wimax_phy_accuracy/load
add wave -noupdate /tb_wimax_phy_accuracy/en

#===============================================================================
# Input Interface (single-bit serial)
#===============================================================================
add wave -divider "Input Interface"
add wave -noupdate /tb_wimax_phy_accuracy/data_in


#===============================================================================
# PRBS Randomizer - using actual instance name from phy_top.sv
#===============================================================================
add wave -divider "PRBS"
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/clk
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/rst_n
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/load
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/en
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/i_valid
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/i_data
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/i_ready
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/o_valid
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/o_data
add wave -noupdate /tb_wimax_phy_accuracy/dut/randomizer_U0/o_ready
add wave -noupdate -radix unsigned /tb_wimax_phy_accuracy/dut/randomizer_U0/counter
add wave -noupdate -radix binary /tb_wimax_phy_accuracy/dut/randomizer_U0/r_reg

#===============================================================================
# FEC Encoder - using actual instance name from phy_top.sv
#===============================================================================
add wave -divider "FEC"
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/clk_50mhz
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/clk_100mhz
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/rst_n
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/i_valid
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/i_data
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/i_ready
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/o_valid
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/o_data
add wave -noupdate /tb_wimax_phy_accuracy/dut/fec_encoder_U1/o_ready

#===============================================================================
# Interleaver - using actual instance name from phy_top.sv
#===============================================================================
add wave -divider "INTERLEAVER"
add wave -noupdate /tb_wimax_phy_accuracy/dut/interleaver_U2/clk
add wave -noupdate /tb_wimax_phy_accuracy/dut/interleaver_U2/reset_N
add wave -noupdate /tb_wimax_phy_accuracy/dut/interleaver_U2/valid_in
add wave -noupdate /tb_wimax_phy_accuracy/dut/interleaver_U2/data_in
add wave -noupdate /tb_wimax_phy_accuracy/dut/interleaver_U2/ready_out
add wave -noupdate /tb_wimax_phy_accuracy/dut/interleaver_U2/valid_out
add wave -noupdate /tb_wimax_phy_accuracy/dut/interleaver_U2/data_out
add wave -noupdate /tb_wimax_phy_accuracy/dut/interleaver_U2/ready_in

#===============================================================================
# QPSK Modulator - using actual instance name from phy_top.sv
#===============================================================================
add wave -divider "MODULATOR"
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/clk
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/rst_n
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/i_valid
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/i_data
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/i_ready
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/o_valid
add wave -noupdate -radix decimal /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/I_comp
add wave -noupdate -radix decimal /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/Q_comp
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/o_ready
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/bit_count
add wave -noupdate /tb_wimax_phy_accuracy/dut/qpsk_MOD_U3/b0



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

echo ""
echo "Running simulation..."
echo ""
echo "Test Configuration:"
echo "  - Number of test blocks: $NUM_BLOCKS"
echo "  - Input: RANDOMIZER_INPUT from package (96 bits repeated)"
echo "  - Mode: Stage-by-stage verification against golden data"
echo ""
echo "Pipeline: Randomizer -> FEC -> Interleaver -> Modulator"
echo ""
echo "PING-PONG BUFFER LATENCY NOTE:"
echo "  Block 0 of Interleaver/Modulator outputs uninitialized data"
echo "  (expected behavior - 1 block latency from double buffering)"
echo "  Blocks 1 onwards should match golden reference data"
echo ""

run -all

echo ""
echo "Zooming waveform to fit..."
wave zoom full

echo ""
echo "=========================================="
echo "Accuracy Test Complete!"
echo "=========================================="
