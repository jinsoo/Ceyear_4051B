using GPIB_rp5
using Dates

# Note: SpectrumAnalyzer type is defined in the including module

"""
    check_identify(analyzer::SpectrumAnalyzer)

Query the device identification information.
SCPI: `*IDN?`
"""
function check_identify(analyzer::SpectrumAnalyzer)
    idn = GPIB_rp5.query(analyzer.device, "*IDN?")
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
    reset(analyzer::SpectrumAnalyzer)

Reset the device to its default state.
SCPI: `*RST`
"""
function reset(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, "*RST")
    sleep(0.5)
end

"""
    clear(analyzer::SpectrumAnalyzer)

Clear the device status and error queue.
SCPI: `*CLS`
"""
function clear(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, "*CLS")
end

"""
    check_error(analyzer::SpectrumAnalyzer)

Check for and print any errors from the device.
SCPI: `:SYSTem:ERRor?`
"""
function check_error(analyzer::SpectrumAnalyzer)
    error_msg = GPIB_rp5.query(analyzer.device, ":SYST:ERR?")
    
    if !contains(error_msg, "+0")
        println("Error: $error_msg")
        GPIB_rp5.write(analyzer.device, "*CLS")
        return true
    end
    return false
end

# --- Frequency Control ---

"""
    set_freq(analyzer::SpectrumAnalyzer, center_freq, span_freq=500)

Set the center frequency and span.
SCPI: `:FREQuency:CENTer`, `:FREQuency:SPAN`
"""
function set_freq(analyzer::SpectrumAnalyzer, center_freq::Real, span_freq::Real=500)
    analyzer.center_freq = Float64(center_freq)
    analyzer.span_freq = Float64(span_freq)
    
    GPIB_rp5.write(analyzer.device, ":FREQUENCY:CENTER $(center_freq) GHz")
    GPIB_rp5.write(analyzer.device, ":FREQUENCY:SPAN $(span_freq) MHz")
    check_error(analyzer)
end

"""
    set_freq_start_stop(analyzer::SpectrumAnalyzer, start_freq, stop_freq)

Set the start and stop frequencies.
SCPI: `:FREQuency:STARt`, `:FREQuency:STOP`
"""
function set_freq_start_stop(analyzer::SpectrumAnalyzer, start_freq::Real, stop_freq::Real)
    GPIB_rp5.write(analyzer.device, ":FREQuency:STARt $(start_freq) GHz")
    GPIB_rp5.write(analyzer.device, ":FREQuency:STOP $(stop_freq) GHz")
    
    # Update center/span cache roughly
    analyzer.center_freq = (start_freq + stop_freq) / 2
    analyzer.span_freq = (stop_freq - start_freq) * 1000
    check_error(analyzer)
end

"""
    set_freq_step(analyzer::SpectrumAnalyzer, step_size, auto=true)

Set the frequency step size.
SCPI: `:FREQuency:CENTer:STEP`
"""
function set_freq_step(analyzer::SpectrumAnalyzer, step_size::Real=0.0, auto::Bool=true)
    if auto
        GPIB_rp5.write(analyzer.device, ":FREQuency:CENTer:STEP:AUTO ON")
    else
        GPIB_rp5.write(analyzer.device, ":FREQuency:CENTer:STEP $(step_size) MHz")
        GPIB_rp5.write(analyzer.device, ":FREQuency:CENTer:STEP:AUTO OFF")
    end
    check_error(analyzer)
end

"""
    set_freq_offset(analyzer::SpectrumAnalyzer, offset)

Set the frequency offset.
SCPI: `:FREQuency:OFFSet`
"""
function set_freq_offset(analyzer::SpectrumAnalyzer, offset::Real)
    GPIB_rp5.write(analyzer.device, ":FREQuency:OFFSet $(offset) Hz")
    check_error(analyzer)
end

# --- Amplitude & Power ---

"""
    set_reference_level(analyzer::SpectrumAnalyzer, level)

Set the reference level.
SCPI: `:DISPlay:WINDow:TRACe:Y:RLEVel`
"""
function set_reference_level(analyzer::SpectrumAnalyzer, level::Real)
    analyzer.reference_level = Float64(level)
    GPIB_rp5.write(analyzer.device, ":DISPlay:WINDow:TRACe:Y:RLEVel $(level) dBm")
    check_error(analyzer)
end

"""
    set_attenuation(analyzer::SpectrumAnalyzer, attenuation, auto=false)

Set the RF input attenuation.
SCPI: `:SENSe:POWer:RF:ATTenuation`
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
    set_elec_attenuation(analyzer::SpectrumAnalyzer, attenuation, enable=true)

Set the electronic attenuation.
SCPI: `:POWer:RF:EATTenuation`
"""
function set_elec_attenuation(analyzer::SpectrumAnalyzer, attenuation::Real, enable::Bool=true)
    state = enable ? "ON" : "OFF"
    GPIB_rp5.write(analyzer.device, ":POWer:RF:EATTenuation:STATe $(state)")
    if enable
        GPIB_rp5.write(analyzer.device, ":POWer:RF:EATTenuation $(attenuation) dB")
    end
    check_error(analyzer)
end

"""
    set_mixer_range(analyzer::SpectrumAnalyzer, level)

Set the maximum mixer level.
SCPI: `:POWer:RF:MIXer:RANGe`
"""
function set_mixer_range(analyzer::SpectrumAnalyzer, level::Real)
    GPIB_rp5.write(analyzer.device, ":POWer:RF:MIXer:RANGe $(level) dBm")
    check_error(analyzer)
end

"""
    set_preamp(analyzer::SpectrumAnalyzer, enable=true)

Turn the pre-amplifier on or off.
SCPI: `:POWer:RF:GAIN[:STATe]`
"""
function set_preamp(analyzer::SpectrumAnalyzer, enable::Bool=true)
    state = enable ? "ON" : "OFF"
    GPIB_rp5.write(analyzer.device, ":POWer:RF:GAIN:STATe $(state)")
    check_error(analyzer)
end

"""
    set_scale_div(analyzer::SpectrumAnalyzer, scale)

Set the scale per division.
SCPI: `:DISPlay:WINDow:TRACe:Y:SCALe:PDIVision`
"""
function set_scale_div(analyzer::SpectrumAnalyzer, scale::Real)
    GPIB_rp5.write(analyzer.device, ":DISPlay:WINDow:TRACe:Y:SCALe:PDIVision $(scale) dB")
    check_error(analyzer)
end

"""
    set_unit(analyzer::SpectrumAnalyzer, unit="dBm")

Set the power unit.
SCPI: `:UNIT:POWer`
"""
function set_unit(analyzer::SpectrumAnalyzer, unit::String="dBm")
    valid_units = ["DBM", "DBMV", "DBMA", "V", "W", "A", "DBUV", 
                   "DBUA", "DBUVM", "DBUAM", "DBPT", "DBG"]
    if any(uppercase(unit) == uppercase(u) for u in valid_units)
        GPIB_rp5.write(analyzer.device, ":UNIT:POWER $(unit)")
    else
        @error "Invalid unit: $(unit)"
    end
    check_error(analyzer)
end

# --- Sweep Control ---

"""
    set_sweep(analyzer::SpectrumAnalyzer, sweep_type="sweep", points=1001)

Configure sweep type and points.
SCPI: `:SWEep:TYPE`, `:SWEep:POINts`
"""
function set_sweep(analyzer::SpectrumAnalyzer, sweep_type::String="sweep", points::Integer=1001)
    analyzer.points = points
    GPIB_rp5.write(analyzer.device, ":SWEep:TYPE $(sweep_type)")
    GPIB_rp5.write(analyzer.device, ":SWEep:POINts $(points)")
    check_error(analyzer)
end

"""
    set_sweep_time(analyzer::SpectrumAnalyzer, time=0.0, auto=true)

Set the sweep time.
SCPI: `:SWEep:TIME`
"""
function set_sweep_time(analyzer::SpectrumAnalyzer, time::Real=0.0, auto::Bool=true)
    if auto
        GPIB_rp5.write(analyzer.device, ":SWEep:TIME:AUTO ON")
    else
        GPIB_rp5.write(analyzer.device, ":SWEep:TIME $(time) s")
        GPIB_rp5.write(analyzer.device, ":SWEep:TIME:AUTO OFF")
    end
    check_error(analyzer)
end

"""
    set_sweep_mode(analyzer::SpectrumAnalyzer, mode="CONT")

Set the sweep mode (Continuous or Single).
SCPI: `:INITiate:CONTinuous`
"""
function set_sweep_mode(analyzer::SpectrumAnalyzer, mode::String="CONT")
    if uppercase(mode) == "CONT"
        GPIB_rp5.write(analyzer.device, ":INITiate:CONTinuous ON")
    elseif uppercase(mode) == "SING"
        GPIB_rp5.write(analyzer.device, ":INITiate:CONTinuous OFF")
    else
        @error "Invalid sweep mode: $mode. Use 'CONT' or 'SING'."
    end
    check_error(analyzer)
end

"""
    set_gated_sweep(analyzer::SpectrumAnalyzer, enable=true, source="EXT", delay=0.0, length=0.0)

Configure gated sweep.
SCPI: `:SWEep:EGATe`
"""
function set_gated_sweep(analyzer::SpectrumAnalyzer, enable::Bool=true, source::String="EXT", delay::Real=0.0, length::Real=0.0)
    if enable
        GPIB_rp5.write(analyzer.device, ":SWEep:EGATe:STATe ON")
        GPIB_rp5.write(analyzer.device, ":SWEep:EGATe:SOURce $(source)")
        if delay > 0
             GPIB_rp5.write(analyzer.device, ":SWEep:EGATe:DELay $(delay) s")
        end
        if length > 0
             GPIB_rp5.write(analyzer.device, ":SWEep:EGATe:LENGth $(length) s")
        end
    else
        GPIB_rp5.write(analyzer.device, ":SWEep:EGATe:STATe OFF")
    end
    check_error(analyzer)
end

# --- Bandwidth & Trace ---

"""
    set_bandwidth(analyzer::SpectrumAnalyzer, rbw=0.0, vbw=0.0, auto=true)

Set RBW and VBW.
SCPI: `:BANDwidth:RESolution`, `:BANDwidth:VIDeo`
"""
function set_bandwidth(analyzer::SpectrumAnalyzer, rbw::Real=0.0, vbw::Real=0.0, auto::Bool=true)
    if auto
        GPIB_rp5.write(analyzer.device, ":BANDwidth:RESolution:AUTO ON")
        GPIB_rp5.write(analyzer.device, ":BANDwidth:VIDeo:AUTO ON")
        
        resp_rbw = GPIB_rp5.query(analyzer.device, ":BANDwidth:RESolution?")
        analyzer.rbw = parse(Float64, resp_rbw)
        resp_vbw = GPIB_rp5.query(analyzer.device, ":BANDwidth:VIDeo?")
        analyzer.vbw = parse(Float64, resp_vbw)
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
    set_trace_mode(analyzer::SpectrumAnalyzer, mode="WRITE", trace_num=1)

Set trace mode.
SCPI: `:TRACe:MODE`
"""
function set_trace_mode(analyzer::SpectrumAnalyzer, mode::String="WRITE", trace_num::Integer=1)
    valid_modes = ["WRITE", "MAXHold", "MINHold", "VIEW", "BLANk", "AVERage"]
    if any(uppercase(mode) == uppercase(m) for m in valid_modes)
        if trace_num == 1
            analyzer.trace_mode = uppercase(mode)
        end
        GPIB_rp5.write(analyzer.device, ":TRACe$(trace_num):MODE $(mode)")
    else
        @error "Invalid trace mode: $(mode)"
    end
    check_error(analyzer)
end

"""
    set_detector(analyzer::SpectrumAnalyzer, detector_type="NORMAL")

Set detector type.
SCPI: `:DETector:TRACe`
"""
function set_detector(analyzer::SpectrumAnalyzer, detector_type::String="NORMAL")
    valid_detectors = ["NORMAL", "POSitive", "NEGative", "SAMPle", "AVERage", "RMS"]
    if any(uppercase(detector_type) == uppercase(d) for d in valid_detectors)
        analyzer.detector_type = uppercase(detector_type)
        GPIB_rp5.write(analyzer.device, ":DETector:TRACe1 $(detector_type)")
    else
        @error "Invalid detector type: $(detector_type)"
    end
    check_error(analyzer)
end

"""
    set_format(analyzer::SpectrumAnalyzer, data_type="ASCii")

Set trace data format.
SCPI: `:FORMat:TRACe`
"""
function set_format(analyzer::SpectrumAnalyzer, data_type::String="ASCii")
    valid_formats = ["ASCii", "INTeger32", "REAL32", "REAL64"]
    if any(uppercase(data_type) == uppercase(f) for f in valid_formats)
        GPIB_rp5.write(analyzer.device, ":FORMAT:TRACE $(data_type)")
    else
        @error "Invalid format: $(data_type)"
    end
    check_error(analyzer)
end

"""
    reset_trace(analyzer::SpectrumAnalyzer)

Reset all trace data.
SCPI: `:TRACe:PRESET:ALL`
"""
function reset_trace(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, ":TRACE:PRESET:ALL")
    check_error(analyzer)
end

"""
    save_trace_data(analyzer::SpectrumAnalyzer, filename, trace_num=1, include_header=true)

Save trace data to a CSV file.
"""
function save_trace_data(analyzer::SpectrumAnalyzer, filename::String, trace_num::Integer=1, include_header::Bool=true)
    GPIB_rp5.write(analyzer.device, ":FORMat:TRACe:DATA ASCii")
    response = GPIB_rp5.query(analyzer.device, ":TRACe:DATA? TRACE$(trace_num)")
    
    values = split(response, ",")
    y_data = [parse(Float64, v) for v in values]
    
    freq_start = analyzer.center_freq - analyzer.span_freq/2000
    freq_stop = analyzer.center_freq + analyzer.span_freq/2000
    x_data = range(freq_start, freq_stop, length=length(y_data))
    
    open(filename, "w") do file
        if include_header
            write(file, "# Ceyear 4051B Trace Data\n")
            write(file, "# Date: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))\n")
            write(file, "# Center: $(analyzer.center_freq) GHz, Span: $(analyzer.span_freq) MHz\n")
        end
        for (x, y) in zip(x_data, y_data)
            write(file, "$x, $y\n")
        end
    end
end

# --- Triggering ---

"""
    set_trigger(analyzer::SpectrumAnalyzer, trigger="IMMediate")

Set trigger source.
SCPI: `:TRIGger:SOURce`
"""
function set_trigger(analyzer::SpectrumAnalyzer, trigger::String="IMMediate")
    valid_triggers = ["EXTernal1", "EXTernal2", "IMMediate", "LINE", "FRAMe", 
                      "RFBurst", "VIDeo", "IF", "ALARm", "LAN", "IQMag", 
                      "IDEMod", "QDEMod", "IINPut", "QINPut", "AIQMag"]
    if any(uppercase(trigger) == uppercase(t) for t in valid_triggers)
        GPIB_rp5.write(analyzer.device, ":TRIGger:SOURce $(trigger)")
    else
        @error "Invalid trigger: $(trigger)"
    end
    check_error(analyzer)
end

"""
    set_trigger_delay(analyzer::SpectrumAnalyzer, delay, source="EXTernal1", enable=true)

Set trigger delay.
SCPI: `:TRIGger:EXTernal:DELay`
"""
function set_trigger_delay(analyzer::SpectrumAnalyzer, delay::Real, source::String="EXTernal1", enable::Bool=true)
    GPIB_rp5.write(analyzer.device, ":TRIGger:$(source):DELay:STATe $(enable ? "ON" : "OFF")")
    if enable
        GPIB_rp5.write(analyzer.device, ":TRIGger:$(source):DELay $(delay) s")
    end
    check_error(analyzer)
end

"""
    set_trigger_level(analyzer::SpectrumAnalyzer, level, source="EXTernal1")

Set trigger level.
SCPI: `:TRIGger:EXTernal:LEVel`
"""
function set_trigger_level(analyzer::SpectrumAnalyzer, level::Real, source::String="EXTernal1")
    GPIB_rp5.write(analyzer.device, ":TRIGger:$(source):LEVel $(level) V")
    check_error(analyzer)
end

"""
    set_trigger_slope(analyzer::SpectrumAnalyzer, slope="POS", source="EXTernal1")

Set trigger slope.
SCPI: `:TRIGger:EXTernal:SLOPe`
"""
function set_trigger_slope(analyzer::SpectrumAnalyzer, slope::String="POS", source::String="EXTernal1")
    GPIB_rp5.write(analyzer.device, ":TRIGger:$(source):SLOPe $(slope)")
    check_error(analyzer)
end

# --- Marker Functions ---

"""
    set_marker(analyzer::SpectrumAnalyzer, marker_num=1, freq=0.0, trace_num=1)

Set marker position.
SCPI: `:CALCulate:MARKer`
"""
function set_marker(analyzer::SpectrumAnalyzer, marker_num::Integer=1, freq::Real=0.0, trace_num::Integer=1)
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):STATe ON")
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):MODE POSition")
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):TRACe $(trace_num)")
    
    if freq <= 0.0
        GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):X:CENTer")
    else
        GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):X $(freq) GHz")
    end
    check_error(analyzer)
end

"""
    get_marker_data(analyzer::SpectrumAnalyzer, marker_num=1)

Get marker frequency and amplitude.
SCPI: `:CALCulate:MARKer:X?`, `:CALCulate:MARKer:Y?`
"""
function get_marker_data(analyzer::SpectrumAnalyzer, marker_num::Integer=1)
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):STATe ON")
    x_resp = GPIB_rp5.query(analyzer.device, ":CALCulate:MARKer$(marker_num):X?")
    y_resp = GPIB_rp5.query(analyzer.device, ":CALCulate:MARKer$(marker_num):Y?")
    return (parse(Float64, x_resp), parse(Float64, y_resp))
end

"""
    set_marker_delta(analyzer::SpectrumAnalyzer, marker_num=1, ref_marker=2)

Set marker to delta mode.
SCPI: `:CALCulate:MARKer:MODE DELTa`
"""
function set_marker_delta(analyzer::SpectrumAnalyzer, marker_num::Integer=1, ref_marker::Integer=2)
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):MODE DELTa")
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):REFerence $(ref_marker)")
    check_error(analyzer)
end

"""
    marker_peak_search(analyzer::SpectrumAnalyzer, marker_num=1)

Move marker to peak.
SCPI: `:CALCulate:MARKer:MAXimum`
"""
function marker_peak_search(analyzer::SpectrumAnalyzer, marker_num::Integer=1)
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):MAXimum")
    check_error(analyzer)
end

"""
    marker_to_center(analyzer::SpectrumAnalyzer, marker_num=1)

Set center frequency to marker value.
SCPI: `:CALCulate:MARKer:FUNCtion:TO:CENTer`
"""
function marker_to_center(analyzer::SpectrumAnalyzer, marker_num::Integer=1)
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):FUNCtion:TO:CENTer")
    check_error(analyzer)
end

"""
    marker_to_ref(analyzer::SpectrumAnalyzer, marker_num=1)

Set reference level to marker value.
SCPI: `:CALCulate:MARKer:FUNCtion:TO:RLEVel`
"""
function marker_to_ref(analyzer::SpectrumAnalyzer, marker_num::Integer=1)
    GPIB_rp5.write(analyzer.device, ":CALCulate:MARKer$(marker_num):FUNCtion:TO:RLEVel")
    check_error(analyzer)
end

# --- Measurement Functions ---

"""
    measure(analyzer::SpectrumAnalyzer)

Perform a measurement and return trace data.
SCPI: `:INIT`, `:TRACe:DATA?`
"""
function measure(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, "*SRE 32")
    GPIB_rp5.write(analyzer.device, "*ESE 1")
    GPIB_rp5.write(analyzer.device, ":INIT")
    GPIB_rp5.query(analyzer.device, "*OPC?")
    
    response = GPIB_rp5.query(analyzer.device, ":TRACe:DATA? TRACE1")
    values = split(response, ",")
    data = [parse(Float64, v) for v in values]
    
    for d in data
        println(d)
    end
    return data
end

"""
    shot(analyzer::SpectrumAnalyzer, n=10, freq=0.0)

Take multiple readings at a specific frequency.
"""
function shot(analyzer::SpectrumAnalyzer, n::Integer=10, freq::Real=0.0)
    meas_freq = freq == 0.0 ? analyzer.center_freq : Float64(freq)
    data = zeros(Float64, n)
    
    GPIB_rp5.write(analyzer.device, ":CALC:MARKER:X:POSITION $(meas_freq)")
    
    for i in 1:n
        GPIB_rp5.write(analyzer.device, "*TRG")
        response = GPIB_rp5.query(analyzer.device, ":CALC:MARK:Y?")
        data[i] = parse(Float64, rstrip(response))
    end
    check_error(analyzer)
    return data
end

"""
    measure_channel_power(analyzer::SpectrumAnalyzer)

Measure Channel Power.
SCPI: `:CONFigure:CHPower`, `:FETCh:CHPower?`
"""
function measure_channel_power(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, ":CONFigure:CHPower")
    GPIB_rp5.write(analyzer.device, ":INITiate:CHPower")
    GPIB_rp5.query(analyzer.device, "*OPC?")
    return GPIB_rp5.query(analyzer.device, ":FETCh:CHPower?")
end

"""
    measure_obw(analyzer::SpectrumAnalyzer)

Measure Occupied Bandwidth.
SCPI: `:CONFigure:OBWidth`, `:FETCh:OBWidth?`
"""
function measure_obw(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, ":CONFigure:OBWidth")
    GPIB_rp5.write(analyzer.device, ":INITiate:OBWidth")
    GPIB_rp5.query(analyzer.device, "*OPC?")
    return GPIB_rp5.query(analyzer.device, ":FETCh:OBWidth?")
end

"""
    measure_acp(analyzer::SpectrumAnalyzer)

Measure Adjacent Channel Power.
SCPI: `:CONFigure:ACPower`, `:FETCh:ACPower?`
"""
function measure_acp(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, ":CONFigure:ACPower")
    GPIB_rp5.write(analyzer.device, ":INITiate:ACPower")
    GPIB_rp5.query(analyzer.device, "*OPC?")
    return GPIB_rp5.query(analyzer.device, ":FETCh:ACPower?")
end

"""
    measure_harmonics(analyzer::SpectrumAnalyzer)

Measure Harmonics.
SCPI: `:CONFigure:HARMonics`, `:FETCh:HARMonics?`
"""
function measure_harmonics(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, ":CONFigure:HARMonics")
    GPIB_rp5.write(analyzer.device, ":INITiate:HARMonics")
    GPIB_rp5.query(analyzer.device, "*OPC?")
    return GPIB_rp5.query(analyzer.device, ":FETCh:HARMonics?")
end

"""
    measure_toi(analyzer::SpectrumAnalyzer)

Measure Third Order Intercept.
SCPI: `:CONFigure:TOI`, `:FETCh:TOI?`
"""
function measure_toi(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, ":CONFigure:TOI")
    GPIB_rp5.write(analyzer.device, ":INITiate:TOI")
    GPIB_rp5.query(analyzer.device, "*OPC?")
    return GPIB_rp5.query(analyzer.device, ":FETCh:TOI?")
end

# --- System ---

"""
    set_rosc_source(analyzer::SpectrumAnalyzer, source="INT")

Set reference oscillator source.
SCPI: `:ROSCillator:SOURce`
"""
function set_rosc_source(analyzer::SpectrumAnalyzer, source::String="INT")
    GPIB_rp5.write(analyzer.device, ":ROSCillator:SOURce $(source)")
    check_error(analyzer)
end

"""
    system_preset_user(analyzer::SpectrumAnalyzer)

Preset system to user settings.
SCPI: `:SYSTem:PRESet:USER`
"""
function system_preset_user(analyzer::SpectrumAnalyzer)
    GPIB_rp5.write(analyzer.device, ":SYSTem:PRESet:USER")
    check_error(analyzer)
end

"""
    set_gpib_address(analyzer::SpectrumAnalyzer, address)

Set GPIB address.
SCPI: `:SYSTem:COMMunicate:GPIB:ADDRess`
"""
function set_gpib_address(analyzer::SpectrumAnalyzer, address::Integer)
    GPIB_rp5.write(analyzer.device, ":SYSTem:COMMunicate:GPIB:ADDRess $(address)")
    check_error(analyzer)
end

"""
    set_display_enable(analyzer::SpectrumAnalyzer, enable=true)

Enable or disable the display.
SCPI: `:DISPlay:ENABle`
"""
function set_display_enable(analyzer::SpectrumAnalyzer, enable::Bool=true)
    GPIB_rp5.write(analyzer.device, ":DISPlay:ENABle $(enable ? "ON" : "OFF")")
    check_error(analyzer)
end
