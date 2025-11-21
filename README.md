# Ceyear 4051B Spectrum Analyzer Control

A Julia package for controlling CEYEAR 4051B spectrum analyzers via GPIB.

## Overview

This package provides a high-level interface for automating measurements with the Ceyear 4051B Spectrum Analyzer. It handles the low-level SCPI commands and provides convenient Julia functions for common operations.

## Features

### Basic Operations
- **Connection**: Connect via GPIB (`SpectrumAnalyzer`)
- **Identification**: Check device ID (`check_identify`)
- **Reset/Clear**: Reset device state (`reset`, `clear`)
- **Errors**: Check system errors (`check_error`)

### Frequency & Sweep
- **Frequency**: Set center/span (`set_freq`) or start/stop (`set_freq_start_stop`)
- **Step/Offset**: Set frequency step and offset (`set_freq_step`, `set_freq_offset`)
- **Sweep**: Configure sweep points (`set_sweep`), time (`set_sweep_time`), and mode (`set_sweep_mode`)
- **Gated Sweep**: Configure gated sweep parameters (`set_gated_sweep`)

### Amplitude & Power
- **Units**: Set power units (`set_unit`)
- **Reference**: Set reference level (`set_reference_level`)
- **Attenuation**: Control mechanical (`set_attenuation`) and electronic attenuation (`set_elec_attenuation`)
- **Pre-amp**: Enable/disable pre-amplifier (`set_preamp`)
- **Scaling**: Set scale per division (`set_scale_div`)

### Trace & Markers
- **Trace Control**: Set trace modes (Write, MaxHold, etc.) and detectors (`set_trace_mode`, `set_detector`)
- **Bandwidth**: Set RBW and VBW (`set_bandwidth`)
- **Markers**: Place markers (`set_marker`), read values (`get_marker_data`), delta mode (`set_marker_delta`)
- **Marker Functions**: Peak search (`marker_peak_search`), marker to center/ref (`marker_to_center`, `marker_to_ref`)
- **Data**: Save trace data to CSV (`save_trace_data`)

### Advanced Measurements
- **Channel Power**: `measure_channel_power`
- **Occupied Bandwidth**: `measure_obw`
- **Adjacent Channel Power**: `measure_acp`
- **Harmonics**: `measure_harmonics`
- **TOI**: `measure_toi`

## Installation

```julia
using Pkg
Pkg.add("GPIB_rp5") # Dependency
# Clone this repository
```

## Usage

```julia
using Ceyear_4051B

# Connect to the analyzer
sa = SpectrumAnalyzer("GPIB0::18")

# Basic Setup
reset(sa)
set_freq(sa, 2.4, 100) # 2.4 GHz center, 100 MHz span
set_reference_level(sa, 0)

# Measurement
measure(sa)

# Advanced Features
set_marker(sa, 1, 2.4)
freq, ampl = get_marker_data(sa, 1)
println("Marker 1: $freq Hz, $ampl dBm")

# Save Data
save_trace_data(sa, "measurement.csv")

# Close connection
close(sa)
```

## File Structure

- `src/Ceyear_4051B.jl`: Main module entry point and `SpectrumAnalyzer` struct definition.
- `src/SPI_commands.jl`: Implementation of all SCPI commands and measurement functions.
