#===============================================================================
# QuestaSim Compilation Script for WiMAX PHY Project
# Compiles all RTL, IP, and testbench files in correct order
# To run: do compile.do
#===============================================================================

echo "=========================================="
echo "WiMAX PHY Compilation Script"
echo "=========================================="
echo "Current Directory: [pwd]"
echo ""

# Clean up previous simulation
quit -sim

# Delete and recreate libraries (use catch to ignore errors)
catch {vdel -all -lib work}

# Create libraries
vlib work
vmap work work

# Create Altera library mappings (may already exist)
catch {vlib altera_mf}
catch {vmap altera_mf altera_mf}
catch {vlib altera_lnsim}
catch {vmap altera_lnsim altera_lnsim}

#===============================================================================
# Detect Project Layout
#===============================================================================

set ip_path ""
set rtl_path ""
set sim_path ""

# Check for subdirectory layout (IP/, RTL/, sim/)
if {[file isdirectory "[pwd]/IP"] && [file isdirectory "[pwd]/RTL"] && [file isdirectory "[pwd]/sim"]} {
    set ip_path "[pwd]/IP"
    set rtl_path "[pwd]/RTL"
    set sim_path "[pwd]/sim"
    echo "Found subdirectory layout"
} elseif {[file exists "[pwd]/phy_top.sv"]} {
    # Flat layout - all files in same folder
    set ip_path "[pwd]"
    set rtl_path "[pwd]"
    set sim_path "[pwd]"
    echo "Found flat layout"
} else {
    echo "ERROR: Could not detect project layout"
    echo "Please run from project root directory"
    return
}

echo "$ip_path"
echo "$rtl_path"
echo "$sim_path"
echo "IP Path: $ip_path"
echo "RTL Path: $rtl_path"
echo "Sim Path: $sim_path"
echo ""

#===============================================================================
# Compile Altera IP Libraries
#===============================================================================

echo "Compiling Altera Libraries..."
vlog -work altera_mf $ip_path/altera_mf.v
vlog -sv -work altera_lnsim $ip_path/altera_lnsim.sv

#===============================================================================
# Compile IP Cores (PLL, RAM)
#===============================================================================

echo ""
echo "Compiling IP Cores..."
vlog -work work $ip_path/MY_PLL_0002.v
vlog -work work $ip_path/MY_PLL.v

# Compile RAM IPs if they exist
if {[file exists "$ip_path/SDPR.v"]} {
    vlog -work work $ip_path/SDPR.v
}
if {[file exists "$ip_path/RAM_2_PORT.v"]} {
    vlog -work work $ip_path/RAM_2_PORT.v
}

# FEC Dual-Port RAM - USE FEC_DPR (UNREGISTERED outputs), NOT FEC_DPR_NEW!
# FEC_DPR_NEW has registered outputs which add 1 cycle latency and break the encoder
if {[file exists "$ip_path/FEC_DPR.v"]} {
    vlog -work work $ip_path/FEC_DPR.v
    echo "INFO: Using FEC_DPR.v (correct - unregistered outputs)"
} else {
    echo "ERROR: FEC_DPR.v not found in IP folder!"
    echo "       FEC encoder requires FEC_DPR.v with UNREGISTERED outputs."
    echo "       Do NOT use FEC_DPR_NEW.v - it has registered outputs that break timing!"
}

#===============================================================================
# Compile WiMAX Package (MUST be first - contains constants and types)
#===============================================================================

echo ""
echo "Compiling WiMAX Package..."
vlog -sv [pwd]/wimax_pkg.sv

#===============================================================================
# Compile RTL Modules (in dependency order)
#===============================================================================

echo ""
echo "Compiling RTL Modules..."

# PRBS Randomizer
vlog -sv $rtl_path/prbs_randomizer.sv

# FEC Encoder
vlog -sv $rtl_path/fec_encoder.sv

# Interleaver components (compile base modules first)
vlog -sv $rtl_path/interleaver.sv

# PPBuffer components (if they exist)
if {[file exists "$rtl_path/PPBuffer.sv"]} {
    vlog -sv $rtl_path/PPBuffer.sv
}
if {[file exists "$rtl_path/PPBufferControl.sv"]} {
    vlog -sv $rtl_path/PPBufferControl.sv
}

# Interleaver top (depends on interleaver and PPBuffer)
vlog -sv $rtl_path/interleaver_top.sv

# QPSK Modulator
vlog -sv $rtl_path/modulator_qpsk.sv

# PHY Top (depends on all above)
vlog -sv $rtl_path/phy_top.sv

# FPGA Wrappers (depend on phy_top)
if {[file exists "$rtl_path/fpga_wrapper_simple.sv"]} {
    vlog -sv $rtl_path/fpga_wrapper_simple.sv
}

# wimax_fpga_wrapper is optional - use catch to continue if it fails
if {[file exists "$rtl_path/wimax_fpga_wrapper.sv"]} {
    catch {vlog -sv $rtl_path/wimax_fpga_wrapper.sv} result
    if {$result != 0} {
        echo "WARNING: wimax_fpga_wrapper.sv had compilation issues (optional module, continuing...)"
    }
}

#===============================================================================
# Compile Testbenches
#===============================================================================

echo ""
echo "Compiling Testbenches..."

# Accuracy testbench
if {[file exists "$sim_path/tb_wimax_phy_accuracy.sv"]} {
    vlog -sv $sim_path/tb_wimax_phy_accuracy.sv
}

# FPGA wrapper simple testbench
if {[file exists "$sim_path/tb_fpga_wrapper_simple.sv"]} {
    vlog -sv $sim_path/tb_fpga_wrapper_simple.sv
}

# Original working testbenches (if they exist)
if {[file exists "$sim_path/WiMAX_PHY_top_tb.sv"]} {
    vlog -sv $sim_path/WiMAX_PHY_top_tb.sv
}
if {[file exists "$sim_path/wimax_max_top_tb.sv"]} {
    vlog -sv $sim_path/wimax_max_top_tb.sv
}

#===============================================================================
# Compilation Complete
#===============================================================================

echo ""
echo "=========================================="
echo "Compilation Complete!"
echo "=========================================="
echo ""
echo "Available testbenches:"
echo "  - tb_wimax_phy_accuracy"
echo "  - tb_fpga_wrapper_simple"
echo ""
echo "To simulate, run one of:"
echo "  vsim -voptargs=+acc work.tb_wimax_phy_accuracy -L altera_mf -L altera_lnsim"
echo "  vsim -voptargs=+acc work.tb_fpga_wrapper_simple -L altera_mf -L altera_lnsim"
echo ""
