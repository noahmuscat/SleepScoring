function sleepSummaryTable = analyzeSleepStates(filename, lightingLux, animalSex)
    % Function to analyze sleep states
    % Inputs:
    %   filename    : full path of the .mat file containing sleep state data
    %   lightingLux : lighting conditions in Lux
    %   animalSex   : gender of the animal ('M' or 'F')
    % Outputs:
    %   sleepSummaryTable : table containing the processed sleep state data

    % Extract animal name, date, and time from the filename
    [~, name, ~] = fileparts(filename);
    
    try
        % Locate the positions based on fixed format and extract relevant parts
        animalNameEndIdx = find(name == '_', 1) - 1;   % Index before the first underscore
        dateStrStartIdx = animalNameEndIdx + 2;       % Start index for date string
        dateStrEndIdx = dateStrStartIdx + 5;          % End index for date string
        timeStrStartIdx = dateStrEndIdx + 2;          % Start index for time string
        timeStrEndIdx = timeStrStartIdx + 5;          % End index for time string
        
        animalName = name(1:animalNameEndIdx);        % Extract animal name
        dateStr = name(dateStrStartIdx:dateStrEndIdx);% Extract date string
        timeStr = name(timeStrStartIdx:timeStrEndIdx);% Extract time string

        % Convert extracted date and time to datetime object
        manualStartTime = datetime([dateStr timeStr], 'InputFormat', 'yyMMddHHmmss', 'TimeZone', 'America/New_York');
    catch
        % Error handling if parsing fails
        error('Failed to parse date and time information from filename.');
    end

    % Load the sleep state data from the .mat file
    sleepData = load(filename);
    sleepStates = sleepData.SleepState.idx.states;   % Extract sleep state indices

    % Filter sleep states to include only valid states (1: WAKE, 3: NREM, 5: REM)
    validStates = ismember(sleepStates, [1, 3, 5]);
    sleepStates = sleepStates(validStates);

    % Filter corresponding timestamps based on the valid sleep states
    timestamps = sleepData.SleepState.idx.timestamps(validStates);

    % Confirm unique states available in the data
    uniqueStates = unique(sleepStates);
    disp('Unique sleep states present in the data:'); % Display unique states
    disp(uniqueStates');

    % Check the length of the timestamps to ensure it matches the sleep states length
    if length(timestamps) ~= length(sleepStates)
        error('Mismatch between the length of timestamps and sleep states data.');
    end

    % Compute the time array based on the manual start time
    timeArray = manualStartTime + seconds(timestamps);
    
    % Convert to a timetable and bin data by 1-second intervals, computing the mode of each bin
    timeTable = table(timeArray, sleepStates, 'VariableNames', {'Time', 'State'});
    timeTable = table2timetable(timeTable);  % Convert table to timetable
    
    % Create a regular time vector with 1-second intervals
    startTime = min(timeArray);  % Start time based on minimum timestamp
    endTime = max(timeArray);    % End time based on maximum timestamp
    regularTime = (startTime:seconds(1):endTime)';  % Generate 1-second intervals
    
    % Synchronize timetable to regular time vector and take the mode of sleep states for each 1-second bin
    timeTableSync = retime(timeTable, regularTime, @mode);
    binnedTimeArray = timeTableSync.Time;
    binnedSleepStates = timeTableSync.State;
    
    % Round the binned timestamp array to the nearest hour
    roundedTimeArray = dateshift(binnedTimeArray, 'start', 'hour', 'nearest');
    
    % Correct Posix time to reflect real time
    binnedPosixTime = posixtime(binnedTimeArray);
    
    % Calculate Zeitgeber Time (ZT) in hours considering DST for the rounded time array
    ZTtime = zeros(size(roundedTimeArray));
    for i = 1:length(roundedTimeArray)
        currentHour = hour(roundedTimeArray(i));  % Extract current hour
        isDST = isdst(roundedTimeArray(i));       % Check if time is in DST
        if isDST
            % Daylight Saving Time (lights on at 6 AM, lights off at 6 PM)
            ZTtime(i) = mod(currentHour - 6, 24);
        else
            % Standard Time (lights on at 5 AM, lights off at 5 PM)
            ZTtime(i) = mod(currentHour - 5, 24);
        end
    end
    
    % Determine lighting condition based on ZT time
    lights = repmat({'OFF'}, length(ZTtime), 1); % Default to 'OFF'
    lights(ZTtime >= 0 & ZTtime < 12) = {'ON'}; % Set 'ON' for ZT 0-12

    % Set lighting condition in Lux (manually)
    lightingCondition = repmat(lightingLux, length(ZTtime), 1);  % Set the Lux value for every time point
    
    % Metadata for animal sex
    animalSexColumn = repmat({animalSex}, length(roundedTimeArray), 1);  % Set gender for every time point
    
    % Create a table with the processed data
    sleepSummaryTable = table(binnedPosixTime, ZTtime, binnedSleepStates, lightingCondition, lights, animalSexColumn, ...
        'VariableNames', {'PosixTime', 'ZT_time_hours', 'SleepState', 'LightingCondition', 'Lights', 'AnimalSex'});
    
    % Generate output filename for saving the table as CSV
    outputFilename = ['/Users/noahmuscat/University of Michigan Dropbox/Noah Muscat/JeremyAnalysis/Sleep_Scoring/' animalName '/' name '_sleep_summary.csv'];
    
    % Save the table to a CSV file
    writetable(sleepSummaryTable, outputFilename);
    
    % Display success message
    disp('Sleep summary CSV created successfully.');

    %% Visualization of Sleep Data
    
    % Calculate the percentage time spent in each state
    stateLabels = {'WAKE', 'NREM', 'REM'};
    totalSeconds = numel(binnedSleepStates);  % Total number of seconds in the data
    stateCounts = histcounts(binnedSleepStates, [1, 3, 5, 6]);  % Count occurrences of each state
    statePercentages = (stateCounts / totalSeconds) * 100;  % Calculate percentages

    % Construct labels for the pie chart
    stateLabelsWithPercentages = cellfun(@(x, y) sprintf('%s: %.1f%%', x, y), stateLabels, num2cell(statePercentages), 'UniformOutput', false);

    % Plot percentage time spent in each state as a pie chart
    figure;
    pie(statePercentages, stateLabelsWithPercentages);
    title('Percentage Time Spent in Each Sleep State');

    % Plot total time spent in each state as a bar chart
    figure;
    stateLabels = categorical(stateLabels);
    bar(stateLabels, stateCounts);
    ylabel('Total Time (seconds)');
    title('Total Time Spent in Each Sleep State');

    % Plot frequency of each state over 24 hours as a line plot
    ZT_bins = 0:23;  % ZT bins representing each hour in a 24-hour period
    WAKE_freq = zeros(1, 24);
    NREM_freq = zeros(1, 24);
    REM_freq = zeros(1, 24);
    
    % Count the frequency of each state in each ZT_bin
    for i = 0:23
        WAKE_freq(i+1) = sum(ZTtime == i & binnedSleepStates == 1);
        NREM_freq(i+1) = sum(ZTtime == i & binnedSleepStates == 3);
        REM_freq(i+1) = sum(ZTtime == i & binnedSleepStates == 5);
    end

    % Concatenate data to duplicate it for 48 hours
    ZT_bins_48h = [ZT_bins, ZT_bins + 24];  % Create bins for 48 hours
    WAKE_freq_48h = [WAKE_freq, WAKE_freq];
    NREM_freq_48h = [NREM_freq, NREM_freq];
    REM_freq_48h = [REM_freq, REM_freq];
    
    % Plot the frequency over 48 hours
    figure;
    hold on;
    p1 = plot(ZT_bins_48h, WAKE_freq_48h, '-o', 'DisplayName', 'WAKE', 'LineWidth', 2, 'Color', [0, 0.4470, 0.7410]);
    p2 = plot(ZT_bins_48h, NREM_freq_48h, '-o', 'DisplayName', 'NREM', 'LineWidth', 2, 'Color', [0.8500, 0.3250, 0.0980]);
    p3 = plot(ZT_bins_48h, REM_freq_48h, '-o', 'DisplayName', 'REM', 'LineWidth', 2, 'Color', [0.9290, 0.6940, 0.1250]);
    hold off;
    legend;
    xlabel('ZT Time (hours)');
    ylabel('Frequency');
    title('Frequency of Each Sleep State Over 48 Hours');
    addShadedAreaToPlotZT48Hour();

    uistack(p1, 'top');
    uistack(p2, 'top');
    uistack(p3, 'top');
    
    % Display the plot for the frequency over 48 hours
    set(gcf, 'Position', [100, 100, 1200, 800]);  % Adjust figure size
end

% Function to add a shaded area to the current plot
function addShadedAreaToPlotZT48Hour()
    hold on;
    
    % Define x and y coordinates for the first shaded area (from t=12 to t=24)
    x_shaded1 = [12, 24, 24, 12];
    y_lim = ylim;
    y_shaded1 = [y_lim(1), y_lim(1), y_lim(2), y_lim(2)];
    
    % Define x and y coordinates for the second shaded area (from t=36 to t=48)
    x_shaded2 = [36, 48, 48, 36];
    y_shaded2 = [y_lim(1), y_lim(1), y_lim(2), y_lim(2)];
    
    fill_color = [0.7, 0.7, 0.7]; % Light gray color for the shading
    
    % Add shaded areas to the plot
    fill(x_shaded1, y_shaded1, fill_color, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill(x_shaded2, y_shaded2, fill_color, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    % Additional Plot settings
    xlim([-0.5, 47.5]);
    xticks(0:1:47);
    xtickangle(90);
    
    hold off;
end