saveDir = '/Users/noahmuscat/Desktop';

% Define the conditions
conditions = {'300Lux', '1000LuxWk1', '1000LuxWk4'};
validConditions = {'Cond_300Lux', 'Cond_1000LuxWk1', 'Cond_1000LuxWk4'};

% Define sleep states and their corresponding numeric values
sleepStates = {'WAKE', 'NREM', 'REM'};
stateValues = [1, 3, 5]; % Corresponding to WAKE, NREM, REM

structName = CanuteV2Combined80;

% Initialize data structure for storing total time
totalTimeSpent = struct();
for i = 1:length(validConditions)
    totalTimeSpent.(validConditions{i}) = zeros(2, length(sleepStates)); % 2 for day/night
end

% Calculate total time for each condition and each ZT period
for i = 1:length(validConditions)
    condData = structName.(validConditions{i});
    for ztPeriod = 1:2 % 1 for day, 2 for night
        if ztPeriod == 1
            range = 3:8; % Day
        else
            range = 15:20; % Night
        end
        
        for j = 1:length(sleepStates)
            stateValue = stateValues(j);
            
            % Identify indices for the current ZT range
            ZTindices = ismember(hour(condData.ZT_Datetime), range);
            % Count occurrences of each corresponding state value in the ZT range
            totalTimeSpent.(validConditions{i})(ztPeriod, j) = ...
                sum(condData.SleepState(ZTindices) == stateValue);
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
sgtitle('Total Time Spent in Sleep States per Condition');

subplot(2, 1, 1); % Day
bar(barData_Day, 'grouped');
title('Day (ZT 3-8)');
set(gca, 'XTickLabel', conditions);
ylabel('Total Time');
legend(sleepStates, 'Location', 'best');
xticks(1:length(conditions));
ylim([0 200000])


subplot(2, 1, 2); % Night 
bar(barData_Night, 'grouped');
title('Night (ZT 15-20)');
set(gca, 'XTickLabel', conditions);
ylabel('Total Time');
legend(sleepStates, 'Location', 'best');
xticks(1:length(conditions));
ylim([0 200000])

saveas(gcf, fullfile(saveDir, 'Canute%TimeSleepStateMiddle6.png'));
