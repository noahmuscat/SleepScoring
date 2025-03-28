saveDir = '/Users/noahmuscat/Desktop';

% Define the conditions
conditions = {'300Lux', '1000LuxWk1', '1000LuxWk4'};
validConditions = {'Cond_300Lux', 'Cond_1000LuxWk1', 'Cond_1000LuxWk4'};

% Define sleep states and their corresponding numeric values
sleepStates = {'WAKE', 'NREM', 'REM'};
stateValues = [1, 3, 5]; % Corresponding to WAKE, NREM, REM

structName = HaraldV3Combined80;

% Initialize data structure for storing total time
totalTimeSpent = struct();
for i = 1:length(validConditions)
    totalTimeSpent.(validConditions{i}) = zeros(2, length(sleepStates)); % 2 for day/night
end

% Data aggregation
for conditionIdx = 1:length(validConditions)
    condName = validConditions{conditionIdx};
    condData = structName.(condName);

    % Calculate the timeframe for the last 4 days
    datetime_list = condData.ZT_Datetime;
    endTime = datetime_list(end);
    startTime = endTime - days(4);

    % Create a mask for the last 4 days
    last4DaysMask = (datetime_list >= startTime) & (datetime_list <= endTime);

    % Filter the SleepState for the last 4 days
    last4DaysSleepState = condData.SleepState(last4DaysMask);

    for ztPeriod = 1:2 % 1 for day, 2 for night
        if ztPeriod == 1
            range = 0:11; % Day
        else
            range = 12:23; % Night
        end
        
        for stateIdx = 1:length(sleepStates)
            stateValue = stateValues(stateIdx);

            % Identify indices for the current ZT range
            ZTindices = ismember(hour(datetime_list(last4DaysMask)), range);

            % Count occurrences of each corresponding state value in the ZT range
            totalTimeSpent.(condName)(ztPeriod, stateIdx) = ...
                sum(last4DaysSleepState(ZTindices) == stateValue);
        end
    end
end

% Convert the struct to a matrix for easier plotting
barData_Day = []; % Data for bar plot during day 
barData_Night = []; % Data for bar plot during night 

for i = 1:length(validConditions)
    barData_Day = [barData_Day; totalTimeSpent.(validConditions{i})(1, :)]; % Collect data for day
    barData_Night = [barData_Night; totalTimeSpent.(validConditions{i})(2, :)]; % Collect data for night
end

% Generate plots
figure;
sgtitle('Harald - Total Time Spent in Sleep States per Condition');

subplot(2, 1, 1); % Day
bar(barData_Day, 'grouped');
title('Day (ZT 0-11)');
set(gca, 'XTickLabel', conditions);
ylabel('Total Time');
legend(sleepStates, 'Location', 'best');
xticks(1:length(conditions));
ylim([0 100000])


subplot(2, 1, 2); % Night 
bar(barData_Night, 'grouped');
title('Night (ZT 12-23)');
set(gca, 'XTickLabel', conditions);
ylabel('Total Time');
legend(sleepStates, 'Location', 'best');
xticks(1:length(conditions));
ylim([0 100000])

saveas(gcf, fullfile(saveDir, 'HaraldTotalTimeSleepStateAll.png'));
