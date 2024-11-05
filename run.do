# Create a working library (called 'work'). This is required for simulation.
vlib work

# Compile the Verilog design file (replace 'your_design.v' with your actual Verilog file name)
# If you have multiple files, you can add them here as well.
vlog your_design.v

# Optionally, compile the testbench file (replace 'your_testbench.v' with the testbench Verilog file).
# This is necessary if you're simulating using a testbench.
vlog your_testbench.v

# Invoke the simulator and specify the top module (either the design or testbench top module).
# Replace 'your_testbench' or 'your_design' with the actual top module name.
vsim your_testbench

# Add signals to the waveform window for analysis (replace 'top_module' with your top module name).
# This ensures you can see signals of interest when the simulation runs.
add wave *

# Run the simulation indefinitely (until a `$finish` or `$stop` is encountered in the code).
run -all

# If you only want to run the simulation for a specific amount of time (say 1000 time units), use:
# run 1000
