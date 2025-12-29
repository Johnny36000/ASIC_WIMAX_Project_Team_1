# ==============================================================================
# Timing Constraints for WiMAX FPGA Wrapper (fpga_wrapper_simple.sv)
# ==============================================================================
# Simplified SDC for DE0-CV with Cyclone V and MY_PLL
#
# To use:
#   1. Assignments → Settings → Timing Analyzer → SDC Files
#   2. Add this file
#   3. Full recompile
#   4. Tools → Timing Analyzer → Update Timing Netlist → Report Timing
# ==============================================================================

# ==============================================================================
# Input Clock Definition (50 MHz board oscillator)
# ==============================================================================
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# ==============================================================================
# PLL-Generated Clocks
# ==============================================================================
# Let Quartus automatically discover PLL clocks
# This creates clocks for all PLL outputs based on PLL configuration
derive_pll_clocks

# Add clock uncertainty for jitter/skew
derive_clock_uncertainty

# ==============================================================================
# Asynchronous Inputs (Push Buttons & Switches)
# ==============================================================================
# These go through synchronizers, so no timing constraints needed
set_false_path -from [get_ports {KEY0}] -to *
set_false_path -from [get_ports {KEY1}] -to *
set_false_path -from [get_ports {SW0}] -to *

# ==============================================================================
# Asynchronous Outputs (LEDs)
# ==============================================================================
# LEDs are slow (human-visible) - no timing constraints needed
set_false_path -from * -to [get_ports {LEDR[*]}]

# ==============================================================================
# End of Constraints
# ==============================================================================
