function EphysComparing(sleepStateFilename, activityFilename)
    % Function to analyze and overlay sleep states and activity data
    % Inputs:
    %   sleepStateFilename : CSV file containing sleep state data
    %   activityFilename   : CSV file containing activity data
    
    % Load the sleep state data from the CSV file
    sleepData = readtable(sleepStateFilename);

    % Convert PosixTime to datetime for easier manipulation
    sleepData.Time = datetime(sleepData.PosixTime, 'ConvertFrom', 'posixtime', 'TimeZone', 'America/New_York');

    % Extract the date range from the sleep state data
    startDate = min(sleepData.Time);
    endDate = max(sleepData.Time);
    
    % Load the activity data from the CSV file
    activityData = readtable(activityFilename);

    % Convert Date string to datetime for manipulation
    activityData.Date = datetime(activityData.Date, 'InputFormat', 'MM/dd/yyyy HH:mm', 'TimeZone', 'America/New_York');
    
    % Display the original date range of the sleep data
    fprintf('Sleep Data Range: %s to %s\n', datestr(startDate), datestr(endDate));
    
    % Display the original date range of the activity data
    fprintf('Activity Data Range (before filtering): %s to %s\n', datestr(min(activityData.Date)), datestr(max(activityData.Date)));
    
    % Filter activity data to match the extended date range of sleep state data
    activityData = activityData(activityData.Date >= startDate & activityData.Date <= (endDate + days(1)), :);
    
    % Display the date range of the filtered activity data
    fprintf('Activity Data Range (after filtering to endDate + 1): %s to %s\n', datestr(min(activityData.Date)), datestr(max(activityData.Date)));

    % Calculate hourly bins for sleep state data
    sleepData.HourlyZT = floor(sleepData.ZT_time_hours);
    
    % Initialize arrays to store frequency data
    WAKE_freq = zeros(1, 24);
    NREM_freq = zeros(1, 24);
    REM_freq = zeros(1, 24);

    % Count the frequency of each state in each ZT_bin
    for i = 0:23
        WAKE_freq(i+1) = sum(sleepData.HourlyZT == i & sleepData.SleepState == 1);
        NREM_freq(i+1) = sum(sleepData.HourlyZT == i & sleepData.SleepState == 3);
        REM_freq(i+1) = sum(sleepData.HourlyZT == i & sleepData.SleepState == 5);
    end
    
    % Concatenate sleep data to duplicate it for 48 hours
    ZT_bins_48h = [0:23, 24:47];  % Create bins for 48 hours
    WAKE_freq_48h = [WAKE_freq, WAKE_freq];
    NREM_freq_48h = [NREM_freq, NREM_freq];
    REM_freq_48h = [REM_freq, REM_freq];
    
    % Calculate hourly sums for activity data
    activityData.HourlyZT = floor(mod(hour(activityData.Date) + minute(activityData.Date)/60, 24));
    hourlyActivitySum = zeros(1, 24);
    
    for i = 0:23
        hourlyActivitySum(i+1) = sum(activityData.SelectedPixelDifference(activityData.HourlyZT == i));
    end
    
    % Concatenate activity data to duplicate it for 48 hours
    activitySum48 = [hourlyActivitySum, hourlyActivitySum];
    
    % Start plotting
    figure;
    
    % Create first subplot for activity
    subplot(2,1,1);
    hold on;
    
    % Plot activity data as the bars first
    b1 = bar(ZT_bins_48h, activitySum48, 'FaceColor', [0.4660, 0.6740, 0.1880], 'EdgeColor', 'none');
    
    % Add shaded areas
    addShadedAreaToPlotZT48Hour();
    
    % Add labels and title to the first subplot
    xlabel('ZT Time (hours)', 'FontWeight', 'bold');
    ylabel('Sum of Selected Pixel Difference', 'FontWeight', 'bold');
    title('Activity Over 48 Hours', 'FontWeight', 'bold');
    set(gca, 'FontWeight', 'bold'); % Increase font weight for axis labels

    uistack(b1, 'top');
    
    hold off;
    
    % Create second subplot for sleep states
    subplot(2,1,2);
    hold on;
    
    % Plot the lines for sleep states
    p1 = plot(ZT_bins_48h, WAKE_freq_48h, '-o', 'DisplayName', 'WAKE', 'LineWidth', 2, 'Color', [0, 0.4470, 0.7410]);
    p2 = plot(ZT_bins_48h, NREM_freq_48h, '-o', 'DisplayName', 'NREM', 'LineWidth', 2, 'Color', [0.8500, 0.3250, 0.0980]);
    p3 = plot(ZT_bins_48h, REM_freq_48h, '-o', 'DisplayName', 'REM', 'LineWidth', 2, 'Color', [0.9290, 0.6940, 0.1250]);
    
    % Add shaded areas
    addShadedAreaToPlotZT48Hour();
    
    % Add legend, labels, and title to the second subplot
    legend('show');
    xlabel('ZT Time (hours)', 'FontWeight', 'bold');
    ylabel('Sleep State Frequency', 'FontWeight', 'bold');
    title('Frequency of Each Sleep State Over 48 Hours', 'FontWeight', 'bold');
    set(gca, 'FontWeight', 'bold'); % Increase font weight for axis labels

    uistack(p1, 'top');
    uistack(p2, 'top');
    uistack(p3, 'top');

    hold off;

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
    
    % Additional plot settings
    xlim([-0.5, 47.5]);
    xticks(0:47);
    xtickangle(90);
    
    hold off;
end