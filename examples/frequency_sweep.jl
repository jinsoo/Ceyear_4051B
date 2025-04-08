#
# frequency_sweep.jl - Example of performing frequency sweeps with Ceyear_4051B
#
# This example demonstrates how to perform a frequency sweep and save the data,
# optionally plotting it if the Plots package is available.

using Ceyear_4051B
using Dates
import REPL  # Used to check if Plots is available without requiring it

"""
    run_sweep_example()

Demonstrates performing a frequency sweep and saving the data.
"""
function run_sweep_example()
    println("CEYEAR 4051B Frequency Sweep Example")
    println("===================================")
    
    # Connect to the spectrum analyzer
    println("\nConnecting to spectrum analyzer...")
    sa = SpectrumAnalyzer()
    
    # Configure for a frequency sweep
    println("\nConfiguring analyzer for sweep...")
    center_freq = 2.4  # 2.4 GHz (for example, WiFi band)
    span = 200  # 200 MHz span
    points = 401  # Number of points in the sweep
    
    set_freq(sa, center_freq, span)
    set_sweep(sa, "sweep", points)
    set_unit(sa, "dBm")
    set_format(sa, "ASCii")  # Ensure we're using ASCII format
    
    # Calculate frequency range for later use
    freq_start = center_freq - span/2000  # GHz
    freq_stop = center_freq + span/2000   # GHz
    
    # Perform the sweep
    println("\nPerforming frequency sweep from $(freq_start) GHz to $(freq_stop) GHz...")
    sweep_data = measure(sa)
    
    # Generate frequency points
    freq_points = range(freq_start, freq_stop, length=length(sweep_data))
    
    # Save data to CSV
    filename = "sweep_$(center_freq)GHz_$(Dates.format(now(), "yyyymmdd_HHMMSS")).csv"
    println("\nSaving sweep data to $filename...")
    
    open(filename, "w") do file
        write(file, "Frequency (GHz),Power (dBm)\n")
        for (freq, power) in zip(freq_points, sweep_data)
            write(file, "$(freq),$(power)\n")
        end
    end
    
    # Try to plot the data if Plots package is available
    try
        # Check if Plots is available
        @eval import Plots
        
        println("\nPlotting sweep data...")
        Plots.plot(freq_points, sweep_data,
             xlabel="Frequency (GHz)", 
             ylabel="Power (dBm)",
             title="Frequency Sweep: $center_freq GHz ± $(span/2) MHz",
             legend=false)
        
        plot_filename = "sweep_plot_$(center_freq)GHz.png"
        Plots.savefig(plot_filename)
        println("Plot saved to $plot_filename")
    catch e
        println("\nSkipping plot generation: Plots package not available")
        println("To generate plots, install the Plots package with:")
        println("    using Pkg; Pkg.add(\"Plots\")")
    end
    
    # Close the connection
    println("\nClosing connection...")
    close(sa)
    
    println("\nSweep completed successfully!")
    println("Data saved to: $filename")
end

# Run the example if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    try
        run_sweep_example()
    catch e
        println("Error running example: $e")
        println(e)
    end
end
