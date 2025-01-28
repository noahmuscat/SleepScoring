%% loading in data
data_sleepScoring = load('/Users/noahmuscat/University of Michigan Dropbox/Noah Muscat/EphysAnalysis/SampleFiles/Canute/sleepScoringMetrics.mat');
data_activity = readtable('/Users/noahmuscat/University of Michigan Dropbox/Noah Muscat/ActivityAnalysis/ActigraphyEphys/EphysActivityData.csv');
save_directory = '/Users/noahmuscat/Desktop';
conditionOrderSleep = {'Cond300Lux', 'Cond1000LuxWk1', 'Cond1000LuxWk4'};
conditionOrderActivity = {'300Lux', '1000Lux1', '1000Lux4'};

% Convert 'Condition' and 'Animal' into categorical variables
data_activity.Condition = categorical(data_activity.Condition, conditionOrderActivity, 'Ordinal', true);
data_activity.Animal = categorical(data_activity.Animal);

% Ensure 'RelativeDay' is numeric and integer
if ~isnumeric(data_activity.RelativeDay)
    data_activity.RelativeDay = str2double(string(data_activity.RelativeDay));
end
data_activity.RelativeDay = floor(data_activity.RelativeDay);

% Convert 'RelativeDay' to categorical
data_activity.RelativeDay = categorical(data_activity.RelativeDay);

animalActivity = data_activity(data_activity.Animal == 'Canute', :);

%% plotting data
plotSleepStateFrequency(data_sleepScoring.resultsSleepScoring, animalActivity,conditionOrderSleep, conditionOrderActivity, save_directory);

%% Function
function plotSleepStateFrequency(resultsSleepScoring, animalActivity, conditionOrderSleep, conditionOrderActivity, save_directory)
    % Ensure the save directory exists
    if ~exist(save_directory, 'dir')
        mkdir(save_directory);
    end

    total_hours = 0:47; % 48-hour range for the plot

    for condIdx = 1:length(conditionOrderSleep)
        conditionSleep = conditionOrderSleep{condIdx};
        conditionActivity = conditionOrderActivity{condIdx};

        % Filter the data for this specific condition
        thisConditionData = animalActivity(animalActivity.Condition == conditionActivity, :);
            
        % Determine days, and select last 4 or all days if < 8 unique days
        uniqueDays = unique(thisConditionData.RelativeDay);
        numUniqueDays = length(uniqueDays);
            
        if numUniqueDays < 8
            selectedDays = uniqueDays;
        else
            selectedDays = uniqueDays(end-3:end); % Select last 4 days
        end
            
        % Filter data for the selected days
        filteredData = thisConditionData(ismember(thisConditionData.RelativeDay, selectedDays), :);

        % Calculate mean NormalizedActivity for each ZT hour
        hourlyMeans = varfun(@mean, filteredData, 'InputVariables', 'NormalizedActivity', ...
                             'GroupingVariables', 'ZT_Time');
                         
        % Duplicate the 24-hour data to create a 48-hour cycle
        activity48Hours = [hourlyMeans.mean_NormalizedActivity; hourlyMeans.mean_NormalizedActivity];
        
        % Verify that the condition field and ZTData field exist
        if isfield(resultsSleepScoring, conditionSleep) && isfield(resultsSleepScoring.(conditionSleep), 'ZTData')
            thisConditionData = resultsSleepScoring.(conditionSleep).ZTData;
        else
            error('Condition "%s" or its ZTData field does not exist.', conditionSleep);
        end

        % Check ZTData variable names for consistency
        if ~all(ismember({'ZT_Hour', 'Sleep_State'}, thisConditionData.Properties.VariableNames))
            error('ZTData table must contain ''ZT_Hour'' and ''Sleep_State'' columns.');
        end

        % Add a count column to facilitate grouping by state occurrences
        thisConditionData.Count = ones(height(thisConditionData), 1);

        % Aggregate by ZT_Hour and Sleep_State using sum to count occurrences
        stateCounts = groupsummary(thisConditionData, {'ZT_Hour', 'Sleep_State'}, 'sum', 'Count');

        % Prepare empty arrays for plotting
        wakeCounts = zeros(24, 1);
        nremCounts = zeros(24, 1);
        remCounts = zeros(24, 1);

        % Populate the arrays with counts
        for ztHour = 0:23
            % Filter for each sleep state at the current ZT hour
            wakeCounts(ztHour + 1) = sum(stateCounts.sum_Count(stateCounts.ZT_Hour == ztHour & stateCounts.Sleep_State == 1));
            nremCounts(ztHour + 1) = sum(stateCounts.sum_Count(stateCounts.ZT_Hour == ztHour & stateCounts.Sleep_State == 3));
            remCounts(ztHour + 1) = sum(stateCounts.sum_Count(stateCounts.ZT_Hour == ztHour & stateCounts.Sleep_State == 5));
        end

        % Duplicate the 24-hour data to create a 48-hour cycle
        wakeCounts48 = [wakeCounts; wakeCounts];
        nremCounts48 = [nremCounts; nremCounts];
        remCounts48 = [remCounts; remCounts];

        % Create the plot
        figure;

        subplot(2,1,1)
        plot(total_hours, wakeCounts48, 'r', 'LineWidth', 2);
        hold on;
        plot(total_hours, nremCounts48, 'b', 'LineWidth', 2);
        plot(total_hours, remCounts48, 'g', 'LineWidth', 2);

        % Add shading for lights on/off periods
        yLimit = ylim; % Get current y-axis limits
        fill([12 23 23 12], [yLimit(1) yLimit(1) yLimit(2) yLimit(2)], [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
        fill([36 47 47 36], [yLimit(1) yLimit(1) yLimit(2) yLimit(2)], [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.3);

        xlabel('ZT Hour');
        ylabel('Counts of Sleep State');
        title(['48-hour Sleep State Frequency - ', conditionActivity]);
        legend({'WAKE', 'NREM', 'REM'}, 'Location', 'best');
        xticks(0:6:48);
        xlim([-0.5, 47.5]);
        grid on;
        hold off;

        subplot(2,1,2)
        % Plot the 48-hour cycle
        plot(total_hours, activity48Hours, 'b-', 'LineWidth', 2);
        hold on;
        
        % Highlight min and max for each 24-hour cycle
        [minVal1, minIdx1] = min(activity48Hours(1:24));
        [maxVal1, maxIdx1] = max(activity48Hours(1:24));
        [minVal2, minIdx2] = min(activity48Hours(25:48));
        [maxVal2, maxIdx2] = max(activity48Hours(25:48));
        
        plot(total_hours(minIdx1), minVal1, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        plot(total_hours(maxIdx1), maxVal1, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        plot(total_hours(minIdx2 + 24), minVal2, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        plot(total_hours(maxIdx2 + 24), maxVal2, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        
        xlabel('ZT Hour');
        ylabel('Normalized Activity', 'FontSize', 8);
        title(['Activity Over 48 Hours - ', char(conditionActivity)]);
        xticks(0:6:48);
        xlim([-0.5, 47.5]); % Ensure all 48 hours are visible
        grid on;

        % Force the y-axis to auto-scale to fit all plot elements
        ylim([-1 1.5]);
        
        % Retrieve y-axis limits after plotting and auto-scaling
        yLimit = ylim;
        
        % Add gray shading from ZT 12 to ZT 23 and from ZT 36 to ZT 47
        fill([12 23 23 12], [yLimit(1) yLimit(1) yLimit(2) yLimit(2)], [0.7 0.7 0.7], ...
             'EdgeColor', 'none', 'FaceAlpha', 0.5);
        fill([36 47 47 36], [yLimit(1) yLimit(1) yLimit(2) yLimit(2)], [0.7 0.7 0.7], ...
             'EdgeColor', 'none', 'FaceAlpha', 0.5);
        hold off;

        % Save the figure
        save_filename = sprintf('%s_SleepStateFrequencyActivity.png', conditionActivity);
        saveas(gcf, fullfile(save_directory, save_filename));
    end
end