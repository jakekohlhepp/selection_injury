clear all
cap log close
set type double
log using log/01_10_instrument_check.log, replace
set more off
set scheme cleanplots

* Purpose: check instrument relevance and independence
use data/01_01_estimation_sample, clear
keep if has_datevar==1

**** relevance - lpms with f-tests
cap eststo clear
eststo: reg work bar_* adj_div_8_leave_count , cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "No"
estadd local hasmonth "No"
estadd local hasdate "No"
eststo: reg work bar_* adj_div_8_leave_count  an_age max_rate seniority_rank, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "No"
estadd local hasmonth "No"
estadd local hasdate "No"
eststo: reg work bar_* adj_div_8_leave_count  an_age max_rate seniority_rank i.grouped_div, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasmonth "No"
estadd local hasdate "No"
eststo: reg work bar_* adj_div_8_leave_count  an_age max_rate seniority_rank i.grouped_div i.month i.dayofweek, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasmonth "Yes"
estadd local hasdate "No"
eststo: reg work bar_* adj_div_8_leave_count  an_age max_rate seniority_rank i.grouped_div i.analysis_workdate, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasmonth "No"
estadd local hasdate "Yes"
esttab est1 est2 est3 est4 est5  using out/1_10_relevance.tex, se star(* 0.10 ** 0.05 *** 0.01) keep(adj_div_8_leave_count an_age max_rate seniority_rank) scalars("fs First-Stage F." "hasdiv Division FE" "hasmonth Month/Day of Week FE" "hasdate Date FE") nodepvar replace nomtitles label

*** balance tests
replace medpd=0 if matched_injury==1 & missing(medpd)
cap eststo clear
eststo: reg medpd adj_div_8_leave_count an_age max_rate seniority_rank if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "No"
estadd local hasmonth "No"
estadd local hasdate "No"
eststo: reg medpd adj_div_8_leave_count an_age max_rate seniority_rank if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "No"
estadd local hasmonth "No"
estadd local hasdate "No"
eststo: reg medpd adj_div_8_leave_count an_age max_rate seniority_rank i.grouped_div if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasmonth "No"
estadd local hasdate "No"
eststo: reg medpd adj_div_8_leave_count an_age max_rate seniority_rank i.grouped_div i.month if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasmonth "Yes"
estadd local hasdate "No"
eststo: reg medpd adj_div_8_leave_count  an_age max_rate seniority_rank i.analysis_workdate if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasmonth "No"
estadd local hasdate "Yes"
esttab est1 est2 est3 est4 est5  using out/1_10_balance.tex, se star(* 0.10 ** 0.05 *** 0.01) keep(adj_div_8_leave_count an_age max_rate seniority_rank) scalars("fs First-Stage F." "hasdiv Division FE" "hasmonth Month FE" "hasdate Date FE") nodepvar replace nomtitles label


****
log close

