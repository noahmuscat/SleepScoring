%% loading in data
data = load('/Users/noahmuscat/University of Michigan Dropbox/Noah Muscat/EphysAnalysis/SampleFiles/Canute/sleepScoringMetrics.mat');
save_directory = '/Users/noahmuscat/Desktop';
conditionOrder = {'Cond300Lux', 'Cond1000LuxWk1', 'Cond1000LuxWk4'};

%% plotting data
plotSleepStateFrequency(data.resultsSleepScoring, conditionOrder, save_directory);

%% Function
function plotSleepStateFrequency(resultsSleepScoring, conditionOrder, save_directory)
    % Ensure the save directory exists
    if ~exist(save_directory, 'dir')
        mkdir(save_directory);
    end

    total_hours = 0:47; % 48-hour range for the plot

    for condIdx = 1:length(conditionOrder)
        condition = conditionOrder{condIdx};
        
        % Verify that the condition field and ZTData field exist
        if isfield(resultsSleepScoring, condition) && isfield(resultsSleepScoring.(condition), 'ZTData')
            thisConditionData = resultsSleepScoring.(condition).ZTData;
        else
            error('Condition "%s" or its ZTData field does not exist.', condition);
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
        title(['48-hour Sleep State Frequency - ', condition]);
        legend({'WAKE', 'NREM', 'REM'}, 'Location', 'best');
        xticks(0:6:48);
        xlim([-0.5, 47.5]);
        grid on;
        hold off;

        % Save the figure
        save_filename = sprintf('%s_SleepStateFrequency.png', condition);
        saveas(gcf, fullfile(save_directory, save_filename));
    end
end