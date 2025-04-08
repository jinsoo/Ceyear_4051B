#
# advanced_features.jl - Example demonstrating the advanced features added to Ceyear_4051B
#
# This example shows how to use the extended functionality including
# bandwidth settings, markers, detectors, trace modes, and data export.

using Ceyear_4051B
using Dates
using Statistics

"""
    run_advanced_example()

Demonstrates the use of advanced spectrum analyzer features.
"""
function run_advanced_example()
    println("CEYEAR 4051B Advanced Features Example")
    println("======================================")
    
    # Connect to the spectrum analyzer
    println("\nConnecting to spectrum analyzer...")
    sa = SpectrumAnalyzer()
    
    # Configure basic settings
    println("\nConfiguring basic settings...")
    center_freq = 2.45  # WiFi band center (2.45 GHz)
    span = 100          # 100 MHz span
    
    set_freq(sa, center_freq, span)
    set_reference_level(sa, 0)  # Set 0 dBm reference level
    set_attenuation(sa, 0, true)  # Use auto attenuation
    
    # Configure bandwidth settings
    println("\nConfiguring bandwidth settings...")
    set_bandwidth(sa, 10e3, 1e3, false)  # 10 kHz RBW, 1 kHz VBW
    
    # Configure detector and trace modes
    println("\nConfiguring detector and trace modes...")
    set_detector(sa, "RMS")          # RMS detector for average power measurements
    set_trace_mode(sa, "WRITE", 1)   # Clear and write mode for trace 1
    set_trace_mode(sa, "MAXHold", 2) # Maximum hold mode for trace 2
    
    # Configure sweep
    println("\nConfiguring sweep...")
    set_sweep(sa, "sweep", 1001)  # 1001 points
    
    # Perform the measurement
    println("\nPerforming measurements...")
    println("- First sweep for trace 1 (normal)")
    write(sa.device, ":INIT:CONTinuous OFF")  # Single sweep mode
    write(sa.device, ":INIT")                # Trigger a sweep
    query(sa.device, "*OPC?")                # Wait for completion
    
    # Multiple sweeps for max hold trace
    println("- Multiple sweeps for trace 2 (max hold)")
    for i in 1:5
        println("  Sweep $i of 5")
        write(sa.device, ":INIT")
        query(sa.device, "*OPC?")
    end
    
    # Use markers to find peaks
    println("\nFinding peaks with markers...")
    # Set marker 1 to peak in trace 1
    write(sa.device, ":CALCulate:MARKer1:TRACe 1")
    write(sa.device, ":CALCulate:MARKer1:MAXimum")
    freq1, power1 = get_marker_data(sa, 1)
    
    # Set marker 2 to peak in trace 2 (max hold)
    set_marker(sa, 2, 0.0, 2)
    write(sa.device, ":CALCulate:MARKer2:MAXimum")
    freq2, power2 = get_marker_data(sa, 2)
    
    println("\nPeak Results:")
    println("  Trace 1 (normal): $(freq1/1e9) GHz at $(power1) dBm")
    println("  Trace 2 (max hold): $(freq2/1e9) GHz at $(power2) dBm")
    println("  Difference: $(power2 - power1) dB")
    
    # Save trace data to files
    println("\nSaving trace data...")
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    trace1_file = save_trace_data(sa, "trace1_$(timestamp).csv", 1)
    trace2_file = save_trace_data(sa, "trace2_maxhold_$(timestamp).csv", 2)
    
    # Try to plot if Plots is available
    try
        @eval import Plots
        
        println("\nPlotting trace data...")
        
        # Read the saved data for plotting
        function read_trace_file(filename)
            lines = readlines(filename)
            # Skip header lines starting with #
            data_start = findfirst(line -> !startswith(line, "#"), lines)
            header = lines[data_start]
            data_lines = lines[(data_start+1):end]
            
            # Parse the data
            freq = Float64[]
            power = Float64[]
            for line in data_lines
                if !isempty(line)
                    parts = split(line, ",")
                    push!(freq, parse(Float64, parts[1]))
                    push!(power, parse(Float64, parts[2]))
                end
            end
            return freq, power
        end
        
        # Read and plot both traces
        freq1, power1 = read_trace_file(trace1_file)
        freq2, power2 = read_trace_file(trace2_file)
        
        plot = Plots.plot(freq1, power1, 
            label="Normal Trace", 
            xlabel="Frequency (GHz)", 
            ylabel="Power (dBm)",
            title="Spectrum Analysis: $(center_freq) GHz ± $(span/2) MHz",
            linewidth=2,
            legend=:topright)
        
        Plots.plot!(freq2, power2, 
            label="Max Hold Trace", 
            linewidth=2, 
            linestyle=:dash)
        
        plot_file = "spectrum_comparison_$(timestamp).png"
        Plots.savefig(plot_file)
        println("Plot saved to: $plot_file")
    catch e
        println("\nSkipping plot generation: $(e)")
        println("To generate plots, install the Plots package with:")
        println("    using Pkg; Pkg.add(\"Plots\")")
    end
    
    # Reset to default settings before closing
    println("\nResetting analyzer to default settings...")
    reset(sa)
    
    # Close the connection
    println("\nClosing connection...")
    close(sa)
    
    println("\nAdvanced example completed successfully!")
end

# Run the example if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    try
        run_advanced_example()
    catch e
        println("Error running example: $e")
        println(e)
    end
end
