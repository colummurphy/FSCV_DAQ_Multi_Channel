classdef ProcessInput < handle
    
    properties
        % initialized by constructor, never changed
        app;
        parameters;
        display;
        padding_rangeout;

        src;            % initialized in newDataAvailable, updated every call
        newSamples;
        
        displayActive;

        % displayData + captureData property
        fscvBuffer;     

        % capture properties        
        captureActive;  
        fscvScanDataForFile;
        numOfCaptureCalls;
        firstTriggerMoment;
        scanSearchStartMoment;
    end
    
    methods

        % Constructor.
        function obj = ProcessInput(app, parameters, display)

            obj.app = app;
            obj.parameters = parameters;
            obj.display = display;
            obj = obj.initializeProperties();
        end
    

        function obj = initializeProperties(obj)
        
            obj.displayActive = false;
            obj.captureActive = false;
            obj.padding_rangeout = 0;
            obj.fscvBuffer = [];
            obj.fscvScanDataForFile = [];
            obj.numOfCaptureCalls = 0;
            obj.firstTriggerMoment = [];
            obj.scanSearchStartMoment = 0;
        end
        
        
        % Function called when data is available.
        function obj = newDataAvailable(obj, src, newSamples) 
            obj.src = src;
            obj.newSamples = newSamples;
                        
            % update parameters from the input
            obj.parameters.update();

            if (obj.app.getCapture())
                obj = obj.captureData();
            else
                obj = obj.displayData();
            end
        end


        % Run always starts at timepoint 0. - Run button starts background acquisition
        function obj = displayData(obj)
            
            % first run of function (first timestamp == 0)
            % if (obj.event.TimeStamps(1) == 0)
            if ~obj.displayActive
                obj.fscvBuffer = [];
                obj.scanSearchStartMoment = obj.newSamples(1,1);
                obj.displayActive = true;
            end

            obj.app.setMessage('Not Recording'); 
            
            % add latest data to buffer
            obj = obj.addDataToBuffer(obj.newSamples);
            
            % get scan data
            [firstScan, ~, moments, scanStartMoments,... 
                scanEndMoments, obj] = obj.getScanData();
            
            % display error
            if (isempty(moments))
                 error("No trigger detected for current block of data!");
            end    
      
            % plot data to scope              
            obj.display.plotScopeData(firstScan);

            % plot continuous data
            obj.display.plotContinuousData(obj.fscvBuffer, obj.src.Rate);
            
            % show trigger info in console
            obj.display.showTriggerInfo(obj.newSamples(1,1), moments,...
                                   scanStartMoments, scanEndMoments);     
        end


        function obj = captureData(obj)

            % if no capture active, reset the properties 
            if ~obj.captureActive
                obj.fscvBuffer = [];                
                obj.fscvScanDataForFile = [];
                obj.numOfCaptureCalls = 0;
                obj.firstTriggerMoment = [];
                obj.captureActive = true;       % started to capture data                
                obj.scanSearchStartMoment = obj.newSamples(1,1);
            end
            
            obj.app.setMessage('Recording ...');

            % get latest data from DAQ, add it to the buffer
            obj = obj.addDataToBuffer(obj.newSamples);
            
            % get scan data
            [firstScan, scanData, moments, scanStartMoments, ...
                scanEndMoments, obj] = obj.getScanData();
            
            if (isempty(moments))
                 error("No trigger detected for current block of data!");
            end    

            % keep the first capture Moment
            if isempty(obj.firstTriggerMoment)
                obj.firstTriggerMoment = moments(1);
            end

            % add latest to all scan data
            obj.fscvScanDataForFile = [obj.fscvScanDataForFile; scanData];

            % update capture calls counter
            obj.numOfCaptureCalls = obj.numOfCaptureCalls + 1;
            obj.parameters.numOfCaptureCalls = obj.numOfCaptureCalls;

            % plot continuous data
            obj.display.plotContinuousData(obj.fscvBuffer, obj.src.Rate);

            % plot data for the first triggered scan
            obj.display.plotScopeData(firstScan);
            
            % show trigger info in console
            obj.display.showTriggerInfo(obj.newSamples(1,1), moments,...
                                   scanStartMoments, scanEndMoments);  
           
            % if capture time complete
            if ((obj.fscvBuffer(end,1) - obj.firstTriggerMoment) >...
                    obj.parameters.timeToRecord)

                % get the current file name, save the data to .mat file
                recordedData = obj.fscvScanDataForFile;
                varName = obj.app.getFileName();
                save(varName,'recordedData');
                
                % update file name
                obj.updateFileName();
           
                % plot captured data
                obj.display.plotCapturedData(obj.fscvScanDataForFile);

                % clear the first trigger moment
                obj.firstTriggerMoment = [];

                % clear fscv scan data for file
                obj.fscvScanDataForFile = [];
                
                % reset properties on next run
                if (~obj.app.getContinuousRecord())
                    
                    % stop the daq
                    obj.app.stopDaq();
                    
                    % reset properties in the next loop
                    obj.captureActive = false;

                    % update status                   
                    obj.app.setMessage('Recording Complete');
                end
            end
        end


        function [firstScan, scanData, moments, scanStartMoments,... 
                 scanEndMoments, obj] = getScanData(obj)

            firstScan = [];
            scanData = [];
            moments = [];
            scanStartMoments = [];
            scanEndMoments = [];

            % start from searchFromMoment
            searchFromMoment = obj.scanSearchStartMoment;

            while (true)

                [isTrigDetected, trigMoment] = obj.trigDetect(searchFromMoment);

                if (~isTrigDetected)
                    break;
                end    

                % get indices
                [scanStartIndex, scanEndIndex] = obj.getScanIndices(trigMoment);
                
                % if end index > end, break
                if scanEndIndex > length(obj.fscvBuffer)
                    break;
                end    

                % Disguard partial ramp, start searching from the end of it.
                if (scanStartIndex < 1)
                    
                    disp("Discard scan");
                    disp(trigMoment);
                    disp(scanStartIndex);
                    disp(scanEndIndex);
                    
                    % search from the end of the last scan
                    searchFromMoment = obj.fscvBuffer(scanEndIndex, 1);                                 
                    continue;
                end

                % add scan to array of scans
                singleScan = obj.fscvBuffer(scanStartIndex : scanEndIndex, :);

                if isempty(firstScan)
                    firstScan = singleScan;
                end    

                scanData = [scanData; singleScan]; %#ok<AGROW> 
                moments = [moments; trigMoment]; %#ok<AGROW> 

                scanStartMoments = [scanStartMoments;... 
                    obj.fscvBuffer(scanStartIndex, 1)]; %#ok<AGROW> 

                scanEndMoments = [scanEndMoments;...
                    obj.fscvBuffer(scanEndIndex, 1)]; %#ok<AGROW> 
                
                % search from the end of the last scan
                searchFromMoment = obj.fscvBuffer(scanEndIndex, 1);
            end 

            % update start moment for the next call 
            obj.scanSearchStartMoment = searchFromMoment;
        end    


        % Get a trigger moment, Search from searchFromMoment timestamp.
        function [isTrigDetected, trigMoment] = trigDetect(obj, searchFromMoment)
          
            % Default % Channel = ch34 % Level = -0.1 V % Slope = 10
            % Note: trigChan is 1 higher in fscvData array
            trigChan = obj.parameters.trigCh + 1;         
            trigLevel = obj.parameters.trigLevel;         
            trigSlope = obj.parameters.trigSlope;         
            
            startIndex = find(obj.fscvBuffer(:,1) == searchFromMoment, 1, 'first');
            currentData = obj.fscvBuffer(startIndex:end, :);
            
            % Array of points where trigger (ramp) is above trigger level 
            % trigCondition1 = [0, 0, 0, 0, ..., 1 ] (logical array)
            trigCondition1 = currentData(:, trigChan) > trigLevel;
            
            % if negative slope, check if less then trig level
            if trigSlope < 0
                trigCondition1 = currentData(:, trigChan) < trigLevel;
            end

            % Calculate time step from timestamps (dt = 40 us)
            dt = currentData(2,1) - currentData(1,1);

            % Calculate voltage difference between successive time steps
            % Array of slopes for successive points
            slope = diff(currentData(:, trigChan)) / dt;

            % Compare slopes against trigger slope 
            % trigCondition2 = [ 1, 1, 1, 1, ...0 ] (logical array)
            trigCondition2 = slope > trigSlope;

            % if negative slope
            if trigSlope < 0
                trigCondition2 = slope < trigSlope;
            end

            % Keeps 2 condition arrays same size.
            trigCondition2 = [false; trigCondition2];
   
            % AND 2 logical arrays
            trigCondition = trigCondition1 & trigCondition2;

            % true if any value in trigCondition is 1 
            isTrigDetected = any(trigCondition);

            trigMoment = 0;
            if isTrigDetected
                % Find time moment when trigger condition has been met
                trigTimeStamps = currentData(trigCondition, 1);
    
                % first timestamp in the currentData where the trigger is met 
                trigMoment = trigTimeStamps(1);    
            end
        end


        % Add latestData to buffer. Resize buffer if it gets to large.
        function obj = addDataToBuffer(obj, latestData)

            % Add data to buffer to the end of the buffer
            obj.fscvBuffer = [obj.fscvBuffer; latestData];
            
            % Value is positive if buffer > set size 
            numSamplesToDiscard = size(obj.fscvBuffer,1) ...
                                - obj.parameters.sampleSizeOfBuffer;

            % Remove discarded samples from the start of the buffer.
            if (numSamplesToDiscard > 0)
                obj.fscvBuffer( 1 : numSamplesToDiscard, :) = [];
            end
                    
        end


        % Get the indices of the scan which was detected by the trigger.
        function [scanStartIndex, scanEndIndex] = getScanIndices(obj, trigMoment)
            %{
            scanStartIndex = index 13 samples before the trigger
            scanEndIndex = scanStartIndex + 213 (width of ramp in samples)
            %}

            samplesToTrig = obj.parameters.samplesToTrig;
            timeToScan = obj.parameters.timeToScan;
 
            scanStartIndex = find(obj.fscvBuffer(:,1) == trigMoment, ...
                    1, 'first') - obj.padding_rangeout - samplesToTrig;     
       
            scanEndIndex = round(scanStartIndex + timeToScan * obj.src.Rate ...
                                            + obj.padding_rangeout * 2);     
        end


        % Update stored name for subsequent captures
        function updateFileName(obj) 
               
            fileName = obj.app.getFileName();
            fileTokens = strsplit(fileName, '_');
            
            if length(fileTokens) >= 2
                fileID = strjoin(fileTokens(1:(end-1)), '_');                              
                fileNum = str2num(string(fileTokens(end))); %#ok<ST2NM>    
                newFileName = strcat(fileID, '_', num2str(fileNum + 1));
                
                obj.app.setFileName(newFileName);
            end
        end

    end
end

