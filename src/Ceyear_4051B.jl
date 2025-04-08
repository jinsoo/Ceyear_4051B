"""
    Ceyear4051B

A Julia module for controlling CEYEAR 4051B spectrum analyzers via GPIB or LAN interfaces.
Provides a high-level interface for common spectrum analyzer operations.

# Author
- Original Python implementation: Unknown
- Julia adaptation: Taeho <virtalf@gmail.com>
"""
module Ceyear_4051B

# Export public API
export SpectrumAnalyzer, 
       check_identify, reset, clear,
       set_freq, set_sweep, set_unit, set_format,
       reset_trace, set_trigger, measure, shot,
       check_error

# We need the GPIB_rp5 package for communication
using GPIB_rp5

"""
    SpectrumAnalyzer

Type representing a connection to a CEYEAR 4051B spectrum analyzer.

# Fields
- `device::GPIBDevice`: The GPIB device connection
- `interface::String`: The interface string used for connection
- `center_freq::Float64`: Current center frequency in GHz (cached)
- `span_freq::Float64`: Current frequency span in MHz (cached)
- `points::Int`: Number of sweep points (cached)
"""
mutable struct SpectrumAnalyzer
    device::GPIBDevice
    interface::String
    center_freq::Float64
    span_freq::Float64
    points::Int
    
    """
        SpectrumAnalyzer(interface="GPIB0::18")
    
    Create a new connection to a CEYEAR 4051B spectrum analyzer.
    
    # Arguments
    - `interface::String="GPIB0::18"`: GPIB interface string, usually in the format 
      "GPIBx::address" for GPIB or "TCPIP0::ip_address::5025::SOCKET" for LAN
    
    # Returns
    - A new `SpectrumAnalyzer` instance
    
    # Example
    ```julia
    # Connect to a spectrum analyzer at GPIB address 18
    sa = SpectrumAnalyzer()
    
    # Or with a specific interface
    sa = SpectrumAnalyzer("GPIB0::20")
    
    # Or via LAN
    sa = SpectrumAnalyzer("TCPIP0::192.168.2.2::5025::SOCKET")
    ```
    """
    function SpectrumAnalyzer(interface::String="GPIB0::18")
        # Extract board and address from GPIB interface string
        if startswith(interface, "GPIB")
            parts = split(interface, "::")
            board_index = parse(Int, replace(parts[1], "GPIB" => ""))
            address = parse(Int, parts[2])
            
            # Connect to the device
            device = open_device(board_index, address)
            println("Connecting to GPIB device at address $address on board $board_index")
        else
            error("Only GPIB interfaces are currently supported")
        end
        
        # Create a new analyzer instance
        analyzer = new(device, interface, 0.0, 0.0, 1001)
        
        # Initialize the device
        identify_string = check_identify(analyzer)
        println("Connected to: $identify_string")
        
        # Reset and clear the device
        reset(analyzer)
        clear(analyzer)
        
        return analyzer
    end
end

"""
    check_identify(analyzer)

Query the device identification information.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection

# Returns
- `String`: The device identification string

# Example
```julia
sa = SpectrumAnalyzer()
idn = check_identify(sa)
println("Connected to: \$idn")
```
"""
function check_identify(analyzer::SpectrumAnalyzer)
    idn = query(analyzer.device, "*IDN?")
    idn_parts = split(idn, ",")
    
    if contains(idn_parts[1], "Ceyear")
        println("Spectrum Analyzer $(idn_parts[2]) is connected.")
        return idn
    else
        @warn "Connected device may not be a CEYEAR instrument: $idn"
        return idn
    end
end

"""
    reset(analyzer)

Reset the device to its default state.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
"""
function reset(analyzer::SpectrumAnalyzer)
    write(analyzer.device, "*RST")
    sleep(0.5)  # Add a small delay to let the device reset
end

"""
    clear(analyzer)

Clear the device status and error queue.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
"""
function clear(analyzer::SpectrumAnalyzer)
    write(analyzer.device, "*CLS")
end

"""
    set_freq(analyzer, center_freq, span_freq=500)

Set the frequency parameters of the spectrum analyzer.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `center_freq::Real`: Center frequency in GHz
- `span_freq::Real=500`: Frequency span in MHz

# Example
```julia
# Set center frequency to 2.4 GHz with a 100 MHz span
set_freq(sa, 2.4, 100)
```
"""
function set_freq(analyzer::SpectrumAnalyzer, center_freq::Real, span_freq::Real=500)
    # Update cached values
    analyzer.center_freq = Float64(center_freq)
    analyzer.span_freq = Float64(span_freq)
    
    # Set center frequency and span
    write(analyzer.device, ":FREQUENCY:CENTER $(center_freq) GHz")
    write(analyzer.device, ":FREQUENCY:SPAN $(span_freq) MHz")
    
    # Check for errors
    check_error(analyzer)
end

"""
    set_sweep(analyzer, sweep_type="sweep", points=1001)

Configure the sweep parameters.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `sweep_type::String="sweep"`: Type of sweep to perform
- `points::Integer=1001`: Number of points in the sweep

# Example
```julia
# Set a sweep with 2001 points
set_sweep(sa, "sweep", 2001)
```
"""
function set_sweep(analyzer::SpectrumAnalyzer, sweep_type::String="sweep", points::Integer=1001)
    # Update cached values
    analyzer.points = points
    
    # Set sweep type and number of points
    write(analyzer.device, ":SWEep:TYPE $(sweep_type)")
    write(analyzer.device, ":SWEep:POINts $(points)")
    
    # Check for errors
    check_error(analyzer)
end

"""
    set_unit(analyzer, unit="dBm")

Set the power unit for measurements.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `unit::String="dBm"`: Power unit, can be one of: 
  - "DBM" (dBm, power relative to 1 mW)
  - "DBMV" (dB millivolts)
  - "DBMA" (dB milliamps)
  - "V" (volts)
  - "W" (watts)
  - "A" (amps)
  - "DBUV" (dB microvolts)
  - "DBUA" (dB microamps)
  - "DBUVM" (dB microvolt/meter)
  - "DBUAM" (dB microamp/meter)
  - "DBPT" (dB pascals)
  - "DBG" (dB gauss)

# Example
```julia
# Set to display results in volts
set_unit(sa, "V")
```
"""
function set_unit(analyzer::SpectrumAnalyzer, unit::String="dBm")
    # List of valid units
    valid_units = ["DBM", "DBMV", "DBMA", "V", "W", "A", "DBUV", 
                   "DBUA", "DBUVM", "DBUAM", "DBPT", "DBG"]
    
    # Check if unit is valid (case-insensitive)
    if any(uppercase(unit) == uppercase(u) for u in valid_units)
        write(analyzer.device, ":UNIT:POWER $(unit)")
    else
        @error "Invalid unit: $(unit). Must be one of: $(join(valid_units, ", "))"
    end
    
    # Check for errors
    check_error(analyzer)
end

"""
    set_format(analyzer, data_type="ASCii")

Set the data format for trace data.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `data_type::String="ASCii"`: Data format, can be one of:
  - "ASCii" (ASCII text)
  - "INTeger32" (32-bit integers)
  - "REAL32" (32-bit floats)
  - "REAL64" (64-bit floats)

# Example
```julia
# Set to receive data as 32-bit floats
set_format(sa, "REAL32")
```
"""
function set_format(analyzer::SpectrumAnalyzer, data_type::String="ASCii")
    # List of valid data formats
    valid_formats = ["ASCii", "INTeger32", "REAL32", "REAL64"]
    
    # Check if format is valid (case-insensitive)
    if any(uppercase(data_type) == uppercase(f) for f in valid_formats)
        write(analyzer.device, ":FORMAT:TRACE $(data_type)")
    else
        @error "Invalid format: $(data_type). Must be one of: $(join(valid_formats, ", "))"
    end
    
    # Check for errors
    check_error(analyzer)
end

"""
    reset_trace(analyzer)

Reset all trace data.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
"""
function reset_trace(analyzer::SpectrumAnalyzer)
    write(analyzer.device, ":TRACE:PRESET:ALL")
    check_error(analyzer)
end

"""
    set_trigger(analyzer, trigger="IMMediate")

Set the trigger source.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `trigger::String="IMMediate"`: Trigger source, can be one of:
  - "IMMediate" (immediate triggering)
  - "EXTernal1" (external trigger 1)
  - "EXTernal2" (external trigger 2)
  - "LINE" (line trigger)
  - "FRAMe" (frame trigger)
  - "RFBurst" (RF burst trigger)
  - "VIDeo" (video trigger)
  - And others: "IF", "ALARm", "LAN", "IQMag", "IDEMod", "QDEMod", "IINPut", "QINPut", "AIQMag"

# Example
```julia
# Set to video triggering
set_trigger(sa, "VIDeo")
```
"""
function set_trigger(analyzer::SpectrumAnalyzer, trigger::String="IMMediate")
    # List of valid trigger sources
    valid_triggers = ["EXTernal1", "EXTernal2", "IMMediate", "LINE", "FRAMe", 
                      "RFBurst", "VIDeo", "IF", "ALARm", "LAN", "IQMag", 
                      "IDEMod", "QDEMod", "IINPut", "QINPut", "AIQMag"]
    
    # Check if trigger is valid (case-insensitive)
    if any(uppercase(trigger) == uppercase(t) for t in valid_triggers)
        write(analyzer.device, ":TRIGger:SOURce $(trigger)")
    else
        @error "Invalid trigger: $(trigger). Must be one of: $(join(valid_triggers, ", "))"
    end
    
    # Check for errors
    check_error(analyzer)
end

"""
    measure(analyzer)

Perform a measurement and print the results.
This is a basic implementation and may need to be adapted based on
specific needs and data formats.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection

# Returns
- `Vector{Float64}`: Array of measurement results

# Note
This function requires further adaptation for binary data formats.
"""
function measure(analyzer::SpectrumAnalyzer)
    # Set up for measurement
    write(analyzer.device, "*SRE 32")
    write(analyzer.device, "*ESE 1")
    
    # Perform the measurement
    write(analyzer.device, ":INIT")
    query(analyzer.device, "*OPC?")
    
    # Read the results
    # Note: This implementation is simplified and may need adaptation
    # depending on the data format set with set_format()
    response = query(analyzer.device, ":TRACE:DATA? TRACE1")
    
    # For ASCII format, split the comma-separated values
    values = split(response, ",")
    
    # Convert to floating-point numbers
    data = [parse(Float64, v) for v in values]
    
    # Print the data
    for d in data
        println(d)
    end
    
    return data
end

"""
    check_error(analyzer)

Check for and print any errors from the device.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection

# Returns
- `Bool`: true if there was an error, false otherwise
"""
function check_error(analyzer::SpectrumAnalyzer)
    error_msg = query(analyzer.device, ":SYST:ERR?")
    
    if !contains(error_msg, "+0")
        println("Error: $error_msg")
        # Clear the error queue
        write(analyzer.device, "*CLS")
        return true
    end
    
    return false
end

"""
    shot(analyzer, n=10, freq=0.0)

Take multiple readings at a specific frequency.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `n::Integer=10`: Number of readings to take
- `freq::Real=0.0`: Frequency in GHz (defaults to current center frequency if 0.0)

# Returns
- `Vector{Float64}`: Array of measurement results

# Example
```julia
# Take 5 measurements at the current center frequency
results = shot(sa, 5)

# Take 20 measurements at 5.8 GHz
results = shot(sa, 20, 5.8)
```
"""
function shot(analyzer::SpectrumAnalyzer, n::Integer=10, freq::Real=0.0)
    # Use the specified frequency or the current center frequency if not provided
    measurement_freq = freq == 0.0 ? analyzer.center_freq : Float64(freq)
    
    # Preallocate array for results
    data = zeros(Float64, n)
    
    # Position the marker at the specified frequency
    write(analyzer.device, ":CALC:MARKER:X:POSITION $(measurement_freq)")
    
    # Take n measurements
    for i in 1:n
        # Trigger a measurement
        write(analyzer.device, "*TRG")
        
        # Read the marker value
        response = query(analyzer.device, ":CALC:MARK:Y?")
        
        # Remove trailing newline and convert to float
        data[i] = parse(Float64, rstrip(response))
    end
    
    # Check for errors
    check_error(analyzer)
    
    return data
end

"""
    close(analyzer)

Close the connection to the spectrum analyzer.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection to close
"""
function Base.close(analyzer::SpectrumAnalyzer)
    close_device(analyzer.device)
    println("Connection to spectrum analyzer closed.")
end

end # module Ceyear4051B
