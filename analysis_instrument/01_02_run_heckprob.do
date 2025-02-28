clear all
cap log close
set type double
log using log/01_02_run_heckprob.log, replace
set more off
set scheme cleanplots


********* RUN MAIN ANALYSIS
use data/01_01_estimation_sample, clear
eststo: heckprobit matched_injury bar_adj_div_8_leave_count bar_max_rate  an_age max_rate seniority_rank i.analysis_workdate i.grouped_div if has_datevar==1, select(work =  bar_adj_div_8_leave_count bar_max_rate  adj_div_8_leave_count  an_age max_rate seniority_rank i.analysis_workdate i.grouped_div) vce(cluster empid)
estimates save out/01_02_heckprob_results.ster, replace
* mark sample
summarize work if e(sample)
gen sample_marked = e(sample)
assert sample_marked==1 if has_datevar==1

save data/01_01_estimation_sample, replace
*******
log close