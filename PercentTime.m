saveDir = '/Users/noahmuscat/Desktop';

% Define the conditions
conditions = {'300Lux', '1000LuxWk1', '1000LuxWk4'};
validConditions = {'Cond_300Lux', 'Cond_1000LuxWk1', 'Cond_1000LuxWk4'};

% Define sleep states and their corresponding numeric values
sleepStates = {'WAKE', 'NREM', 'REM'};
stateValues = [1, 3, 5]; % Corresponding to WAKE, NREM, REM

structName = CanuteV2Combined80;

% Initialize data structure for storing percentages
statePercentages = struct();
for i = 1:length(validConditions)
    statePercentages.(validConditions{i}) = zeros(2, length(sleepStates)); % 2 for day/night
end

% Calculate percentages for each condition and each ZT period
for i = 1:length(validConditions)
    condData = structName.(validConditions{i});
    for ztPeriod = 1:2 % 1 for day, 2 for night
        if ztPeriod == 1
            range = 3:8; % Day, ZT 3-8
        else
            range = 15:20; % Night, ZT 15-20
        end
        
        totalZT = 0; % Total count for current ZT period across all states
        for j = 1:length(sleepStates)
            stateValue = stateValues(j);
            
            % Identify indices for the current ZT range
            ZTindices = ismember(hour(condData.ZT_Datetime), range);
            % Count occurrences of each corresponding state value in the ZT range
            stateCount = sum(condData.SleepState(ZTindices) == stateValue);
            
            statePercentages.(validConditions{i})(ztPeriod, j) = stateCount;
            totalZT = totalZT + stateCount; % Increment total state count
        end
        
        % Convert counts to percentages if total count is not zero
        if totalZT > 0
            statePercentages.(validConditions{i})(ztPeriod, :) = ...
                 (statePercentages.(validConditions{i})(ztPeriod, :) / totalZT) * 100;
        end
    end
end

% Convert the struct to a matrix for easier plotting
barData_Day = []; % Data for bar plot during day (ZT 3-8)
barData_Night = []; % Data for bar plot during night (ZT 15-20)

for i = 1:length(validConditions)
    barData_Day = [barData_Day; statePercentages.(validConditions{i})(1, :)]; % Collect data for day
    barData_Night = [barData_Night; statePercentages.(validConditions{i})(2, :)]; % Collect data for night
end

% Generate plots
figure;
sgtitle('Percentage Time Spent in Sleep States per Condition');

subplot(2, 1, 1); % Day (ZT 3-8)
bar(barData_Day, 'grouped');
title('Day (ZT 3-8)');
set(gca, 'XTickLabel', conditions);
ylabel('% Time');
legend(sleepStates, 'Location', 'best');
xticks(1:length(conditions));

subplot(2, 1, 2); % Night (ZT 15-20)
bar(barData_Night, 'grouped');
title('Night (ZT 15-20)');
set(gca, 'XTickLabel', conditions);
ylabel('% Time');
legend(sleepStates, 'Location', 'best');
xticks(1:length(conditions));

saveas(gcf, fullfile(saveDir, 'Canute%TimeSleepStateMiddle6.png'));
