%% Import data from text file
% Script for importing data from the following text file:
%
%    filename: F:\JayAndAudrey\log01-13-2020(15_36_00)AH6_3.stateScriptLog
%
% Auto-generated by MATLAB on 14-Jan-2020 10:20:42

%% Setup the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 2);

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = "#";

% Specify column names and types
opts.VariableNames = ["VarName1", "W_Maze_variant_reward_middleRewardHeavy_use8sc"];
opts.VariableTypes = ["string", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["VarName1", "W_Maze_variant_reward_middleRewardHeavy_use8sc"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["VarName1", "W_Maze_variant_reward_middleRewardHeavy_use8sc"], "EmptyFieldRule", "auto");

%%

% Import the data
%myfilenames={'F:\JayAndAudrey\log01-13-2020(15_36_00)AH6_3.stateScriptLog'};
% or use dir

mydir=uigetdir;
%%

filelist = dir(fullfile(mydir, '**\*.*'));  %get list of files and folders in any subfolder

okfiles=cellfun(@(a) contains(a,'stateScriptLog'),{filelist.name});
filelist = filelist(okfiles);
% now get the rat and date
for i=1:length(filelist)
    namesep=find(filelist(i).name=='_');
    filelist(i).rundate=datenum(filelist(i).date);
    filelist(i).ratname=filelist(i).name(namesep(1)+1:namesep(2)-1);
    filelist(i).sessnum=filelist(i).name(find(filelist(i).name=='_',1,'last')+1:...
        strfind(filelist(i).name,'.')-1);
    %filelist(i).datenum=datenum(filelist(i).rundate);
end

% now sort, first by session, then by date then by rat, this will make rat
% the top sorting category


ratinfo=filelist;
% we can interchange tables and structs easily
ratinfo=sortrows(struct2table(filelist),{'ratname','datenum','sessnum'});
% now for ease here im going to put it into a struct
ratinfo=table2struct(ratinfo);

verbose=1;
%%
for i=1:length(ratinfo)
    fprintf(' \n \n');
    fprintf('Running  %s %s %s \n',ratinfo(i).date, ratinfo(i).ratname, ratinfo(i).sessnum);
    DataFile = readtable(fullfile(ratinfo(i).folder,ratinfo(i).name), opts);
    % Convert to output type
    DataRaw = table2cell(DataFile);
    numIdx = cellfun(@(x) ~isempty(x{1}), DataRaw(:,1));
    DataTips = DataRaw(numIdx,1);
    
    % convert to char and split out
    DataTips2=cellfun(@(a) char(a{1}), DataTips, 'UniformOutput',false);
    DataAll=cellfun(@(a) a(1:find(a==' ',1,'first')), DataTips2,'UniformOutput',false);
    DataAll(:,2)=cellfun(@(a) a(find(a==' ',1,'first')+1:end), DataTips2,'UniformOutput',false);
    
    ledger=DataAll;
    [myevents,eventlist] = parseTrodesEvents(ledger);
    
    
    % now turn into real time
    
    % it looks like any event in which the next start is less than 1 seconds
    % from the last poke
    shortlag=2; % guess that the short lag is like 2 seconds

    % so every event that has a past event thats really recent, kill it,
    eventlags=diff(linearize(myevents(:,1:2)')); % get time lags between events
    returnevents=[1; diff(myevents(:,3))==0]; % add a zero (lets consider the first event as a return, its a freebie
    eventlags=[shortlag+1; eventlags(2:2:length(eventlags))]; % this is list of last end to this start
    shortlag=min(eventlags(returnevents==0)); % get min time for a real run
    realevents=myevents(eventlags>shortlag & ~returnevents,:); % kill all returns shorter than that
    realevents(:,5)=[nan; realevents(1:end-1,3)]; % tack previous arm on to the end
    realevents=realevents(2:end,:); % remove first trial, it doesnt count!
    % vestigial, was for when we took return visits
    armtrans=table(realevents(:,1),realevents(:,2),realevents(:,3),realevents(:,4),...
        realevents(:,5),'VariableNames',{'departure','arrival','thisArm','isRewarded',...
        'lastArm'});
    if verbose
        % make a huge plot here
        % on left y maybe a moving average of total success rate
        figure;
        plot(movsum(armtrans.isRewarded,5)/5,'k');
        hold on;
        % inbound performance is what % of times that he leaves an outer
        % arm does he go to the center arm. 
        % now rewards per each side
        plot(cumsum(armtrans.isRewarded==1 & armtrans.lastArm~=2)./cumsum(armtrans.lastArm~=2),'r'); % %%of leaving sides
        hold on;
        
        plot(cumsum(armtrans.isRewarded==1 & armtrans.thisArm~=2)./cumsum(armtrans.thisArm~=2),'b'); % %%of entering sides

        % how to calculate a 5 trial moving average of the events? prob nan
        % out middles? and then fill in after?
        plot([0 height(armtrans)],[.5 .5],'r--');
        
        plot((cumsum(armtrans.thisArm==3)-cumsum(armtrans.thisArm==1))./cumsum(armtrans.thisArm~=2)+.5,'m'); % side preference
        legend({'Performance window 5','Center performance cumsum','Side Performance cumsum','chance','cumsum Side preference'});
        title(sprintf('Session \n %s %s %s',ratinfo(i).date, ratinfo(i).ratname, ratinfo(i).sessnum));

    end
    myevents(:,end+1)=i; armtrans.session(:)=i;
    ratinfo(i).samples=myevents;
    ratinfo(i).armvisits=armtrans;
    eventtable=table(realevents(:,1),realevents(:,2),realevents(:,3),realevents(:,4),...
        realevents(:,5),'VariableNames',{'Start','end','arm ID','rewarded','last arm'});
    fprintf(' All rewards are %d, All visits are %d, Arm transitions are %.f%% of all %.2f second runs \n',...
        sum(realevents(:,4)==1), size(realevents,1), nanmean(realevents(:,3)~=realevents(:,5))*100,shortlag); % basically when the diff==0

    % when he leaves a side arm
    fprintf('NOT including return visits, %.f%% of %d side arm departures correct \n',...
      nanmean(armtrans.isRewarded(armtrans.lastArm~=2)==1)*100, sum(armtrans.lastArm~=2));

    % when he leaves the center arm
    fprintf('NOT including return visits, %.f%% of %d side arm approaches correct \n',...
      nanmean(armtrans.isRewarded(armtrans.thisArm~=2)==1)*100, sum(armtrans.thisArm~=2));
    ylim([0 1]);
end

%% and ask the date that the animals switched
switchdate={'18-Feb-2020'}; % for ah 1 and 2
switchdate{2}='22-Jan-2020'; % for ah3 and 6
 

for i=1:length(ratinfo)
    if contains(ratinfo(i).ratname,'AH1') || contains(ratinfo(i).ratname,'AH2')
        ratinfo(i).tasknum=(datenum(ratinfo(i).rundate)>=datenum(switchdate{1}))+1;
    else
          ratinfo(i).tasknum=(datenum(ratinfo(i).rundate)>=datenum(switchdate{2}))+1;
    end
end

%% and now we test these sessions

plotIt=0;

[rats,~,ratinds]=unique({ratinfo.ratname});
[tasks,~,taskinds]=unique(cell2mat({ratinfo.tasknum}));

bmodes={}; bmodec={}; b95s={}; b95c={}; b05s={}; b05c={};
pmatrixs={}; pmatrixc={}; trialCritC={}; trialCritS={};
sidect={}; centct={};
for i=1:length(rats)
    for tk=1:max(tasks)
        
        fprintf('running rat %s \n',rats{i});
        
        % alldays is a master matrix of events. The columns are as follows:
        % 1 nosepoke start
        % 2. nosepoke end
        % 3. which arm that poke is at
        % 4. did he get fed?
        % 5. where was the last port?
        % 6. day number
        % 7. run number
        
        %  Task 1 _________       ___________
        %         |   |   |       |    |    |
        %         1   2   3       1    3    2
        
        % after transition, you have to every time it says 2 to say 3, this is
        % because now port 2 is in position 3, and port 3 is in position 2
        
        % we'll have to put in the new positions (post switch) as new columns
        % in this matrix
        
        % so there end up being a small number of rewarded trials where the
        % animal does the wrong thing, we need to examine this further, but not
        % yet
        
        alldays=cell2mat({ratinfo(ratinds==i & taskinds==tk).armvisits}');
        alldays(:,end+1)=1:size(alldays,1);
        % past port was center
        leavingcenter=alldays(alldays(:,5)==2,:); % leaving center
        % past port was an outside port
        leavingsides=alldays(alldays(:,5)~=2,:); % e.g. him leaving the sides
        
        rightvisits=alldays(alldays(:,3)==1,:);
        leftvisits=alldays(alldays(:,3)==2,:);
        
        [~,~,alldays(:,6)]=unique(alldays(:,6)); % reorder the days
        
        %{
    figure;
    plot(centervisits(:,7),SmoothMat2(movsum(centervisits(:,4),10)/10,[1 30],3),'--.');
    hold on;
    plot(sidevisits(:,7),SmoothMat2(movsum(sidevisits(:,4),10)/10,[1 30],3),'--.');
    plot([0 max([length(centervisits) max(sidevisits(:,7))])],[.5 .5],'r');
    legend('Inbound performance','Outbound performance');
    title(sprintf('10 trial moving average, %s ',rats{i}));
        %}
        %  now the statespace model
        
        
        % leaving sides
        [bmodes{i,tk},b05s{i,tk},b95s{i,tk},pmatrixs{i,tk}] = CalcStateSpacePerformance(leavingsides(:,4)', 0.5);
        trialCritS{i,tk}=leavingsides(find(pmatrixs{i,tk}<.05,1,'first'),7);
        sidect{i,tk}=leavingsides(:,7);
        % leaving center
        [bmodec{i,tk},b05c{i,tk},b95c{i,tk},pmatrixc{i,tk}] = CalcStateSpacePerformance(leavingcenter(:,4)', 0.5);
        trialCritC{i,tk}=leavingcenter(find(pmatrixc{i,tk}<.05,1,'first'),7);
        centct{i,tk}=leavingcenter(:,7);
        if plotIt
            figure; sp=subplot(2,1,1);
            % plot mode, confidence bounds, chance, and session marker
            plot(sp(1),leavingsides(:,7)',bmodesc{i,tk}(1:end-1)); hold on; % mean
            plot(sp(1),leavingsides(:,7),b05s{i,tk}(1:end-1),'r--'); % lower conf
            plot(sp(1),leavingsides(:,7),b95s{i,tk}(1:end-1),'r--'); % upper conf
            plot(sp(1),[0 max(leavingsides(:,7))],[.5 .5],'c'); % chance
            plot(sp(1),find(mod(alldays(:,6),2)==1),0.1*ones(sum(mod(alldays(:,6),2)==1),1),'b.'); % session indicator
            title(sprintf('%s learned task %d center at %d',rats{i},tk,leavingsides(find(pmatrixs{i,tk}<.05,1,'first'),7)));
            xlabel('trial'); ylabel('perf');
            sp(2)=subplot(2,1,2);
            
            
            plot(sp(2),leavingcenter(:,7),bmodecc{i,tk}(1:end-1)); hold on;  % meam
            plot(sp(2),leavingcenter(:,7),b05c{i,tk}(1:end-1),'r--'); % lower conf
            plot(sp(2),leavingcenter(:,7),b95c{i,tk}(1:end-1),'r--'); % upper conf
            plot(sp(2),[0 max(leavingcenter(:,7))],[.5 .5],'c'); % cjamce
            plot(sp(2),find(mod(alldays(:,6),2)==1),0.1*ones(sum(mod(alldays(:,6),2)==1),1),'b.'); % session indicator
            title(sprintf('%s learned task %d side at %d',rats{i}, tk, leavingcenter(find(pmatrixc{i,tk}<.025,1,'first'),7)));
            xlabel('trial'); ylabel('perf');
        end
    end
end
    
%% now to collapse these into a single plot:

figure;
sp=subplot(2,2,1); % center performance, task 1

% first plot each curve in grey, and figure out when they actually achieve
for k=1:4
    critreached=find(b05s{k,1}>.5,1,'first');
    if  isempty(critreached), critreached=1; end
    plot(sidect{k,1}(1:critreached),bmodes{k,1}(1:critreached),':','Color',[.5 .5 .5]); hold on;
    plot(sidect{k,1}(critreached:end),bmodes{k,1}(critreached:end-1),'-','Color',[.5 .5 .5]);
end

% aggregate trial and performance leaving sides (s)
lastTr=min(cellfun(@(a) length(a), sidect(:,1))); % shortest session
% get all the mode performances, concatenate together
bmodes1=cell2mat(cellfun(@(a) a(1:lastTr), bmodes(:,1), 'UniformOutput', false)');  
% keep track of trial count for each rat (this is catted too)
trcts=cell2mat(cellfun(@(a) a(1:lastTr), sidect(:,1), 'UniformOutput', false));
% accumarray and smooth
rawperf=accumarray(trcts, bmodes1',[max(trcts),1],@mean,nan);
meanperfS1=SmoothMat2(rawperf,[1,5],2);
plot(meanperfS1,'b','LineWidth',2); xlim([0 500]); hold on; 
trialCrit=round(mean(cell2mat(trialCritS(:,1))));
critVar=nanstd(rawperf(trialCrit-5:trialCrit+5));
errorbar(trialCrit,meanperfS1(trialCrit),SEM(cell2mat(trialCritS(:,1))),...
    'horizontal','r-x','MarkerSize',4,'LineWidth',1);
errorbar(trialCrit,meanperfS1(trialCrit),critVar,...
    'r-x','MarkerSize',4,'LineWidth',1);
ylabel(sprintf('Inbound Performance \n(easier)')); title('N = 4');
plot([0 500],[.5 .5],'k'); box off;
%legend('Mean Rate','Criterion reached','Chance');


sp(2)=subplot(2,2,2); % center performance, task 2


for k=1:4
    critreached=find(b05s{k,2}>.5,1,'first');
    if  isempty(critreached), critreached=1; end
    li=plot(sidect{k,2}(1:critreached),bmodes{k,2}(1:critreached),':','Color',[.5 .5 .5]); hold on;
    li(2)=plot(sidect{k,2}(critreached:end),bmodes{k,2}(critreached:end-1),'-','Color',[.5 .5 .5]);
end

% aggregate trial and performance
lastTr=min(cellfun(@(a) length(a), sidect(:,2)));
bmodes2=cell2mat(cellfun(@(a) a(1:lastTr), bmodes(:,2), 'UniformOutput', false)');    
trcts=cell2mat(cellfun(@(a) a(1:lastTr), sidect(:,2), 'UniformOutput', false));
% accumarray and smooth
rawperf=accumarray(trcts, bmodes2',[max(trcts),1],@mean,nan);
meanperfC2=SmoothMat2(rawperf,[1,5],2);
li(3)=plot(meanperfC2,'b','LineWidth',2); xlim([0 500]); hold on; 
trialCrit=round(mean(cell2mat(trialCritS(:,2))));
critVar=nanstd(rawperf(trialCrit-5:trialCrit+5));
li(4)=errorbar(trialCrit,meanperfC2(trialCrit),SEM(cell2mat(trialCritS(:,2))),...
    'horizontal','r-x','MarkerSize',4,'LineWidth',1);
errorbar(trialCrit,meanperfC2(trialCrit),critVar,...
    'r-x','MarkerSize',4,'LineWidth',1);
plot([0 500],[.5 .5],'k');
legend(li,'Before Criterion','Individual Rat','Mean Performance','SEM');
%ylabel('Inbound performance (easier)'); title('N = 4');
 box off;

sp(3)=subplot(2,2,3); % center performance, task 2
for k=1:4
    critreached=find(b05c{k,1}>.5,1,'first');
    if  isempty(critreached), critreached=1; end
    li=plot(centct{k,1}(1:critreached),bmodec{k,1}(1:critreached),':','Color',[.5 .5 .5]); hold on;
    li(2)=plot(centct{k,1}(critreached:end),bmodec{k,1}(critreached:end-1),'-','Color',[.5 .5 .5]);
end
% leaving center
lastTr=min(cellfun(@(a) length(a), centct(:,1)));
bmodec1=cell2mat(cellfun(@(a) a(1:lastTr), bmodec(:,1), 'UniformOutput', false)');    
trcts=cell2mat(cellfun(@(a) a(1:lastTr), centct(:,1), 'UniformOutput', false));
% accumarray and smooth
rawperf=accumarray(trcts, bmodec1',[max(trcts),1],@mean,nan);
meanperfC1=SmoothMat2(rawperf,[1,5],2);
li(3)=plot(meanperfC1,'b','LineWidth',2); xlim([0 500]); hold on; 
trialCrit=round(mean(cell2mat(trialCritC(:,1))));
critVar=nanstd(rawperf(trialCrit-5:trialCrit+5));
errorbar(trialCrit,meanperfC1(trialCrit),SEM(cell2mat(trialCritC(:,1))),...
    'horizontal','r-x','MarkerSize',4,'LineWidth',1);
errorbar(trialCrit,meanperfC1(trialCrit),critVar,...
    'r-x','MarkerSize',4,'LineWidth',1);
ylabel(sprintf('Outbound Performance \n(harder)'));
plot([0 500],[.5 .5],'k'); xlabel('Trials in Standard W Maze');  box off;




sp(4)=subplot(2,2,4); % center performance, task 2
for k=1:4
    critreached=find(b05c{k,2}>.5,1,'first');
    if  isempty(critreached), critreached=1; end
    li=plot(centct{k,2}(1:critreached),bmodec{k,2}(1:critreached),':','Color',[.5 .5 .5]); hold on;
    li(2)=plot(centct{k,2}(critreached:end),bmodec{k,2}(critreached:end-1),'-','Color',[.5 .5 .5]);
end
% aggregate trial and performance
lastTr=min(cellfun(@(a) length(a), centct(:,2)));
bmodec2=cell2mat(cellfun(@(a) a(1:lastTr), bmodec(:,2), 'UniformOutput', false)');    
trcts=cell2mat(cellfun(@(a) a(1:lastTr), centct(:,2), 'UniformOutput', false));
% accumarray and smooth
rawperf=accumarray(trcts, bmodec2',[max(trcts),1],@mean,nan);
meanperfS2=SmoothMat2(rawperf,[1,5],2);
li(3)=plot(meanperfS2,'b','LineWidth',2); xlim([0 500]); hold on; 
trialCrit=round(mean(cell2mat(trialCritC(:,2))));
critVar=nanstd(rawperf(trialCrit-5:trialCrit+5));
errorbar(trialCrit,meanperfS2(trialCrit),SEM(cell2mat(trialCritC(:,2))),...
    'horizontal','r-x','MarkerSize',4,'LineWidth',1);
errorbar(trialCrit,meanperfS2(trialCrit),critVar,...
    'r-x','MarkerSize',4,'LineWidth',1);
plot([0 500],[.5 .5],'k');
xlabel('Trials in ''Switch'' Task');
linkaxes(sp); box off;

%% messing around here








