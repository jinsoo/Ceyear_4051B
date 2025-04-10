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
       check_error, set_reference_level, set_attenuation,
       set_detector, set_trace_mode, set_bandwidth,
       get_marker_data, set_marker, save_trace_data

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
    reference_level::Float64
    attenuation::Int
    rbw::Float64
    vbw::Float64
    detector_type::String
    trace_mode::String
    
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
        analyzer = new(device, interface, 0.0, 0.0, 1001, 0.0, 0, 0.0, 0.0, "NORMAL", "WRITE")
        
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
    GPIB_rp5.write(analyzer.device, "*RST")
    sleep(0.5)  # Add a small delay to let the device reset
end

"""
    clear(analyzer)

Clear the device status and error queue.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
"""
function clear(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, "*CLS")
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
    GPIB_rp5.write(analyzer.device, ":FREQUENCY:CENTER $(center_freq) GHz")
    GPIB_rp5.write(analyzer.device, ":FREQUENCY:SPAN $(span_freq) MHz")
    
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
    GPIB_rp5.write(analyzer.device, ":SWEep:TYPE $(sweep_type)")
    GPIB_rp5.write(analyzer.device, ":SWEep:POINts $(points)")
    
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
        GPIB_rp5.write(analyzer.device, ":UNIT:POWER $(unit)")
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
        GPIB_rp5.write(analyzer.device, ":FORMAT:TRACE $(data_type)")
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
    GPIB_rp5.write(analyzer.device, ":TRACE:PRESET:ALL")
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
        GPIB_rp5.write(analyzer.device, ":TRIGger:SOURce $(trigger)")
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
    GPIB_rp5.write(analyzer.device, "*SRE 32")
    GPIB_rp5.write(analyzer.device, "*ESE 1")
    
    # Perform the measurement
    GPIB_rp5.write(analyzer.device, ":INIT")
    GPIB_rp5.query(analyzer.device, "*OPC?")
    
    # Read the results
    # Note: This implementation is simplified and may need adaptation
    # depending on the data format set with set_format()
    response = GPIB_rp5.query(analyzer.device, ":TRACE:DATA? TRACE1")
    
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
        GPIB_rp5.write(analyzer.device, "*CLS")
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
    GPIB_rp5.write(analyzer.device, ":CALC:MARKER:X:POSITION $(measurement_freq)")
    
    # Take n measurements
    for i in 1:n
        # Trigger a measurement
        GPIB_rp5.write(analyzer.device, "*TRG")
        
        # Read the marker value
        response = GPIB_rp5.query(analyzer.device, ":CALC:MARK:Y?")
        
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

"""
    set_reference_level(analyzer, level)

Set the reference level of the spectrum analyzer.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `level::Real`: Reference level in dBm

# Example
```julia
# Set reference level to 0 dBm
set_reference_level(sa, 0)
```
"""
function set_reference_level(analyzer::SpectrumAnalyzer, level::Real)
    analyzer.reference_level = Float64(level)
    GPIB_rp5.write(analyzer.device, ":DISPlay:WINDow:TRACe:Y:RLEVel $(level) dBm")
    check_error(analyzer)
end

"""
    set_attenuation(analyzer, attenuation, auto=false)

Set the RF input attenuation.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `attenuation::Integer`: Attenuation value in dB (typically 0-70)
- `auto::Bool=false`: Set to true for automatic attenuation

# Example
```julia
# Set 20 dB attenuation
set_attenuation(sa, 20)

# Or enable automatic attenuation
set_attenuation(sa, 0, true)
```
"""
function set_attenuation(analyzer::SpectrumAnalyzer, attenuation::Integer, auto::Bool=false)
    if auto
        GPIB_rp5.write(analyzer.device, ":SENSe:POWer:RF:ATTenuation:AUTO ON")
    else
        analyzer.attenuation = attenuation
        GPIB_rp5.write(analyzer.device, ":SENSe:POWer:RF:ATTenuation $(attenuation) dB")
        GPIB_rp5.write(analyzer.device, ":SENSe:POWer:RF:ATTenuation:AUTO OFF")
    end
    check_error(analyzer)
end

"""
    set_detector(analyzer, detector_type="NORMAL")

Set the detector type for the active trace.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `detector_type::String="NORMAL"`: Detector type, can be one of:
  - "NORMAL": Normal detector (default)
  - "POSitive": Positive peak detector
  - "NEGative": Negative peak detector
  - "SAMPle": Sample detector
  - "AVERage": Average detector
  - "RMS": RMS detector

# Example
```julia
# Set to RMS detector
set_detector(sa, "RMS")
```
"""
function set_detector(analyzer::SpectrumAnalyzer, detector_type::String="NORMAL")
    # List of valid detector types
    valid_detectors = ["NORMAL", "POSitive", "NEGative", "SAMPle", "AVERage", "RMS"]
    
    # Check if detector type is valid (case-insensitive)
    if any(uppercase(detector_type) == uppercase(d) for d in valid_detectors)
        analyzer.detector_type = uppercase(detector_type)
        GPIB_rp5.write(analyzer.device, ":DETector:TRACe1 $(detector_type)")
    else
        @error "Invalid detector type: $(detector_type). Must be one of: $(join(valid_detectors, ", "))"
    end
    
    check_error(analyzer)
end

"""
    set_trace_mode(analyzer, mode="WRITE", trace_num=1)

Set the trace mode for the specified trace.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `mode::String="WRITE"`: Trace mode, can be one of:
  - "WRITE": Clear and write mode (default)
  - "MAXHold": Maximum hold mode
  - "MINHold": Minimum hold mode
  - "VIEW": View mode (freezes the trace)
  - "BLANk": Blank mode (hides the trace)
  - "AVERage": Average mode
- `trace_num::Integer=1`: Trace number (1-6)

# Example
```julia
# Set trace 1 to max hold mode
set_trace_mode(sa, "MAXHold")

# Set trace 2 to average mode
set_trace_mode(sa, "AVERage", 2)
```
"""
function set_trace_mode(analyzer::SpectrumAnalyzer, mode::String="WRITE", trace_num::Integer=1)
    # List of valid trace modes
    valid_modes = ["WRITE", "MAXHold", "MINHold", "VIEW", "BLANk", "AVERage"]
    
    # Validate trace number
    if trace_num < 1 || trace_num > 6
        @error "Invalid trace number: $(trace_num). Must be between 1 and 6."
        return
    end
    
    # Check if mode is valid (case-insensitive)
    if any(uppercase(mode) == uppercase(m) for m in valid_modes)
        if trace_num == 1
            analyzer.trace_mode = uppercase(mode)
        end
        GPIB_rp5.write(analyzer.device, ":TRACe$(trace_num):MODE $(mode)")
    else
        @error "Invalid trace mode: $(mode). Must be one of: $(join(valid_modes, ", "))"
    end
    
    check_error(analyzer)
end

"""
    set_bandwidth(analyzer, rbw=0.0, vbw=0.0, auto=true)

Set the resolution bandwidth (RBW) and video bandwidth (VBW).

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `rbw::Real=0.0`: Resolution bandwidth in Hz (0.0 for auto)
- `vbw::Real=0.0`: Video bandwidth in Hz (0.0 for auto)
- `auto::Bool=true`: Whether to use automatic bandwidth settings

# Example
```julia
# Set RBW to 100 kHz and VBW to 10 kHz
set_bandwidth(sa, 100e3, 10e3, false)

# Use automatic bandwidth settings
set_bandwidth(sa)
```
"""
function set_bandwidth(analyzer::SpectrumAnalyzer, rbw::Real=0.0, vbw::Real=0.0, auto::Bool=true)
    if auto
        GPIB_rp5.write(analyzer.device, ":BANDwidth:RESolution:AUTO ON")
        GPIB_rp5.write(analyzer.device, ":BANDwidth:VIDeo:AUTO ON")
        
        # Read current values to update the struct
        response = GPIB_rp5.query(analyzer.device, ":BANDwidth:RESolution?")
        analyzer.rbw = parse(Float64, response)
        
        response = GPIB_rp5.query(analyzer.device, ":BANDwidth:VIDeo?")
        analyzer.vbw = parse(Float64, response)
    else
        if rbw > 0.0
            analyzer.rbw = rbw
            GPIB_rp5.write(analyzer.device, ":BANDwidth:RESolution $(rbw) Hz")
            GPIB_rp5.write(analyzer.device, ":BANDwidth:RESolution:AUTO OFF")
        end
        
        if vbw > 0.0
            analyzer.vbw = vbw
            GPIB_rp5.write(analyzer.device, ":BANDwidth:VIDeo $(vbw) Hz")
            GPIB_rp5.write(analyzer.device, ":BANDwidth:VIDeo:AUTO OFF")
        end
    end
    
    check_error(analyzer)
end

"""
    set_marker(analyzer, marker_num=1, freq=0.0, trace_num=1)

Create or move a marker to a specific frequency.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `marker_num::Integer=1`: Marker number (1-12)
- `freq::Real=0.0`: Frequency in GHz (0.0 for current center frequency)
- `trace_num::Integer=1`: Trace number to place the marker on (1-6)

# Example
```julia
# Place marker 1 at 2.45 GHz on trace 1
set_marker(sa, 1, 2.45)
```
"""
function set_marker(analyzer::SpectrumAnalyzer, marker_num::Integer=1, freq::Real=0.0, trace_num::Integer=1)
    # Validate marker number
    if marker_num < 1 || marker_num > 12
        @error "Invalid marker number: $(marker_num). Must be between 1 and 12."
        return
    end
    
    # Validate trace number
    if trace_num < 1 || trace_num > 6
        @error "Invalid trace number: $(trace_num). Must be between 1 and 6."
        return
    end
    
    # Activate the marker
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):STATe ON")
    
    # Set the marker to normal mode (not delta)
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):MODE POSition")
    
    # Assign marker to the specified trace
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):TRACe $(trace_num)")
    
    # Position the marker
    if freq <= 0.0
        # Use center frequency if none specified
        GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):X:CENTer")
    else
        GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):X $(freq) GHz")
    end
    
    check_error(analyzer)
end

"""
    get_marker_data(analyzer, marker_num=1)

Get the frequency and amplitude data from a marker.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `marker_num::Integer=1`: Marker number (1-12)

# Returns
- `Tuple{Float64, Float64}`: Frequency (Hz) and amplitude values

# Example
```julia
# Get data from marker 1
freq, ampl = get_marker_data(sa)
printf("Signal at %.3f MHz: %.2f dBm", freq/1e6, ampl)
```
"""
function get_marker_data(analyzer::SpectrumAnalyzer, marker_num::Integer=1)
    # Validate marker number
    if marker_num < 1 || marker_num > 12
        @error "Invalid marker number: $(marker_num). Must be between 1 and 12."
        return (0.0, 0.0)
    end
    
    # Ensure the marker is on
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):STATe ON")
    
    # Get the X (frequency) value
    x_response = GPIB_rp5.query(analyzer.device, ":CALCulate:MARKer$(marker_num):X?")
    freq = parse(Float64, x_response)
    
    # Get the Y (amplitude) value
    y_response = GPIB_rp5.query(analyzer.device, ":CALCulate:MARKer$(marker_num):Y?")
    ampl = parse(Float64, y_response)
    
    return (freq, ampl)
end

"""
    save_trace_data(analyzer, filename, trace_num=1, include_header=true)

Save trace data to a CSV file.

# Arguments
- `analyzer::SpectrumAnalyzer`: The spectrum analyzer connection
- `filename::String`: File name to save data to
- `trace_num::Integer=1`: Trace number to save (1-6)
- `include_header::Bool=true`: Whether to include header information

# Example
```julia
# Save trace 1 data to file
save_trace_data(sa, "trace_data.csv")
```
"""
function save_trace_data(analyzer::SpectrumAnalyzer, filename::String, trace_num::Integer=1, include_header::Bool=true)
    # Validate trace number
    if trace_num < 1 || trace_num > 6
        @error "Invalid trace number: $(trace_num). Must be between 1 and 6."
        return
    end
    
    # Get trace data
    GPIB_rp5.write(analyzer.device, ":FORMat:TRACe:DATA ASCii")
    response = query(analyzer.device, ":TRACe:DATA? TRACE$(trace_num)")
    
    # Parse the trace data
    values = split(response, ",")
    y_data = [parse(Float64, v) for v in values]
    
    # Generate frequency points
    freq_start = analyzer.center_freq - analyzer.span_freq/2000  # GHz
    freq_stop = analyzer.center_freq + analyzer.span_freq/2000   # GHz
    x_data = range(freq_start, freq_stop, length=length(y_data))
    
    # Save to file
    open(filename, "w") do file
        # Write header information if requested
        if include_header
            write(file, "# Ceyear 4051B Spectrum Analyzer Trace Data\n")
            write(file, "# Date: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))\n")
            write(file, "# Center Frequency: $(analyzer.center_freq) GHz\n")
            write(file, "# Span: $(analyzer.span_freq) MHz\n")
            write(file, "# RBW: $(analyzer.rbw) Hz\n")
            write(file, "# VBW: $(analyzer.vbw) Hz\n")
            write(file, "# Reference Level: $(analyzer.reference_level) dBm\n")
            write(file, "# Detector: $(analyzer.detector_type)\n")
            write(file, "# Trace Mode: $(analyzer.trace_mode)\n")
            write(file, "# Points: $(analyzer.points)\n")
            write(file, "#\n")
        end
        
        # Write column headers
        write(file, "Frequency (GHz),Power (dBm)\n")
        
        # Write data
        for (freq, power) in zip(x_data, y_data)
            write(file, "$(freq),$(power)\n")
        end
    end
    
    println("Trace data saved to: $(filename)")
    return filename
end

end # module Ceyear4051B
