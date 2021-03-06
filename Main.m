%%%%% ====== Pattern Recognition Techniques ===== %%%%%
%%%%% ===== Alexandre Sayal | Sara Oliveira ===== %%%%%
%%%%% =================== 2015 ================== %%%%%
%%%%% ============ Project Main Script ========== %%%%%

%% Import Data
clear, clc;

load higgs_data.mat;

[rawlabels,eventID,rawcolumn_names,rawdata] = dataimport( higgs_data_for_optimization , column_names);

clear higgs_data_for_optimization;

%% Balance between decay and background events
tbl = tabulate(rawlabels);

figure();
    h = pie(tbl(:,3));
    hp = findobj(h, 'Type', 'patch');
    set(hp(1), 'FaceColor', [0 0.4470 0.7410]); set(hp(2), 'FaceColor', [0.8500 0.3250 0.0980]);
    title('Class distribution of original data');
    legend('Decay','Background');

clear tbl h hp;

%% New datasets
data = rawdata;
labels = rawlabels;
column_names = rawcolumn_names;

%% Cross Validation
% Partition the data into training set and test set.
% The training set will be used to calibrate/train the model parameters.
% The trained model is then used to make a prediction on the test set.

data_to_use = data;

% Hold 25% of the data, selected randomly, for test phase.
cv = cvpartition(length(data_to_use),'holdout',0.25);

%---Training set
Xtrain = data_to_use(cv.training(1),:);
Ytrain = labels(cv.training(1),:);
%---Test set
Xtest = data_to_use(cv.test(1),:);
Ytest = labels(cv.test(1),:);

%---Display class distribuition
disp('Training Set:')
tabulate(Ytrain)
disp('Test Set:')
tabulate(Ytest)

%% Missing values - Train and Test
method = {'mean','mode','removeevents','removefeatures'};

[ MVXtrain , MVYtrain , MVXtest , MVYtest, MVcolumn_names , ~,MVcolumn_indexes] ...
    = missingvalues( Xtrain , Ytrain , Xtest , Ytest , column_names, method{4} );

clear method;

%% Normalization
[normtrain , m , sigma ] = scalestd(MVXtrain);
normtest = scalestd(MVXtest,m,sigma);

%% Feature Selection
option = 1;

switch option
%----Kruskal-Wallis----%
    case 1
        threshold = 10; %---Number of features desired based on chi2 values
        [FSdata , FScolumn_names , FSfeatures] = FS_kruskal( normtrain , MVYtrain , MVcolumn_names , threshold );
        FStestdata = normtest(:,FSfeatures);
        
%----Correlation between features----%   
    case 2
        threshold = 0.80; %---Correlation cut-off value
        [FSdata , FScolumn_names , FSfeatures] = FS_corr( normtrain , MVYtrain , MVcolumn_names , 'feat' , threshold);
        FStestdata = normtest(:,FSfeatures);
        
%----Correlation between features and labels----% 
    case 3
        threshold = 0.10; %---Correlation cut-off value
        [FSdata , FScolumn_names , FSfeatures] = FS_corr( normtrain , MVYtrain , MVcolumn_names , 'featlabel' , threshold);
        FStestdata = normtest(:,FSfeatures);
        
%----mRMR----% 
    case 4
        threshold = 15; %---Number of features desired
        [FSdata , FScolumn_names , FSfeatures] = FS_mRMR( normtrain , MVYtrain , MVcolumn_names , threshold );
        FStestdata = normtest(:,FSfeatures);
        
%----Area under curve----% 
    case 5
        threshold = 0.5; %---AUC cut-off value
        [FSdata , FScolumn_names , FSfeatures] = FS_AUC( normtrain , MVYtrain , MVcolumn_names , threshold );
        FStestdata = normtest(:,FSfeatures);
        
%----Fisher Score----% 
    case 6
        threshold = 14; %---Number of features desired
        [FSdata , FScolumn_names , FSfeatures] = FS_fisher(normtrain , MVYtrain , MVcolumn_names, threshold ); 
        FStestdata = normtest(:,FSfeatures);
        
end

clear option threshold;

%% Feature Selection Comparison Graph
x = ones(7,length(MVcolumn_indexes));
x(1,:) = 1:length(MVcolumn_indexes);

[~ , ~ , kruskal_f] = FS_kruskal( normtrain , MVYtrain , MVcolumn_names , 15 );
[~ , ~ , corr_f1] = FS_corr( normtrain , MVYtrain , MVcolumn_names , 'feat' , 0.01);
[~ , ~ , corr_f2] = FS_corr( normtrain , MVYtrain , MVcolumn_names , 'featlabel' , 0.03);
[~ , ~ , mrmr_f] = FS_mRMR( normtrain , MVYtrain , MVcolumn_names , 15 );
[~ , ~ , auc_f] = FS_AUC( normtrain , MVYtrain , MVcolumn_names , 0.55 );
[~ , ~ , fisher_f] = FS_fisher(normtrain , MVYtrain , MVcolumn_names, 15 );

x(2,kruskal_f) = 0;
x(3,corr_f1) = 0;
x(4,corr_f2) = 0;
x(5,mrmr_f) = 0;
x(6,auc_f) = 0;
x(7,fisher_f) = 0;
figure();
colormap bone
imagesc(x(1,:),1:6,x(2:7,:));
title('Comparison of the features selected by the 6 methods')
xlabel('Features');
set(gca,'ygrid', 'on', 'gridlinestyle', '-', 'ycolor', 'k');
set(gca, 'YTick', 1:6, 'YTickLabel', ...
    {'Kruskal-Wallis','F Correlation','FL Correlation','mRMR','AUC','Fisher Score'},...
    'XTick',x(1,:),'XTickLabel',num2cell(MVcolumn_indexes));

%% Feature Reduction

%----Create Structure----%
FRdataTemp.X = normtrain';
FRdataTemp.y = MVYtrain';
FRdataTemp.dim = size(FRdataTemp.X,1);
FRdataTemp.num_data = size(FRdataTemp.X,2);

option = 2;

switch option
%----PCA----%
    case 1
        threshold = 0.40; %---Percentage of Eigenvalues to keep
        [ FRdata , W ] = FeatureReduction( FRdataTemp , 'pca' , threshold );
        FRtestdata = FStestdata*W;
        
%----LDA----%        
    case 2
        threshold = 1; %---Number of features desired
        [ FRdata , W ] = FeatureReduction( FRdataTemp , 'lda' , threshold );
        FRtestdata = normtest*W;
end

FRdata = FRdata';

clear option FRdataTemp threshold;

%% Classification

Ctrain = FRdata;
Ctest = FRtestdata;

class = {'bayes','fld','linsvm','libsvm','kNN','mindist'};
selected = class{1};

switch selected
    case 'bayes'
        %%---Bayes Classifier
        nfold = 10;
        type = {'df','cls'}; stype = 1;
        [ CL_bayes_performance , CL_bayes_model ] = ...
            CL_bayes( Ctrain , MVYtrain , Ctest , MVYtest , type{stype} , nfold);

    case 'fld'
        %%---FLD Classifier
        nfold = 10;
        type = {'linear','quad'}; stype = 1;
        [ CL_fld_performance , CL_fld_model ] = ...
            CL_fld( Ctrain , MVYtrain , Ctest , MVYtest , type{stype} , nfold );
        
    case 'linsvm'
        %%---SVM with LibLINEAR
        nfold = 10;
        C = -16:2:16;
        [ CL_linsvm_performance , CL_linsvm_model ] = ...
            CL_linSVM( Ctrain , MVYtrain , Ctest, MVYtest , C , nfold);
     
    case 'libsvm'
        %%---SVM with LibSVM
        nfold = 10;
        C = -5:2:15;
        gamma = -10:2:5;
        limit = 1000; % Limit the number of events
        [ CL_libsvm_performance , CL_libsvm_model ] = ...
            CL_libSVM( Ctrain , MVYtrain , Ctest, MVYtest , C , gamma , nfold, limit);
        
    case 'kNN'
        %%---kNN
        nfold = 10;
        K = 20:40;
        limit = 1000; % Limit the number of events. Set zero for no limit
        [ CL_kNN_performance , CL_kNN_model ] = ...
            CL_kNN( Ctrain , MVYtrain , Ctest, MVYtest , K , nfold, limit);
       
    case 'mindist'
        %%---Minimum Distance
        [ CL_mindist_performance , CL_mindist_m1 , CL_mindist_m2 ] = ...
            CL_mindist( Ctrain , MVYtrain , Ctest, MVYtest );

end