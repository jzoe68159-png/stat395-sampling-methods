/* =========================================  
Import data set "Hypertension data.csv" to SAS  
========================================= */  
proc import datafile="/home/u63523225/sasuser.v94/Assignment STAT395/Hypertension data.csv"
	out=work.mydata dbms=csv replace;  
	getnames=yes;  
run; 

/* =========================================  
Setup Dataset:  
mydata Variables:  
- HypertensionBinary (defined below)  
- currentSmoker (stratification)  
- Age (cluster) Seed: 202503  
========================================= */ 

/* Create comprehensive binary variable for hypertension */  
data mydata2;  
	set mydata;  
	HypertensionBinary = (sysBP >= 140 or diaBP >= 90 or BPMeds = 1); 

/* Label Smoking Status for reporting */ 
	if currentSmoker = 0 then SmokerLabel = 'Non-Smoker'; 
	else SmokerLabel = 'Smoker'; 
run; 

/* Sort dataset by Age to ensure clusters are heterogeneous */  
proc sort data=mydata2  
	out=mydata_sorted;  
	by Age;  
run; 

/* Macro variables for sample sizes and seed */  
	%let seed = 202503;  
	%let n_srs = 400; /* SRS sample size */  
	%let n_strat = 200; /* per stratum */  
	%let n_cluster = 5; /* number of clusters */ 

/* ========================================= 

Simple Random Sampling (SRS) 

========================================= */  

title "SRS Sample - Hypertension"; 

proc surveyselect data=mydata2 out=srs_sample method=srs /* WOR */  
	sampsize=&n_srs seed=&seed reps=1 /* 1 sample */  
	stats;  
run; 

proc surveymeans data=srs_sample mean clm sum clsum;  
	var HypertensionBinary cigsPerDay;  
run; 

/* =========================================  
2. SRS With Replacement  
========================================= */  

title "SRS With Replacement Sample - Hypertension"; 

proc surveyselect data=mydata2 out=srs_wr_sample  
	method=urs /* WR */  
	sampsize=&n_srs seed=&seed  
	stats; 
run; 

proc surveymeans data=srs_wr_sample mean clm sum clsum;  
	var HypertensionBinary cigsPerDay;  
run; 

/* =========================================  
3. Stratified Sampling by Smoking Status ========================================= */  

title "Stratified Sample by Smoking Status - Hypertension"; 

/* Sort data in ascending order before stratification */ 
proc sort data=mydata2;  
	by currentSmoker;  
run; 

proc surveyselect data=mydata2 out=strat_sample  
	method=srs  
	samprate=0.0472 /* ~4.72% from each stratum */  
	seed=&seed  
	stats;  
	strata currentSmoker;  
run; 

proc surveymeans data=strat_sample mean clm sum clsum;  
	var HypertensionBinary cigsPerDay;  
	strata currentSmoker;  
run; 

/* =========================================  
4. Cluster Sampling by Age  
 ========================================= */  

/* 1. Check age distribution */  
proc univariate data=mydata2;  
	var Age;  
run; 

/* 2. Create 5 roughly equal-sized age bands */  
proc rank data=mydata2 out=mydata2_ageband groups=5;  
	var Age;  
	ranks AgeBandRank;  
run; 

data mydata2_ageband;  
	set mydata2_ageband;  
	AgeGroup = AgeBandRank + 1; /* Make groups 1–5 instead of 0–4 */  
run; 

/* 3. See how many people are in each band */  
proc freq data=mydata2_ageband;  
	tables AgeGroup;  
run; 

/* 4. Present the max and mins of each age band */  
proc means data=mydata2_ageband min max;  
	class AgeGroup;  
	var Age;  
run; 

/* 5. Label Age Groups */  
data mydata2_ageband;  
	set mydata2_ageband; 
	length AgeGroupLabel $10; 
	if AgeGroup = 1 then AgeGroupLabel = '32-41'; 
	else if AgeGroup = 2 then AgeGroupLabel = '42-46'; 
	else if AgeGroup = 3 then AgeGroupLabel = '47-51'; 
	else if AgeGroup = 4 then AgeGroupLabel = '52-58'; 
	else if AgeGroup = 5 then AgeGroupLabel = '59-70'; 
 run; 

/* Check the new labels */  
proc freq data=mydata2_ageband;  
	tables AgeGroupLabel;  
run; 

title "Cluster Sample by Age Group - Hypertension & Cigarettes"; 

proc surveyselect data=mydata2_ageband out=cluster_sample  
	method=srs /* SRS to select clusters */  
	sampsize=&n_cluster  
	seed=&seed  
	stats;  
	cluster AgeGroupLabel; /* Cluster by labeled age groups */  
run; 

proc surveymeans data=cluster_sample mean clm sum clsum;  
	var HypertensionBinary cigsPerDay;  
	cluster AgeGroupLabel;  
run; 

title; /* reset title */ 