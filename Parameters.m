classdef Parameters < handle

% Read current state of parameters + set buttons.

    properties
        app;
        sampleRate;
    
        % gui inputs
        freq;                         
        scanRate;             
        vaMin;           
        vaMax; 
        timeToRecord;                       
        timeToPlot;        

        stimFreq;                             
        stimPulses;                           
        stimWidth;                            
        stimVolts;                             
        stimDelay;                        
        stimStart; 
        stimType;

        scopeChannel1;
        scopeChannel2;

        % calculated values
        trigCh;
        clkCh;
        
        timeToScan;
        trigLevel;
        relTrig;
        trigSlope;
        samplesToTrig;

        scansPerCall;
        scansPerOutputCall;
        defaultFrequency;
        
        stimFlag;
        stimEnable;

        % additional param
        numOfCaptureCalls;

        inputSampleBlockSize;
        sampleSizeOfBuffer;
    end

    
    methods

        % constructor
        function obj = Parameters(app, sampleRate)

            obj.app = app;
            obj.sampleRate = sampleRate;

            % default trig values
            obj.relTrig = 0.15;               % trigger offset
            obj.trigSlope = 10;

            % default values
            obj.numOfCaptureCalls = 0;
            obj.scansPerCall = 10;          % how often is data ping in scans
            obj.scansPerOutputCall = 60;    % how often is data out in scans, if <=10, underflow issues
            obj.defaultFrequency = 10;
            obj.stimFlag = false;
            obj.stimEnable = false;

            % initial values            
            obj.inputSampleBlockSize = 0;
            obj.sampleSizeOfBuffer = 0;
        end


        function obj = setTrigChannel(obj, trigCh)
            obj.trigCh = trigCh;
        end    


        function val = getTrigChannel(obj)
            val = obj.trigCh;
        end


        % call update with session
        function obj = update(obj)

            obj.getInputsFromGUI();
             
            obj.calculateTriggerValues();

            obj.calculateBufferValues();
        end    


        function obj = getInputsFromGUI(obj)

            obj.freq          = obj.app.fscvFreq.Value;               
            obj.scanRate      = obj.app.fscvScanRate.Value;       
            obj.vaMin         = obj.app.fscvLowerLimit.Value;   
            obj.vaMax         = obj.app.fscvUpperLimit.Value; 

            obj.timeToRecord  = obj.app.recordTime.Value;                     
            obj.timeToPlot    = obj.app.displayRange.Value;    

            obj.stimFreq      = obj.app.stimFreq.Value;                             
            obj.stimPulses    = obj.app.stimNumPulses.Value;                           
            obj.stimWidth     = obj.app.stimPulseWidth.Value;                            
            obj.stimVolts     = obj.app.stimVolts.Value;                             
            obj.stimDelay     = obj.app.stimDelay.Value;                         
            obj.stimStart     = obj.app.stimOnsetOfPulses.Value; 

            obj.scopeChannel1 = obj.app.scope1Channel.Value;
            obj.scopeChannel2 = obj.app.scope2Channel.Value;

            if (obj.app.stimTrigger.Value == "mono")
                obj.stimType = 1;
            else 
                obj.stimType = 2;
            end
        end    


        function obj = calculateTriggerValues(obj)

            % duration of scan 
            obj.timeToScan = abs(obj.vaMax-obj.vaMin)./obj.scanRate.*2;

            % -0.3 + 0.15 = -0.15
            obj.trigLevel = obj.vaMin + obj.relTrig;

            % ceil( (-0.15 + 0.3) / 400 * 25000 ) = 10
            obj.samplesToTrig = floor((obj.trigLevel - obj.vaMin)/...
                                    obj.scanRate * obj.sampleRate);
        end


        function obj = calculateBufferValues(obj)

            % Fire data available at size = (10 / 10) * 25000 = 25000        
            obj.inputSampleBlockSize =...
                round( obj.scansPerCall / obj.freq * obj.sampleRate );  
           
            % Duration of block of samples = = 25,000 / 25,000 = 1 second
            dataAvailDuration = double(obj.inputSampleBlockSize)/obj.sampleRate;

            % Note: Not necessary (2-10), minimum = 2 * dataAvailDuration (for overlaps) 
            % Size of buffer in seconds = max([1, 60, 1]) = 60
            durationOfBuffer = max([obj.timeToPlot, obj.timeToRecord, dataAvailDuration]);

            % Size of buffer in samples = = 60 * 25000 = 1,500,000
            obj.sampleSizeOfBuffer = round(durationOfBuffer * obj.sampleRate);
        end

    end
end