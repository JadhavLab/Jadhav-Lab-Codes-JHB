function [dat,hmmdat] = cs_createHMMmatrix(animID, day, region, win, bintime)
topDir = cs_setPaths();
dataDir = [topDir, 'AnalysesAcrossAnimals\'];
animals = {'CS31','CS33','CS34','CS35','CS39','CS41','CS42','CS44'};

%get nosepoke cells for one day
load([dataDir, 'npCells_', region]);
cells = npCells(ismember(npCells(:,[1 2]),[animID, day],'rows'),:);

%for each cell, get spikes
animal = animals{animID};
animDir = [topDir, animal, 'Expt\',animal,'_direct\'];
daystr = getTwoDigitNumber(day);
load([animDir,animal,'spikes',daystr]);
load([animDir,animal,'odorTriggers',daystr]);
numcells = size(cells,1);

%get trial start times
epochs = cs_getRunEpochs(animDir, animal, 'odorplace',day);

for c = 1:numcells
    cell = cells(c,[3 4]);
    
    n(c).data = [];
    trignum = 0;
    for ep = epochs(:,2)'
        if ~isempty(spikes{day}{ep}{cell(1)}{cell(2)}.data)
            spiketimes = spikes{day}{ep}{cell(1)}{cell(2)}.data(:,1);
        else
            spiketimes = [];
        end
        trigs = odorTriggers{day}{ep}.allTriggers;
        trigs = [trigs,trigs+1];
        
        for t = 1:size(trigs,1)
            trigspikes = spiketimes(isExcluded(spiketimes, trigs(t,:)));
            trigspikes = trigspikes - trigs(t,1);
            trignum = trignum +1;
            mat = [repmat(trignum,length(trigspikes),1),trigspikes];
            n(c).data = [n(c).data; mat];
        end
        
    end
    
end
trials = trignum;
tottime = win*1000;
%bintime = 10;
dat = zeros(numcells,1,trials,tottime/bintime); %preallocate data matrix

%Parse into trials, digitize spike times into bins of 0s,1s
for i = 1:numcells
    for j = 1:trignum
        x = ceil(1000/bintime*n(i).data(find(n(i).data(:,1) == j),2));
        x(find(x==0))=[]; %remove zeros... should be unlikely but it will cause error
        
        if x < tottime+1
            dat(i,1,j,x) = 1;
        end
    end
end

%Combine all spikes into 1 array, (some loss of simultaneous spikes)
%where spikes from unit 1 are marked with '1', spikes from unit 2 = '2' ...
for i = 1:numcells
    dat(i,:,:,:) = dat(i,:,:,:)*i;
end 
placeholder = 1;
if numcells > 1
    for i = 1:placeholder
        for j = 1:trials
            for k = 1:tottime/bintime
                temp = find(dat(:,i,j,k) > 0); 
                if temp
                    temp2 = randperm(length(temp)); 
                    newdat(i,j,k) = squeeze(dat(temp(temp2(1)),i,j,k));
                else
                    newdat(i,j,k) = 0;
                end
            end
        end
    end
end 
 
hmmdat = newdat + 1; %Data entered into HMMtrain cannot contain zeros 