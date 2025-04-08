#
# signal_monitoring.jl - Example of signal monitoring with Ceyear_4051B
#
# This example demonstrates how to monitor signal power over time
# using the Ceyear_4051B package.

using Ceyear_4051B
using Dates

"""
    run_monitoring_example()

Demonstrates monitoring signal power over time with timestamp logging.
"""
function run_monitoring_example()
    println("CEYEAR 4051B Signal Monitor Example")
    println("==================================")
    
    # Connect to the spectrum analyzer
    println("\nConnecting to spectrum analyzer...")
    sa = SpectrumAnalyzer()
    
    # Configure the analyzer for monitoring
    println("\nConfiguring analyzer for monitoring...")
    freq = 2.4  # 2.4 GHz for WiFi
    set_freq(sa, freq, 0)  # Set minimal span for faster readings
    set_unit(sa, "dBm")
    
    # Monitor for a period of time
    println("\nMonitoring signal at $(freq) GHz for 10 seconds...")
    println("Timestamp,Power (dBm)")
    
    # Open a file for logging
    log_file = "signal_power_log_$(Dates.format(now(), "yyyymmdd_HHMMSS")).csv"
    open(log_file, "w") do file
        write(file, "Timestamp,Power (dBm)\n")
        
        start_time = now()
        while (now() - start_time) < Millisecond(10000)  # 10 seconds
            result = shot(sa, 1)
            timestamp = Dates.format(now(), "HH:MM:SS.sss")
            
            # Print to console
            println("$timestamp,$(result[1])")
            
            # Write to log file
            write(file, "$timestamp,$(result[1])\n")
            
            sleep(0.5)  # Take a reading every 500ms
        end
    end
    
    # Close the connection
    println("\nClosing connection...")
    close(sa)
    
    println("\nMonitoring completed!")
    println("Data logged to: $log_file")
end

# Run the example if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    try
        run_monitoring_example()
    catch e
        println("Error running example: $e")
    end
end
