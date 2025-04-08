# Ceyear_4051B

A Julia package for controlling CEYEAR 4051B spectrum analyzers via GPIB or other interfaces. It's designed to simplify common spectrum analyzer operations for test automation, measurement scripts, and interactive use.

## Features

- Connect to CEYEAR 4051B spectrum analyzers via GPIB
- Configure frequency settings (center frequency, span)
- Set measurement units and data formats
- Control sweep parameters and triggering
- Take spot measurements or continuous sweeps
- Advanced marker functionality for peak detection and measurements
- Configurable detector types and trace modes
- Bandwidth control (RBW and VBW settings)
- Reference level and attenuation management
- Multiple trace management (up to 6 traces)
- Trace data export to CSV with metadata
- Full error handling and status reporting
- Simple API with detailed documentation

## Prerequisites

- Julia 1.6 or higher
- GPIB_rp5 package (for GPIB communication)
- CEYEAR 4051B spectrum analyzer
- GPIB hardware interface (such as a GPIB controller card or USB-GPIB adapter)

## Installation

1. Ensure you have the `GPIB_rp5` package installed and properly configured:

   ```julia
   using Pkg
   Pkg.add(url="https://github.com/jinsoo/GPIB_rp5")
   ```

2. Install the Ceyear_4051B package:

   ```julia
   using Pkg
   Pkg.add(url="https://github.com/jinsoo/Ceyear_4051B")
   ```

## Quick Start

```julia
using Ceyear_4051B

# Connect to the spectrum analyzer (default: GPIB address 18)
sa = SpectrumAnalyzer()

# Or with a specific GPIB address
# sa = SpectrumAnalyzer("GPIB0::20")

# Set center frequency (2.4 GHz) and span (100 MHz)
set_freq(sa, 2.4, 100)

# Set to immediate triggering
set_trigger(sa, "IMMediate")

# Take 10 measurements at the center frequency
results = shot(sa, 10)
println("Measurement results: $results")

# Calculate mean and standard deviation
using Statistics
mean_power = mean(results)
std_dev = std(results)
println("Mean power: $(mean_power) dBm, Standard deviation: $(std_dev) dB")

# Close the connection when done
close(sa)
```

## Detailed API

### Connection Management

- `SpectrumAnalyzer(interface="GPIB0::18")`: Create a new connection to the analyzer
- `close(analyzer)`: Close the connection
- `check_identify(analyzer)`: Query and verify device identification
- `reset(analyzer)`: Reset the device to default settings
- `clear(analyzer)`: Clear the device status and error queues

### Configuration

- `set_freq(analyzer, center_freq, span_freq=500)`: Set center frequency (GHz) and span (MHz)
- `set_sweep(analyzer, sweep_type="sweep", points=1001)`: Configure sweep parameters
- `set_unit(analyzer, unit="dBm")`: Set the power unit (dBm, V, W, etc.)
- `set_format(analyzer, data_type="ASCii")`: Set data format for readings
- `set_trigger(analyzer, trigger="IMMediate")`: Set trigger source
- `reset_trace(analyzer)`: Reset all trace data
- `set_reference_level(analyzer, level)`: Set the reference level in dBm
- `set_attenuation(analyzer, attenuation, auto=false)`: Set RF input attenuation
- `set_detector(analyzer, detector_type="NORMAL")`: Set the detector type
- `set_trace_mode(analyzer, mode="WRITE", trace_num=1)`: Set the trace mode
- `set_bandwidth(analyzer, rbw=0.0, vbw=0.0, auto=true)`: Set RBW and VBW

### Measurement and Markers

- `measure(analyzer)`: Perform a measurement and return the trace data
- `shot(analyzer, n=10, freq=0.0)`: Take multiple readings at a specific frequency
- `set_marker(analyzer, marker_num=1, freq=0.0, trace_num=1)`: Create/position a marker
- `get_marker_data(analyzer, marker_num=1)`: Get frequency and amplitude from a marker
- `save_trace_data(analyzer, filename, trace_num=1, include_header=true)`: Save trace data to CSV
- `check_error(analyzer)`: Check for and report any errors

## Supported Units

The spectrum analyzer supports various measurement units that can be set with `set_unit()`:

| Unit   | Description                 | Used For                          |
|--------|-----------------------------|-----------------------------------|
| "DBM"  | dBm (power relative to 1mW) | Absolute power measurements       |
| "DBMV" | dB millivolts               | Voltage measurements              |
| "DBMA" | dB milliamps                | Current measurements              |
| "V"    | Volts                       | Linear voltage                    |
| "W"    | Watts                       | Linear power                      |
| "A"    | Amps                        | Linear current                    |
| "DBUV" | dB microvolts               | EMC/EMI measurements              |
| "DBUA" | dB microamps                | Current-based measurements        |
| "DBUVM"| dB microvolt/meter          | Field strength measurements       |
| "DBUAM"| dB microamp/meter           | Magnetic field measurements       |
| "DBPT" | dB pascals                  | Acoustic measurements             |
| "DBG"  | dB gauss                    | Magnetic field strength           |

## Trigger Sources

The available trigger sources that can be set with `set_trigger()` include:

- "IMMediate": Continuous triggering (default)
- "EXTernal1"/"EXTernal2": External trigger inputs
- "VIDeo": Video (amplitude) triggering
- "RFBurst": RF burst detection
- "LINE": Power line synchronization
- Additional specialized triggers: "IF", "FRAMe", "IQMag", etc.

## Data Formats

The `set_format()` function sets the format for returned data:

- "ASCii": Human-readable text format (default)
- "INTeger32": 32-bit integer format
- "REAL32": 32-bit floating point (single precision)
- "REAL64": 64-bit floating point (double precision)

## Examples

See the `examples/` directory for working code examples:

- `basic_measurement.jl`: Simple connection and measurement
- `frequency_sweep.jl`: Performing and saving frequency sweeps
- `signal_monitoring.jl`: Monitoring a signal over time
- `advanced_features.jl`: Using markers, multiple traces, and advanced features

## Troubleshooting

### Common Issues

1. **Connection Errors**: Ensure the GPIB address matches your device settings.

2. **Timeout Errors**: Some operations may take longer to complete. If you see timeout errors, consider:
   - Increasing the GPIB timeout value
   - Adding small delays between commands with `sleep()`

3. **Data Format Issues**: If you get invalid data in `measure()`, make sure you're using the right format:
   - For binary formats, the data handling needs to match the `set_format()` setting
   - The default implementation works best with "ASCii" format

4. **Trigger Problems**: If measurements aren't triggering properly:
   - Ensure the trigger source is set appropriately for your setup
   - For external triggers, check that the signal meets the trigger requirements

## About CEYEAR 4051B

The CEYEAR 4051B is a high-performance spectrum analyzer with features including:

- Frequency range: 9 kHz to 18/26.5/45/67 GHz
- Minimum resolution bandwidth (RBW): 1 Hz
- Phase noise: -110 dBc/Hz @ 1 GHz, 10 kHz offset
- Displayed average noise level (DANL): -156 dBm/Hz
- Full GPIB, LAN, and USB control interfaces
- Multiple measurement modes

## License

This code is provided under the MIT License. Feel free to use and modify it for your projects.
