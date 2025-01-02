%%%%% Auxiliary function to explore the .mat file
function exploreMatFile(filename)
    % Load the .mat file
    data = load(filename);
    
    % Get the names of all variables in the .mat file
    varNames = fieldnames(data);
    
    % Display the names and types of the variables
    fprintf('Contents of %s:\n', filename);
    for i = 1:length(varNames)
        varName = varNames{i};
        varData = data.(varName);
        fprintf('Variable: %s (Type: %s)\n', varName, class(varData));
        
        % Display subfields if the variable is a struct
        if isstruct(varData)
            exploreStruct(varData, 1);
        end
        fprintf('\n');
    end
end

function exploreStruct(s, level)
    subfieldNames = fieldnames(s);
    indent = repmat('  ', 1, level);
    for j = 1:length(subfieldNames)
        subfieldName = subfieldNames{j};
        subfieldData = s.(subfieldName);
        fprintf('%sSubfield: %s (Type: %s)\n', indent, subfieldName, class(subfieldData));
        
        % Recursively display subfields if the subfield is a struct
        if isstruct(subfieldData)
            exploreStruct(subfieldData, level + 1);
        end
    end
end