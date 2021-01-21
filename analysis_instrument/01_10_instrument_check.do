clear all
cap log close
set type double
log using log/01_10_instrument_check.log, replace
set more off
set scheme cleanplots

* Purpose: check instrument relevance and independence
use data/01_01_estimation_sample, clear

**** relevance - lpms with f-tests
cap eststo clear
eststo: reg work bar_* adj_count_any_leave lag_first_contact seniority_rank, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "No"
estadd local hasday "No"
estadd local hasmonth "No"
eststo: reg work bar_* adj_count_any_leave lag_first_contact seniority_rank max_rate, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "No"
estadd local hasday "No"
estadd local hasmonth "No"
eststo: reg work bar_* adj_count_any_leave lag_first_contact seniority_rank max_rate i.grouped_div, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasday "No"
estadd local hasmonth "No"
eststo: reg work bar_* adj_count_any_leave lag_first_contact seniority_rank max_rate i.grouped_div i.dayofweek, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasday "Yes"
estadd local hasmonth "No"
eststo: reg work bar_* adj_count_any_leave lag_first_contact seniority_rank max_rate i.grouped_div i.dayofweek i.month, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasday "Yes"
estadd local hasmonth "Yes"
esttab est1 est2 est3 est4 est5  using out/1_10_relevance.tex, se star(* 0.10 ** 0.05 *** 0.01) keep(adj_count_any_leave lag_first_contact seniority_rank max_rate) scalars("fs First-Stage F." "hasdiv Division FE" "hasday Day of Week FE" "hasmonth Month FE") nodepvar replace nomtitles label

*** balance tests
replace medpd=0 if matched_injury==1 & missing(medpd)
cap eststo clear
eststo: reg medpd adj_count_any_leave lag_first_contact seniority_rank if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "No"
estadd local hasday "No"
estadd local hasmonth "No"
eststo: reg medpd adj_count_any_leave lag_first_contact seniority_rank i.grouped_div if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasday "No"
estadd local hasmonth "No"
eststo: reg medpd adj_count_any_leave lag_first_contact seniority_rank i.grouped_div i.dayofweek if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasday "Yes"
estadd local hasmonth "No"
eststo: reg medpd adj_count_any_leave lag_first_contact seniority_rank i.grouped_div i.dayofweek i.month if matched_injury==1, cluster(empid)
estadd scalar fs = e(F)
estadd local hasdiv "Yes"
estadd local hasday "Yes"
estadd local hasmonth "Yes"
esttab est1 est2 est3 est4  using out/1_10_balance.tex, se star(* 0.10 ** 0.05 *** 0.01) keep(adj_count_any_leave lag_first_contact seniority_rank) scalars("fs F." "hasdiv Division FE" "hasday Day of Week FE" "hasmonth Month FE") nodepvar replace nomtitles label


**** sargan-hansen - use semykina version
tab dayofweek, gen(indw_)
tab month, gen(month_)
tab grouped_div, gen(gdiv_)


snp work an_age bar_* indw_1-indw_6 month_1-month_11 gdiv_1-gdiv_17 is_holiday prcp tmax adj_count_any_leave lag_first_contact seniority_rank max_rate, order(4)

* create variables
predict zb, xb
gen tau = normal(zb/_b[max_rate])

* create spline functions
mkspline splinep_ 5 = tau, displayknots

* 2sls
ivregress gmm matched_injury bar_* an_age i.month i.dayofweek i.grouped_div i.is_holiday prcp tmax max_rate splinep_* (work=adj_count_any_leave lag_first_contact seniority_rank), cluster(empid)
estat overid


****
log close

