classdef DataAcquisition < handle

    properties
        d;
        trigCh;    
        clkCh;

        app; 
        parameters; 
        display;
        
        processInput;
    end

    methods
    
        
        function obj = DataAcquisition(app, parameters, display, sampleRate)

            obj.app = app;
            obj.parameters = parameters;
            obj.display = display;
            obj.processInput = ProcessInput(obj.app, obj.parameters, obj.display);

            obj.d = daq("ni");            
            device = 'striosome';

            numAnalogChannels = 16;
            
            if (numAnalogChannels == 16)
                obj.addAnalogChannels(device, 16);
                obj.addDigitalChannels(device, 8);
            else
                obj.addAnalogChannels(device, 32);
                obj.addDigitalChannels(device, 7);     
            end    
            
            obj.addOutputChannels(device);
        
            % Set acquisition rate, in scans/second/channel
            obj.d.Rate = sampleRate;
            
        end        
        
        
        function obj = addAnalogChannels(obj, device, numChannels) 
            
            channelIndex = 0: numChannels - 1;           
            ch = addinput(obj.d, device, channelIndex, 'Voltage');

            % Set acquisition configuration for each channel
            % NRSE, ramp (filtered) connected to AIsense
            numch=length(ch);
            for ii=1:(numch)
                ch(ii).TerminalConfig = 'SingleEndedNonReferenced';     
                ch(ii).Range = [-10 10];
            end  
            
            % stepped unfiltered ramp   
            addinput(obj.d, device, '_ao0_vs_aognd', 'Voltage');
        end    
        
        
        % 3 ports available on Connector 0 (Port 0, 1 + 2)
        function obj = addDigitalChannels(obj, device, numChannels)
                
            % 7 digital channels
            if (numChannels == 7)
                addinput(obj.d, device, 'Port0/Line0:6', 'Digital');
            end
           
            % 8 digital channels
            if (numChannels == 8)   
                
                % On connector 0
                addinput(obj.d, device, 'Port0/Line0:7', 'Digital');
                
                % On connector 1
                addinput(obj.d, device, 'Port0/Line8:15', 'Digital');
            end    
                              
        end    
        
        
        function obj = addOutputChannels(obj, device)
            
            % Add analog output channels
            addoutput(obj.d, device, [0 2], 'Voltage');

            % Set analog output range
            OutIDs = {obj.d.Channels(1:end).ID};        
            outCh = find(strcmp('ao0', OutIDs) == 1);
            obj.d.Channels(outCh).Range = [-5 5];            
            obj.d.Channels(outCh+1).Range = [-10 10];             

            % get IDs
            IDs = {obj.d.Channels(1:end).ID};              
            
            % trigger channel
            obj.trigCh = find(strcmp('_ao0_vs_aognd', IDs) == 1); 
        end    
        
                
        % get trigger channel
        function trigCh = getTriggerChannel(obj)
            trigCh = obj.trigCh;  
        end
                 

        function preLoadOutputData(obj, outputData)     
            preload(obj.d, outputData);
        end


        function setInputSampleBlockSize(obj, inputSampleBlockSize)    
        
            % ScansAvailableFcn will be called when the number of points
            % accumulated exceeds this value. Default 10 times a second.
            obj.d.ScansAvailableFcnCount = inputSampleBlockSize;
        end

         
        function setThresholdForQueueingMoreOutput(obj, outBuffRefillThreshold )
        
            % Default threshold is 0.5 seconds
            obj.d.ScansRequiredFcnCount = outBuffRefillThreshold;
        end    


        % start session in background 
        function startInBackground(obj)           
            start(obj.d, "continuous");
        end    

        
        % Specify the callback function
        function addListeners(obj, defaultOutput)

            obj.d.ScansAvailableFcn = @(src, event) obj.formatAndProcess(src, event);
            
            obj.d.ScansRequiredFcn = @(src, event) write(src, defaultOutput);
            
            obj.d.ErrorOccurredFcn = @ (src, event) logError(src, event);
            
        end
        
   
        function formatAndProcess(obj, src, ~)
            
            [data, ~] = read(src, src.ScansAvailableFcnCount,...
                            "OutputFormat","Timetable");
            
            dataTable = timetable2table(data);
            dataTable.Time = seconds(dataTable.Time);
            dataArray = table2array(dataTable);
            
            
            obj.processInput.newDataAvailable(src, dataArray); 
        end
        
           
        function logError(~, ~)
            
            disp("Error with Data Acquisition");    
        end    
        
           
        function stopAcquisition(obj)
            
            % stop acquisition
            stop(obj.d);
            
            % clear buttons
            obj.app.resetButtons();

        end    

     
        function displayinitialParams(obj)

            disp(obj.d.Channels);
            disp(obj.parameters);
            disp(obj.parameters.sampleSizeOfBuffer);
        end


        function startAcquisition(obj)

            % clear the data capture plot
            obj.display.clearCapturedDataAxis();

            % set trigger and clock channels
            obj.parameters.setTrigChannel(obj.trigCh);
              
            % update parameters
            obj.parameters.update();
           
            % reset the processInput class to initial values
            obj.processInput.initializeProperties();           
            
            % flush any existing data from the buffers
            flush(obj.d);
            
            % display initial parameters
            obj.displayinitialParams();

            % get default output
            defaultOutput = CreateOutput.getDefaultOutput(obj.parameters);
        
            % set default output buffer refill threshold
            outBuffRefillThreshold = length(defaultOutput) - 10;

            % queue output data before starting session          
            obj.preLoadOutputData(defaultOutput);
    
            % Set size of data available
            obj.setInputSampleBlockSize(obj.parameters.inputSampleBlockSize);

            % DataRequired fired = 150,000 samples(6 seconds) - 10 = 149,990 samples     
            obj.setThresholdForQueueingMoreOutput(outBuffRefillThreshold);

            % Add a listener for events and specify the callback function
            obj.addListeners(defaultOutput);
                    
            % Start session in background mode
            obj.startInBackground();           
        end

    end
end