"""
    Ceyear4051B

A Julia module for controlling CEYEAR 4051B spectrum analyzers via GPIB or LAN interfaces.
Provides a high-level interface for common spectrum analyzer operations.

# Author
- Original Python implementation: Unknown
- Julia adaptation: Taeho <virtalf@gmail.com>
"""
module Ceyear_4051B

# We need the GPIB_rp5 package for communication
using GPIB_rp5
using Base.write

# Export the main struct
export SpectrumAnalyzer

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

# Include the SPI commands (now just a file with functions)
include("SPI_commands.jl")

# Export all functions from SPI_commands
export check_identify, reset, clear,
       set_freq, set_sweep, set_unit, set_format,
       reset_trace, set_trigger, measure, shot,
       check_error, set_reference_level, set_attenuation,
       set_detector, set_trace_mode, set_bandwidth,
       get_marker_data, set_marker, save_trace_data,
       # New functions
       set_freq_start_stop, set_freq_step, set_freq_offset,
       set_elec_attenuation, set_mixer_range, set_preamp, set_scale_div,
       set_sweep_time, set_sweep_mode, set_gated_sweep,
       set_trigger_delay, set_trigger_level, set_trigger_slope,
       set_marker_delta, marker_peak_search, marker_to_center, marker_to_ref,
       measure_channel_power, measure_obw, measure_acp, measure_harmonics, measure_toi,
       set_rosc_source, system_preset_user, set_gpib_address, set_display_enable

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

end
