%% Main Data Aggregation
% Define the base folder for the 300 Lux lighting condition
baseFolder = '/data/Jeremy/Sleepscoring_Data_Noah/Canute/300Lux';
[~, condition] = fileparts(baseFolder); % Extract '300Lux' as condition
[~, animalName] = fileparts(fileparts(baseFolder)); % Get animal name 'Canute'

% Get a list of all subfolders in the base folder
subFolders = dir(baseFolder);
subFolders = subFolders([subFolders.isdir]);  % Keep only directories
subFolders = subFolders(~ismember({subFolders.name}, {'.', '..'}));  % Remove '.' and '..'

% Initialize variables for pooled data
allZTData = [];
allBoutDurations = struct('WAKEstate', [], 'NREMstate', [], 'REMstate', []);
allInterBoutIntervals = struct('WAKEstate', [], 'NREMstate', [], 'REMstate', []);
allAvgDaytimeStateLengths = struct('WAKEstate', [], 'NREMstate', [], 'REMstate', []);
allAvgNighttimeStateLengths = struct('WAKEstate', [], 'NREMstate', [], 'REMstate', []);

% Iterate through all subfolders and process the data
for k = 1:length(subFolders)
    currentSubFolder = fullfile(baseFolder, subFolders(k).name);
    matFile = dir(fullfile(currentSubFolder, '*.SleepState.states.mat'));
    
    if ~isempty(matFile)
        fullFilePath = fullfile(currentSubFolder, matFile.name);
        
        % Extract sleep state intervals and timestamped sleep states from the .mat file
        [sleepIntervals, sleepStates, appropriateTimestamps, ZTData] = getDataFromMatFile(fullFilePath);
        
        % Replace invalid sleep states with NaN
        sleepStates(~ismember(sleepStates, [1, 3, 5])) = NaN;
        ZTData.Sleep_State(~ismember(ZTData.Sleep_State, [1, 3, 5])) = NaN;

        % Append ZTData to the pooled data
        allZTData = [allZTData; ZTData];
        
        % Calculate sleep bout duration averages
        [boutDurations, numBouts] = calculateBoutDurations(sleepIntervals);
        allBoutDurations = aggregateStructData(allBoutDurations, boutDurations);
        
        % Compute inter-bout intervals
        interBoutIntervals = computeInterBoutIntervals(sleepIntervals);
        allInterBoutIntervals = aggregateStructData(allInterBoutIntervals, interBoutIntervals);
        
        % Average state length during daytime vs nighttime
        [avgDaytimeStateLengths, avgNighttimeStateLengths] = computeDayNightStateLengths(sleepIntervals, appropriateTimestamps);
        allAvgDaytimeStateLengths = aggregateStructData(allAvgDaytimeStateLengths, avgDaytimeStateLengths);
        allAvgNighttimeStateLengths = aggregateStructData(allAvgNighttimeStateLengths, avgNighttimeStateLengths);
    end
end
%% plotting
% Calculate the average sleep state occupancy for each ZT hour
pooledStateOccupancy = calculateStateOccupancy(allZTData);

% Plot the pooled sleep state occupancy
plotStateOccupancy(pooledStateOccupancy, animalName, condition);

% Calculate and plot pooled average bout durations
pooledAvgBoutDurations = computeAverageBoutDurations(allBoutDurations);
disp('Pooled Average Bout Durations:');
disp(pooledAvgBoutDurations);
plotBarGraph(pooledAvgBoutDurations, 'Average Bout Duration (s)', 'Pooled Average Bout Durations', animalName, condition);

% Calculate and plot pooled inter-bout intervals
pooledInterBoutIntervals = computeAverageDurations(allInterBoutIntervals);
disp('Pooled Inter-Bout Intervals:');
disp(pooledInterBoutIntervals);
plotBarGraph(pooledInterBoutIntervals, 'Average Inter-Bout Interval (s)', 'Pooled Inter-Bout Intervals', animalName, condition);

% Calculate and plot pooled average daytime and nighttime state lengths
pooledAvgDaytimeStateLengths = computeAverageDurations(allAvgDaytimeStateLengths);
pooledAvgNighttimeStateLengths = computeAverageDurations(allAvgNighttimeStateLengths);
disp('Pooled Average Daytime State Lengths:');
disp(pooledAvgDaytimeStateLengths);
disp('Pooled Average Nighttime State Lengths:');
disp(pooledAvgNighttimeStateLengths);
plotDayNightComparison(pooledAvgDaytimeStateLengths, pooledAvgNighttimeStateLengths, 'Average State Length (s)', 'Pooled Average State Length by Day/Night', animalName, condition);

% Display the first 10 rows of the pooled ZT data
disp('ZT Data (first 10 rows of pooled data):');
disp(allZTData(1:10, :));

%% Function to extract data from a .mat file and generate appropriate timestamps
function [sleepIntervals, sleepStates, appropriateTimestamps, ZTData] = getDataFromMatFile(fullFilePath)
    % Extract the folder name from the full file path
    [folderPath, ~, ~] = fileparts(fullFilePath);

    % Extract the base folder name
    [~, folderName] = fileparts(folderPath);

    % Extract the animal name and initial timestamp from the folder name
    tokens = regexp(folderName, '_(\d{6})_(\d{6})$', 'tokens');
    if isempty(tokens)
        error('The folder name does not match the expected format Animal_YYMMDD_HHMMSS');
    end
    dateStr = tokens{1}{1};
    timeStr = tokens{1}{2};

    % Combine date and time strings to create a datetime object
    startDateStr = ['20' dateStr]; % Assuming the date is in the format YYMMDD
    startTimeStr = timeStr;
    startDatetime = datetime([startDateStr, startTimeStr], 'InputFormat', 'yyyyMMddHHmmss');

    % Load the .mat file
    data = load(fullFilePath);
    sleepStatesStruct = data.SleepState;

    % Extract sleep intervals from 'ints' field
    sleepIntervals.WAKEstate = sleepStatesStruct.ints.WAKEstate;
    sleepIntervals.NREMstate = sleepStatesStruct.ints.NREMstate;
    sleepIntervals.REMstate = sleepStatesStruct.ints.REMstate;

    % Access the 'timestamps' and 'states' fields within 'idx'
    if isfield(sleepStatesStruct, 'idx') && isfield(sleepStatesStruct.idx, 'timestamps') && isfield(sleepStatesStruct.idx, 'states')
        timestamps = sleepStatesStruct.idx.timestamps;
        sleepStates = sleepStatesStruct.idx.states;
    else
        error('The .mat file does not have the expected structure with idx.timestamps and idx.states');
    end

    % Generate appropriate timestamps by adding 'timestamps' to 'startDatetime'
    appropriateTimestamps = startDatetime + seconds(timestamps);

    % Create an empty table
    ZTHours = zeros(length(timestamps), 1);
    sleepStatesColumn = sleepStates;

    % Calculate ZT hours
    for i = 1:length(timestamps)
        ZTHours(i) = calculateZT(appropriateTimestamps(i));
    end

    % Combine the data into a table
    ZTData = table(appropriateTimestamps, ZTHours, sleepStatesColumn, ...
                   'VariableNames', {'Timestamp', 'ZT_Hour', 'Sleep_State'});
end

%% Function to calculate ZT hour
function ZTHour = calculateZT(timestamp)
    baseHour = 5; % Default start for ZT 0 is 5 AM
    
    if isDST(timestamp)
        baseHour = 6; % Adjust for DST
    end
    
    % Calculate the hour of the day since base hour and adjust to ZT hour
    hourOfDay = hour(timestamp);
    minuteOfDay = minute(timestamp) / 60;
    
    elapsedHours = hourOfDay + minuteOfDay - baseHour;
    if elapsedHours < 0
        elapsedHours = elapsedHours + 24; % Wrap around midnight
    end
    
    ZTHour = floor(elapsedHours);
end

%% Function to calculate sleep state occupancy percentages
function stateOccupancy = calculateStateOccupancy(ZTData)
    % Initialize the occupancy structure
    stateOccupancy = struct('ZT_Hour', (0:23)', ...
                            'WAKEstate', zeros(24, 1), ...
                            'NREMstate', zeros(24, 1), ...
                            'REMstate', zeros(24, 1));
    
    % Loop through each ZT hour
    for ztHour = 0:23
        % Extract the data for the current ZT hour
        currentData = ZTData(ZTData.ZT_Hour == ztHour, :);
        
        % Exclude NaN values
        currentData = currentData(~isnan(currentData.Sleep_State), :);

        % Calculate the percentage of each sleep state for the current ZT hour
        if ~isempty(currentData)
            totalCount = height(currentData);
            stateOccupancy.WAKEstate(ztHour + 1) = (sum(currentData.Sleep_State == 1) / totalCount) * 100;
            stateOccupancy.NREMstate(ztHour + 1) = (sum(currentData.Sleep_State == 3) / totalCount) * 100;
            stateOccupancy.REMstate(ztHour + 1) = (sum(currentData.Sleep_State == 5) / totalCount) * 100;
        end
    end
end

%% Function to plot sleep state occupancy
function plotStateOccupancy(stateOccupancy, animalName, condition)
    % Create a stacked bar graph showing the average percentage of each sleep state per ZT hour
    figure;
    b = bar(stateOccupancy.ZT_Hour, [stateOccupancy.WAKEstate, stateOccupancy.NREMstate, stateOccupancy.REMstate], 'stacked');
    
    % Set colors for each sleep state
    b(1).FaceColor = 'r'; % WAKEstate
    b(2).FaceColor = 'b'; % NREMstate
    b(3).FaceColor = 'g'; % REMstate
    
    xlabel('ZT Hour');
    ylabel('Percentage of Time Spent in Sleep State');
    title(sprintf('%s %s - Sleep State Occupancy Over Time', animalName, condition));
    
    legend({'WAKEstate', 'NREMstate', 'REMstate'}, 'Location', 'NorthEast');
end

%% Function to calculate bout durations for each sleep state and count the number of bouts
function [boutDurations, numBouts] = calculateBoutDurations(sleepIntervals)
    states = fieldnames(sleepIntervals);

    boutDurations = struct();
    numBouts = struct();
    for i = 1:length(states)
        state = states{i};
        intervals = sleepIntervals.(state);
        durations = intervals(:, 2) - intervals(:, 1);
        boutDurations.(state) = durations;
        numBouts.(state) = length(durations);
    end
end

%% Function to compute the average duration for each sleep state
function avgBoutDurations = computeAverageBoutDurations(boutDurations)
    states = fieldnames(boutDurations);
    
    avgBoutDurations = struct();
    for i = 1:length(states)
        state = states{i};
        avgBoutDurations.(state) = mean(boutDurations.(state));
    end
end

%% Function to count the average number of sleep bouts per hour
function avgBoutsPerHour = countAvgBoutsPerHour(appropriateTimestamps, sleepStates)
    % Define the bin width in hours
    binWidth = hours(1);
    
    % Calculate the total duration in hours
    startTime = appropriateTimestamps(1);
    endTime = appropriateTimestamps(end);
    totalDurationHours = hours(endTime - startTime);
    
    % Initialize the count structure
    wakeBouts = 0;
    nremBouts = 0;
    remBouts = 0;
    numBins = ceil(totalDurationHours);
    
    % Loop through each hour and count the number of bouts for each state
    for hour = 1:numBins
        binStart = startTime + (hour - 1) * binWidth;
        binEnd = binStart + binWidth;
        
        binStates = sleepStates(appropriateTimestamps >= binStart & appropriateTimestamps < binEnd);
        
        % Count the occurrences of each state
        wakeBouts = wakeBouts + sum(diff([0; binStates == 1]) == 1);
        nremBouts = nremBouts + sum(diff([0; binStates == 3]) == 1);
        remBouts = remBouts + sum(diff([0; binStates == 5]) == 1);
    end

    % Calculate the average bouts per hour
    avgBoutsPerHour = struct();
    avgBoutsPerHour.WAKEstate = wakeBouts / totalDurationHours;
    avgBoutsPerHour.NREMstate = nremBouts / totalDurationHours;
    avgBoutsPerHour.REMstate = remBouts / totalDurationHours;
end

%% Function to compute the average inter-bout interval for each sleep state
function interBoutIntervals = computeInterBoutIntervals(sleepIntervals)
    states = fieldnames(sleepIntervals);
    
    interBoutIntervals = struct();
    for i = 1:length(states)
        state = states{i};
        intervals = sleepIntervals.(state);
        if size(intervals, 1) < 2
            interBoutIntervals.(state) = NaN; % Not enough bouts to calculate interval
        else
            startTimes = intervals(:, 1);
            interBoutDurations = diff(startTimes);
            interBoutIntervals.(state) = mean(interBoutDurations);
        end
    end
end

%% Function to calculate average state lengths for daytime and nighttime
function [avgDaytimeStateLengths, avgNighttimeStateLengths] = computeDayNightStateLengths(sleepIntervals, appropriateTimestamps)
    states = fieldnames(sleepIntervals);

    % Initialize structures to hold durations
    daytimeDurations = struct();
    nighttimeDurations = struct();
    for i = 1:length(states)
        state = states{i};
        daytimeDurations.(state) = [];
        nighttimeDurations.(state) = [];
        intervals = sleepIntervals.(state);

        for j = 1:size(intervals, 1)
            startTime = appropriateTimestamps(intervals(j, 1));
            endTime = appropriateTimestamps(intervals(j, 2));
            duration = seconds(endTime - startTime);

            % Determine if the interval belongs to daytime or nighttime
            if isDaytime(startTime)
                daytimeDurations.(state) = [daytimeDurations.(state); duration];
            else
                nighttimeDurations.(state) = [nighttimeDurations.(state); duration];
            end
        end
    end

    % Calculate average state lengths
    avgDaytimeStateLengths = computeAverageDurations(daytimeDurations);
    avgNighttimeStateLengths = computeAverageDurations(nighttimeDurations);
end

%% Helper Function to check if a timestamp is during daytime or nighttime
function isDay = isDaytime(timestamp)
    % Define daytime start and end times
    dayStart = datetime(timestamp.Year, timestamp.Month, timestamp.Day, 5, 0, 0); % 5 AM
    if isDST(timestamp)
        dayStart = datetime(timestamp.Year, timestamp.Month, timestamp.Day, 6, 0, 0); % 6 AM during DST
    end
    dayEnd = dayStart + hours(12); % 12 hours later

    % Check if the timestamp is within the daytime interval
    isDay = (timestamp >= dayStart) && (timestamp < dayEnd);
end

%% Helper Function to check if a timestamp falls under Daylight Saving Time (DST)
function isDst = isDST(timestamp)
    % DST starts on the second Sunday in March and ends on the first Sunday in November
    startDST = datetime(timestamp.Year, 3, 8) + days(7 - weekday(datetime(timestamp.Year, 3, 8), 'dayofweek'));
    endDST = datetime(timestamp.Year, 11, 1) + days(7 - weekday(datetime(timestamp.Year, 11, 1), 'dayofweek'));
    isDst = (timestamp >= startDST) && (timestamp < endDST);
end

%% Helper Function to compute average durations from a durations struct
function avgDurations = computeAverageDurations(durations)
    states = fieldnames(durations);
    avgDurations = struct();
    for i = 1:length(states)
        state = states{i};
        if ~isempty(durations.(state))
            avgDurations.(state) = mean(durations.(state));
        else
            avgDurations.(state) = NaN; % Handle case where there are no durations
        end
    end
end

%% Helper Function to aggregate data from multiple structures
function aggregatedData = aggregateStructData(aggregatedData, newData)
    states = fieldnames(newData);
    for i = 1:length(states)
        state = states{i};
        if isfield(aggregatedData, state)
            aggregatedData.(state) = [aggregatedData.(state); newData.(state)];
        else
            aggregatedData.(state) = newData.(state);
        end
    end
end

%% Function to plot bar graph for average durations, counts, or intervals
function plotBarGraph(dataStruct, yLabel, titleText, animalName, condition)
    states = fieldnames(dataStruct);
    values = cellfun(@(f) dataStruct.(f), states);
    
    figure;
    bar(values);
    set(gca, 'XTickLabel', states);
    ylabel(yLabel);
    title(sprintf('%s %s - %s', animalName, condition, titleText));
end

%% Function to plot day vs night comparison bar graph
function plotDayNightComparison(dayData, nightData, yLabel, titleText, animalName, condition)
    states = fieldnames(dayData);
    dayValues = cellfun(@(f) dayData.(f), states);
    nightValues = cellfun(@(f) nightData.(f), states);

    % Ensure that dayValues and nightValues are row vectors
    if size(dayValues, 1) > size(dayValues, 2)
        dayValues = dayValues';
    end
    if size(nightValues, 1) > size(nightValues, 2)
        nightValues = nightValues';
    end

    figure;
    % Create a grouped bar plot
    b = bar([dayValues; nightValues]', 'grouped');

    % Set different colors for day and night bars
    b(1).FaceColor = [0 0.4470 0.7410];  % Daytime bars color (default blue)
    b(2).FaceColor = [0.8500 0.3250 0.0980];  % Nighttime bars color (default red-orange)
    
    set(gca, 'XTickLabel', states);
    ylabel(yLabel);
    title(sprintf('%s %s - %s', animalName, condition, titleText));
    legend('Day', 'Night');
end