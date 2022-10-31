%function cs_selectivityTag(cellinfo, cellind, spikes, lefttrigs, righttrigs, win, iterations)

%combine spiketimes across run epochs
%combine trig times across run epochs

%tag cells with selectivity index #, then can find these cells again and
%plot.
clear
topDir = cs_setPaths;

animals = {'CS31','CS33','CS34','CS35','CS39','CS41','CS42','CS44'};

regions = {'CA1','PFC'};
%win = [0 1];
iterations = 1000;
learningtypes = {'prelearn','postlearn'};

%winsize = win(2) + win(1);

for r = 1:length(regions)
    region = regions{r};
    npCellsSelectivity = []; inds =[];
    i_npCellSelectivity = [];
    
    load([topDir,'AnalysesAcrossAnimals\npCells_novel_',region,'.mat']);
    
    for l = 1:length(learningtypes)
        learning = learningtypes{l};
        
        for a = 1:length(animals)
            animal = animals{a};
            animDir = [topDir, animal, 'Expt\',animal,'_direct\'];
            
            load([animDir,animal,'cellinfo.mat'])
            
            %Remove existing tags
            lcellfilt = ['novelLeftSelective'];
            rcellfilt = ['novelRightSelective'];
            filt = ['strcmp($area, ''',region,''') && (strcmp($selectivity_', learning,', ''',lcellfilt,''') || strcmp($selectivity_',learning,', ''',rcellfilt,''')) '];
            old = evaluatefilter(cellinfo,filt);
            
            for f = 1:size(old,1)
                cell = old(f,:);
                if isfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)},['selectivity_',learning])
                    cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)} = rmfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)}, ['selectivity_',learning]);
                end
                if isfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)},['SI_',learning])
                    cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)} = rmfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)}, ['SI_',learning]);
                end
                if isfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)},'selectivity')
                    cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)} = rmfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)}, 'selectivity');
                end
                if isfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)},'SI')
                    cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)} = rmfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)}, 'SI');
                end
            end
            
            %         filt = ['(~isempty($SI))'];
            %         test = evaluatefilter(cellinfo,filt);
            %          for f = 1:size(test,1)
            %             cell = test(f,:);
            %             if isfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)},'SI')
            %                 cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)} = rmfield(cellinfo{cell(1)}{cell(2)}{cell(3)}{cell(4)}, 'SI');
            %             end
            %         end
            %
            cells = npCells(npCells(:,1) ==  a,[2,3,4]);
            
            %         filt = ['isequal($area,''',region,''') && strcmp($tag, ''accepted'')'];
            %         singleunit = evaluatefilter(cellinfo,filt);
            %
            %         cells = intersect(cells, singleunit(:,[1 3 4]),'rows');
            
            days = unique(cells(:,1));
            for d = 1:length(days)
                day = days(d);
                daystr = getTwoDigitNumber(day);
                
                daycells = cells(cells(:,1) == day,:);
                
                load([animDir,animal,'spikes',daystr,'.mat'])
                load([animDir,animal,'odorTriggers',daystr,'.mat'])
                load([animDir, animal,'nosepokeWindow',daystr,'.mat'])
                
                runeps1 = cs_getRunEpochs(animDir, animal, 'novelodor',day);
                runeps2 = cs_getRunEpochs(animDir, animal, 'novelodor2',day);
                runeps = unique([runeps1(:,2);runeps2(:,2)]);
                
                %runeps = find(~cellfun(@isempty,nosepokeWindow{day}));
                
                
                trigs_all= []; correct_left_all = []; correct_right_all = [];
                for ep = 1:length(runeps)
                    epoch = runeps(ep);
                    
                    [correct_left, correct_right, ~, ~] = cs_getSpecificTrialTypeInds_learning(odorTriggers{day}{epoch},learning);
                    %trigs = odorTriggers{day}{epoch}.allTriggers;
                    npwins = nosepokeWindow{day}{epoch};
                    
                    correct_left_all = [correct_left_all; npwins(correct_left,:)];
                    correct_right_all = [correct_right_all; npwins(correct_right,:)];
                    trigs_all = [trigs_all ; npwins];
                    
                end
                
                frallcellsL = []; frallcellsR = [];
                for c = 1:size(daycells,1)
                    
                    leftspikes = [];
                    rightspikes = [];
                    leftfr = [];
                    rightfr = [];
                    
                    cell = daycells(c,:);
                    
                    runspikes = [];
                    
                    for ep = 1:length(runeps)
                        epoch = runeps(ep);
                        
                        if ~isempty(spikes{cell(1)}{epoch}{cell(2)}{cell(3)}.data)
                            runspikes = [runspikes; spikes{cell(1)}{epoch}{cell(2)}{cell(3)}.data(:,1)];
                        end
                        
                        
                    end
                    
                    for t = 1:length(correct_left_all)
                        %trig = correct_left_all(t);
                        trigwin = [correct_left_all(t,1), correct_left_all(t,2)];
                        winspikes =sum(runspikes > trigwin(1) & runspikes <= trigwin(2));
                        %bins = (trig-win(1):binsize:trig+win(2));
                        %binspikecount = histcounts(winspikes,bins);
                        fr = winspikes/(trigwin(2) - trigwin(1));
                        leftspikes = [leftspikes; winspikes];
                        leftfr = [leftfr; fr];
                    end
                    
                    for t = 1:length(correct_right_all)
                        %trig = correct_right_all(t);
                        trigwin = [correct_right_all(t,1), correct_right_all(t,2)];
                        winspikes = sum(runspikes > trigwin(1) & runspikes <= trigwin(2));
                        %bins = (trig-win(1):binsize:trig+win(2));
                        %binspikecount = histcounts(winspikes,bins);
                        fr = winspikes/(trigwin(2) - trigwin(1));
                        rightspikes = [rightspikes; winspikes];
                        rightfr = [rightfr; fr];
                    end
                    
                    
                    sumspikes = sum([leftspikes; rightspikes]);
                    
                    if sumspikes >= length(trigs_all)
                        meanleftfr = mean(leftfr);
                        meanrightfr = mean(rightfr);
                        
                        
                        selectivity = (meanleftfr - meanrightfr)/(meanleftfr + meanrightfr);
                        
                        
                        
                        %do the shuffle
                        
                        leftones = ones(size(leftspikes,1),1);
                        rightzeros = zeros(size(rightspikes,1),1);
                        
                        indicators = [leftones;rightzeros];
                        allTrials = [leftfr; rightfr];
                        
                        shuffIndexDist = zeros(iterations,1);
                        for i = 1:iterations
                            shuffledRL = indicators(randperm(length(indicators)));
                            newLeft = mean(allTrials(shuffledRL == 1));
                            newRight = mean(allTrials(shuffledRL == 0));
                            
                            newIndex = (newLeft - newRight)/(newLeft + newRight);
                            shuffIndexDist(i) = newIndex;
                        end
                        
                        shuffMean = mean(shuffIndexDist);
                        shuffStd = std(shuffIndexDist);
                        
                        trueIndexZ = (selectivity - shuffMean)/shuffStd;
                        
                        
                        
                        for e = 1:length(runeps)
                            epoch = runeps(e);
                            if length(cellinfo{cell(1)}{epoch}{cell(2)}) >= cell(3)
                                if trueIndexZ >= 1.5
                                    
                                    cellinfo{cell(1)}{epoch}{cell(2)}{cell(3)}.(['selectivity_',learning]) = 'novelLeftSelective';
                                    
                                elseif trueIndexZ <= -1.5
                                    cellinfo{cell(1)}{epoch}{cell(2)}{cell(3)}.(['selectivity_',learning]) = 'novelRightSelective';
                                    
                                end
                                cellinfo{cell(1)}{epoch}{cell(2)}{cell(3)}.(['SI_',learning]) = selectivity;
                            end
                        end
                    end
                    
                end
            end
            save([topDir,animal,'Expt\',animal,'_direct\',animal,'cellinfo.mat'],'cellinfo');
        end
    end
end

cs_listSelectiveCells_novel