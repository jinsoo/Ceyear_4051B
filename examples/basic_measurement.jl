#!/usr/bin/env julia
#
# basic_measurement.jl - Example usage of the Ceyear_4051B package
#
# This example demonstrates basic usage of the Ceyear_4051B module to connect to a 
# spectrum analyzer, configure settings, and take measurements.

using Ceyear_4051B
using Statistics
using Dates

"""
    run_basic_example()

Demonstrates basic usage of the Ceyear_4051B module.
"""
function run_basic_example()
    println("CEYEAR 4051B Spectrum Analyzer Example")
    println("======================================")
    
    # Connect to the spectrum analyzer
    println("\nConnecting to spectrum analyzer...")
    sa = SpectrumAnalyzer()
    
    # Configure the analyzer
    println("\nConfiguring analyzer...")
    set_freq(sa, 2.4, 100)  # 2.4 GHz center with 100 MHz span
    set_unit(sa, "dBm")     # Set power unit to dBm
    set_trigger(sa, "IMMediate")  # Immediate triggering
    
    # Take multiple measurements
    println("\nTaking measurements...")
    num_measurements = 10
    results = shot(sa, num_measurements)
    
    # Analyze and print results
    println("\nMeasurement Results (dBm):")
    for (i, power) in enumerate(results)
        println("  Measurement $i: $power dBm")
    end
    
    # Calculate statistics
    mean_power = mean(results)
    std_dev = std(results)
    min_power = minimum(results)
    max_power = maximum(results)
    
    println("\nStatistics:")
    println("  Mean Power: $mean_power dBm")
    println("  Standard Deviation: $std_dev dB")
    println("  Minimum Power: $min_power dBm")
    println("  Maximum Power: $max_power dBm")
    println("  Range: $(max_power - min_power) dB")
    
    # Close the connection
    println("\nClosing connection...")
    close(sa)
    
    println("\nExample completed successfully!")
end

# Run the example if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    try
        run_basic_example()
    catch e
        println("Error running example: $e")
    end
end
