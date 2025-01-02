filename_sleepStates_mat = '/Users/noahmuscat/University of Michigan Dropbox/Noah Muscat/JeremyAnalysis/Sleep_Scoring/Canute/Canute_231208_101235.SleepState.states.mat';
filename_sleepStates_csv = '/Users/noahmuscat/University of Michigan Dropbox/Noah Muscat/JeremyAnalysis/Sleep_Scoring/Canute/Canute_231208_101235.SleepState.states_sleep_summary.csv';
filename_activity = '/Users/noahmuscat/University of Michigan Dropbox/Noah Muscat/JeremyAnalysis/ActigraphyEphys/EphysCohortData.csv';
lightingLux = 300;
animalSex = 'M';
exploreMatFile(filename_sleepStates_mat);
data = analyzeSleepStates(filename_sleepStates_mat, lightingLux, animalSex);
%EphysComparing(filename_sleepStates_csv, filename_activity);