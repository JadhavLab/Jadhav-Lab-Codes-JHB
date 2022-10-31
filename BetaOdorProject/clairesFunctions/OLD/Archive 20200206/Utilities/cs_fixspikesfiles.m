%this function is for fixing spikes files from MountainSort- sometimes it
%separates epochs incorrectly. This function anneals epochs that were
%incorrectly separated.

%combined epochs will be combined into first one, i.e if 1 and 2 are to be
%combined, they will become the new epoch 1, and all other epochs will be
%shifted backwards

clear
animal = 'CS33';
topDir = cs_setPaths();
animDir = [topDir,animal,'Expt\',animal,'_direct\'];

day = 4;
epochsToCombine = [1,2];
%%

daystr = getTwoDigitNumber(day);
oldspikes = loaddatastruct(animDir, animal, 'spikes',day);
oldepochs = 1:length(oldspikes{day});
copy = find(oldepochs < epochsToCombine(1));
shift = find(oldepochs > epochsToCombine(2));

if ~isempty(copy)
    newspikes{day}(copy(1):copy(end)) = oldspikes{day}(copy(1):copy(end));
end
if ~isempty(shift)
    newspikes{day}(2:3) = oldspikes{day}(shift(1):shift(end));
end

newspikes{day}{epochsToCombine(1)} = cell(1,32);

ep1 = oldspikes{day}{epochsToCombine(1)};
ep2 = oldspikes{day}{epochsToCombine(2)};

tets = find(~cellfun(@isempty, ep1));

filt = '~isempty($data)';
goodcells1 = evaluatefilter(ep1,filt);
goodcells2 = evaluatefilter(ep2,filt);
both = intersect(goodcells1,goodcells2,'rows');

timerange = [ep1{both(1,1)}{both(1,2)}.timerange(1), ep2{both(1,1)}{both(1,2)}.timerange(2)];

for t = tets
    cells = 1:length(ep1{t});
    
    for c= 1:length(cells)
          
        ep1data = ep1{t}{c};
        ep2data = ep2{t}{c};
        
        alldata = {ep1data,ep2data};
        chk = ~cellfun(@isempty,alldata);
        
        if sum(chk) == 0 
            newspikes{day}{epochsToCombine(1)}{t}{c} = [];
            continue
        elseif sum(chk) == 1
           goodep = find(chk,1,'first') ;
           
           data = alldata{goodep}.data;
           meanrate = alldata{goodep}.meanrate;
           descript = alldata{goodep}.descript;
           fields = alldata{goodep}.fields;
           tag = alldata{goodep}.tag;
           peak_amplitude = alldata{goodep}.peak_amplitude;
           
        else
            data = [alldata{1}.data; alldata{2}.data];
            meanrate = alldata{1}.meanrate;
            descript = alldata{1}.descript;
            fields = alldata{1}.fields;
            tag = alldata{1}.tag;
            peak_amplitude = alldata{1}.peak_amplitude; 
        end
        
        newsp.data = data;
        newsp.meanrate = meanrate;
        newsp.descript = descript;
        newsp.fields = fields;
        newsp.tag = tag;
        newsp.peak_amplitude = peak_amplitude;
        newsp.timerange = timerange;
        
        newspikes{day}{epochsToCombine(1)}{t}{c} = newsp;
    end
    
    
end
spikes = newspikes;
save([animDir,animal,'spikes',daystr],'spikes')