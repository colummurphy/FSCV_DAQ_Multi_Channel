classdef CreateOutput

    methods(Static)
        
        %{
        output_fscv   150,000 samples, 6 seconds (60 cycles of fscv scans)
        output_stim   150,000 samples, 6 seconds (delay(217 zeros) + 24 pulses + rest(zero))

        if stimFlag == 0 then output_stim is all zeros.
        if stimFlag == 1 AND numCallsMade is correct value then 
        output_stim has pulses.
        %}
        function outputData = getDefaultOutput(parameters)

            freq =          parameters.freq;        % freq = 10
            timeToScan =    parameters.timeToScan;  % timeToScan = 0.0085
            vaMax =         parameters.vaMax;       % vaMax = 1.4
            scanRate =      parameters.scanRate;    % scanRate = 400
            vaMin =         parameters.vaMin;       % vaMin = -0.3

            stimFreq =      parameters.stimFreq;    % stimFreq = 60 Hz
            stimPulses =    parameters.stimPulses;  % stimPulses = 24
            stimWidth =     parameters.stimWidth;   % stimWidth = 2 ms
            stimVolts =     parameters.stimVolts;   % stimVolts = 5 V
            stimDelay =     parameters.stimDelay;   % stimDelay = 0.1 ms
            stimStart =     parameters.stimStart;   % stimStart = 10 sec
            stimType =      parameters.stimType;    % 1 is mono, 2 is bi, stimType = 1 (mono)
            stimFlag =      parameters.stimFlag;    % constantly updated by software

            scansPerCall =  parameters.scansPerCall;        % 10 scans per call
            scansPerOut =   parameters.scansPerOutputCall;     % 60 scans per out

            % acquire calls made during capture, calls = 0 (initial)
            numCallsMade =  parameters.numOfCaptureCalls;   
            sampleRate =    parameters.sampleRate;  % sampleRate = 25000
         
            timePerCall =   scansPerCall/freq;      % 1 s

            
            % output_length = round( 60 / 10 * 25,000 )
            % output_length = 150,000 samples (6 seconds)
            % 6 seconds long for 60 scans per call param
            output_length = round(scansPerOut/parameters.freq*sampleRate); 


            % fscv triangle ramp waveform
            ramp_factor = 1;

            % create equally spaced points along voltage axis with no units for scaling to voltage next

            % sampleframe = [1 : 2500]
            % sampleframe is one cycle of the scan - ramp up, ramp down, hold at -0.3 
            % period of scan = 0.1 seconds
            sampleframe = linspace(1,round((1/freq)*sampleRate),round((1/freq)*sampleRate));    

            % anodal_scan = 400./(25,000).* sampleframe(1 : round(0.0085 * 25000/2) ) - 0.3;
            % anodal_scan = Ramp increment * sampleframe(1 : 106) - 0.3;
            % anodal_scan = Ramp increment * sampleframe(RampUpSamples) - 0.3;
            % anodal_scan = [ -0.3016, -0.3032, -0.3048, ... + 1.396 ]
            anodal_scan = scanRate./(sampleRate).*sampleframe(1:round(timeToScan*sampleRate/2))+vaMin;

            % cathodal_scan = -400./(25,000) .* sampleframe( round(0.0085 * 25000/2) :
            % round(0.0085 * 25000) ) + (1.4 -- 0.3) + 1.396 V
            % cathodal_scan = Ramp decrement .* sampleframe( 106 : 213 ) + 1.7 + 1.396
            % cathodal_scan = [ 1.4, ... -0.312 ]
            cathodal_scan = -scanRate./(sampleRate).*sampleframe(round(timeToScan*sampleRate/2):round(timeToScan*sampleRate))+(vaMax-vaMin)+anodal_scan(end);

            % ramp up + ramp down part of cycle
            % ac_scan length = 214, anodal_scan(1:106), cathodal_scan(107:214)
            ac_scan = [anodal_scan cathodal_scan];

            % hold scan initialized to empty
            hold_scan = [];

            % hold scan length = sampleframe length(2500) - ac_scan length(214)                
            % hold scan values initialized to -0.3
            hold_scan(1:(length(sampleframe)-length(ac_scan))) = vaMin;

            % fscv_scan =[ rampUp, rampDown, hold at -0.3V ] length = 2500 
            fscv_scan = [ac_scan hold_scan]';

            % output_fscv = fscv_scan (ramp_factor = 1)
            output_fscv = fscv_scan.*ramp_factor;

            % repeat fscv cycle 60 times - 150,000 samples (scansPerOut = 60) 
            output_fscv = repmat(output_fscv,scansPerOut,1);  

            % not called
            if length(output_fscv)~=output_length
                warning('output length cuts off uniform scan cycles');
            end

            % output_fscv not changed
            % output_fscv length + output_length are the same 150,000 samples 
            output_fscv = output_fscv(1:output_length);


            %stimulation TTL parameters

            % stimStart = 10 * 25000 = 250,000
            stimStartID = round(stimStart*sampleRate);
            
            % stimStartCall = 10 / 1 = 10
            stimStartCall = stimStart/timePerCall;
            
            % endfirstFSCVindex = 214
            endfirstFSCVindex = length(ac_scan);
            
            % value not used - updated below
            stimOnID = endfirstFSCVindex+round(stimDelay*1e-3*sampleRate)+stimStartID;            %num samples to hold before starting stim relative to end of nearby FSCV scan based on user input
            
            % stimOnID = 214 + 3 = 217
            stimOnID = endfirstFSCVindex+round(stimDelay*1e-3*sampleRate);            %relative to current call
            
            % stimDelayInterval = 217 zeros
            stimDelayInterval = zeros(stimOnID,1);

            % Verticle Vector of 5's, length = 50 samples
            stimPulse = repmat(stimVolts,round(stimWidth*1e-3*sampleRate),1);
            
            % stimInterval = num of samples in stim period - num samples in pulse
            % stimInterval = 417 - 50 = 367 samples
            stimInterval = round(1/stimFreq*sampleRate)-length(stimPulse);
            
            % Verticle Vector of 0's, length = 367 samples 
            stimInterval = zeros(stimInterval,1);
            
            % not used
            stimOut = [stimPulse; stimInterval];

            % bi
            if stimType == 2
                interBi = 2;      %samples between biphasic pulses
                stimOut = [stimPulse; zeros(interBi,1); stimPulse; stimInterval((1:length(stimInterval)-interBi-length(stimPulse)))];
            
            % mono
            else
                % stimOut = [ 5V pulse; 0V Interval ] Verticle Concat
                stimOut = [stimPulse; stimInterval];
            end
            
            % stimOut = 24 cycles of 5V pulse + 0V Inerval
            stimOut = repmat(stimOut,stimPulses,1);
            
            % Vector of 217 0's (Delay), then 24 cycles of stim pulse
            stimOut = [stimDelayInterval; stimOut];
            
            % pad stimOut with zeros to match the length of output_fscv 
            % 150,000 samples, 6 seconds 
            stimRest = zeros(size(output_fscv,1)-size(stimOut,1),1);
            output_stimPrecalc = [stimOut; stimRest];


            % default value for output_stim is all zeros
            % i.e. if stimFlag == 0
            % other conditions not covered below
            output_stim = zeros(length(output_fscv),1);      %disable stim output according to flag based on updated fscv params


            if stimFlag == 1
                
                %not yet stim time yet
                %check that calls made to acquire < stim start call (in acquire call
                %units) since output generate calls (scansPerOut) is slower than input
                %calls (scansPerCall)
                
                % numCallsMade = 0 (initially)
                % 
                if numCallsMade < (stimStartCall*scansPerOut/scansPerCall)
                    output_stim = zeros(length(output_fscv),1);      %disable stim output according to flag based on updated fscv params
                end
                
                %once num calls made = defined stim start time,output stim param,
                %stimCall must be multiple of scansPerOutCall param
                
                % numCallsMade = 0 (initially)
                %  10 * 60 / 10 = 60 
                if numCallsMade == (stimStartCall*scansPerOut/scansPerCall)
                    output_stim = output_stimPrecalc;             %output stim pattern relative to call
                end
                
            end
    
            % Return output_fscv + output_stim vectors
            outputData = repmat([output_fscv,output_stim], 1,1);
        end    
    end
end