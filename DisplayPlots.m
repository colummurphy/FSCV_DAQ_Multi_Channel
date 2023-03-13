classdef DisplayPlots < handle

    properties
        app;
        parameters;

        displayContinuousChannels;
        displayCapturedChannels;
    end


    methods(Static)
        
        
        function showTriggerInfo(firstTimeStamp, ~, scanStartMoments, scanEndMoments)
            disp('---------------------------------------');    
            disp(['TimeStamp: ' num2str(firstTimeStamp) ' seconds'] );
            disp('---------------------------------------');

            
            numScans = length(scanStartMoments);
            for i = 1: numScans
                
                scanStart = scanStartMoments(i);
                scanDuration = scanEndMoments(i) - scanStartMoments(i);
                
                fprintf('scan start: %12.5f\tscan duration: %4.5f\n',... 
                                        scanStart, scanDuration);
            end
        end 
    end


    methods
        function obj = DisplayPlots(app, parameters)
            obj.app = app;
            obj.parameters = parameters;

            obj.displayCapturedChannels = (1:16);
        end


        function plotCapturedData(obj, allfscvScanData)
            
            for i = 1 : length(obj.displayCapturedChannels)
                chanNum = obj.displayCapturedChannels(i);    

                hold(obj.app.capturedDataAxes, 'on');  
                plot(obj.app.capturedDataAxes,...
                        allfscvScanData(:, 1), ...
                        allfscvScanData(:, chanNum + 1));
            end
            hold(obj.app.capturedDataAxes, 'off');  

        end


        % Plot channels in the channel array.  For time period in displayRange.
        function plotContinuousData(obj, fscvBuffer, srcRate)

            % if hold is pressed don't plot
            if obj.app.getHold()
                return;
            end
    
            trigChannel = obj.parameters.getTrigChannel();
            obj.displayContinuousChannels = trigChannel;
            
            timeToPlot = obj.parameters.timeToPlot;
             
            % max time = current fscvBuffer size 
            samplesToPlot = min([ round(timeToPlot * srcRate), ...
                                    size(fscvBuffer,1) ]);
    
            % points to the first sample of the most recent block 
            % (size == samplesToPlot)
            firstPoint = size(fscvBuffer, 1) - samplesToPlot + 1;
    
            % if fscvBuffer size < samplesToPlot
            % Just point to the first sample in the fscvBuffer.
            if firstPoint <= 0
                firstPoint=1;
            end

            % clear axis
            cla(obj.app.continuousDataAxes);
        
            % set the x limits using the first and last timepoint 
            obj.app.continuousDataAxes.XLim = ...
                    [fscvBuffer(firstPoint,1), fscvBuffer(end,1)];
        
            % plot each channel in the channel array
            for i = 1 : length(obj.displayContinuousChannels)
                chanNum = obj.displayContinuousChannels(i);            
                hold(obj.app.continuousDataAxes, 'on');
                plot(obj.app.continuousDataAxes, ...
                    fscvBuffer(firstPoint : end, 1),...
                    fscvBuffer(firstPoint : end, 1 + chanNum) );
            end        
            hold(obj.app.continuousDataAxes, 'off');
        end


        % Plot 2 channels for the duration of the scan (ramp up + down).
        function plotScopeData(obj, firstScan)
        
            % if hold is pressed, don't plot
            if obj.app.getHold()
                return;
            end

            % Get the channel number - default = 1
            scopeChan1 = obj.parameters.scopeChannel1;

            % plot channel vs timestamp
            plot(obj.app.scope1Axes, firstScan(1:end, 1), ...
                firstScan(1:end, scopeChan1 + 1));

            % Get the channel number - default = 2
            scopeChan2 = obj.parameters.scopeChannel2;

            % plot channel vs timestamp
            plot(obj.app.scope2Axes, firstScan(1:end, 1), ...
                firstScan(1:end, scopeChan2 + 1));
        end


        function clearCapturedDataAxis(obj)

            cla(obj.app.capturedDataAxes);
        end

    end
end