clear all
cap log close
set type double
log using log/01_05_xtiv.log, replace
set more off
set scheme cleanplots
set seed 1009

//Purpose: Run panel iv model - linear
use data/01_01_estimation_sample, clear


*naive regressions

cap eststo clear
eststo: reg matched_injury i.work an_age work, cluster(empid)
estadd local hasdiv "No"
estadd local hasday "No"
estadd local hasdate "No"
eststo: reg matched_injury i.work an_age i.grouped_div, cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "No"
estadd local hasdate "No"
eststo: reg matched_injury i.work an_age i.dayofweek i.month i.grouped_div, cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "Yes"
estadd local hasdate "No"
eststo: reg matched_injury i.work an_age i.grouped_div i.analysis_workdate , cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "No"
estadd local hasdate "Yes"
esttab est1 est2 est3 est4  using out/1_05_lpm.tex, star(* 0.10 ** 0.05 *** 0.01) se keep(1.work an_age) scalars("F F-Stat." "hasdiv Division FE" "hasday Day of Week/Month FE" "hasdate Date FE") label nodepvar nomtitle replace

cap eststo clear
eststo: reg work adj_count_any_leave lag_first_contact seniority_rank max_rate an_age bar_*, cluster(empid)
estadd local hasdiv "No"
estadd local hasday "No"
estadd local hasdate "No"
eststo: reg work adj_count_any_leave lag_first_contact seniority_rank max_rate an_age bar_* i.grouped_div, cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "No"
estadd local hasdate "No"
eststo: reg work adj_count_any_leave lag_first_contact seniority_rank max_rate an_age bar_* i.dayofweek i.month i.grouped_div, cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "Yes"
estadd local hasdate "No"
eststo: reg work adj_count_any_leave lag_first_contact seniority_rank max_rate an_age bar_* i.grouped_div i.analysis_workdate , cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "No"
estadd local hasdate "Yes"

esttab est1 est2 est3 est4  using out/1_05_first_stage.tex, star(* 0.10 ** 0.05 *** 0.01) se keep(bar_adj_count_any_leave bar_lag_first_contact bar_max_rate bar_an_age adj_count_any_leave lag_first_contact an_age seniority_rank max_rate ) scalars("F F-Stat." "hasdiv Division FE" "hasday Day of Week/Month FE" "hasdate Date FE") label nodepvar nomtitle replace

*** now FE 2sls -
* need the bar z instruments in both equations.
cap eststo clear
eststo: ivreg2 matched_injury bar_* an_age max_rate (work = adj_count_any_leave lag_first_contact seniority_rank), cluster(empid)
estadd local hasdiv "No"
estadd local hasday "No"
estadd local hasdate "No"
eststo: ivreg2 matched_injury bar_* an_age i.grouped_div max_rate (work = adj_count_any_leave lag_first_contact seniority_rank), cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "No"
estadd local hasdate "No"
eststo: ivreg2 matched_injury bar_* an_age i.grouped_div i.dayofweek i.month max_rate (work = adj_count_any_leave lag_first_contact seniority_rank), cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "Yes"
estadd local hasdate "No"
eststo: ivreg2 matched_injury bar_* an_age i.grouped_div i.analysis_workdate max_rate (work = adj_count_any_leave lag_first_contact seniority_rank), cluster(empid)
estadd local hasdiv "Yes"
estadd local hasday "No"
estadd local hasdate "Yes"

esttab est1 est2 est3 est4  using out/1_05_feiv.tex, star(* 0.10 ** 0.05 *** 0.01) se keep(work) scalars("idstat Underid K-P LM-stat" "cdf C-G F-Stat" "rkf Weak id. K-P F-stat" "j Hansen J" "jp Hansen J p" "hasdiv Division FE" "hasday Day of Week/Month FE" "hasdate Date FE") nodepvar replace nodepvar nomtitle

* to test strict exogeneity of z, do these added variable regressions
*ivregress 2sls matched_injury f1.adj_count_any_leave f1.seniority_rank f1.max_rate  i.main_div i.dayofweek (work =f1.adj_count_any_leave f1.seniority_rank f1.max_rate adj_count_any_leave seniority_rank max_rate ), cluster(empid)


log close

