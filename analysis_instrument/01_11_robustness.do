clear all
cap postclose
cap log close
set type double
log using log/01_11_robustness.log, replace
set more off
set scheme cleanplots

**** perform robustness checks. for each model, store coefficient on leave, rho and the average population rate.
use data/01_01_estimation_sample, clear


postfile results str50 name double( instrument se_i rho se_r margin se_m) using data/01_11_robustness, replace

**** main model (no changes)
eststo clear
preserve
cap eststo clear
estimates use out/01_02_heckprob_results.ster
estimates esample: if sample_marked
estimates store est1
lincom [work]_b[adj_div_8_leave_count]
local se_i = r(se)
nlcom tanh([/athrho])
local rho = tanh([/athrho])
local se_rho = sqrt(r(V)[1,1])
margins if dayofweek>0 & dayofweek<5, predict(pmargin)
local se_m = sqrt(r(V)[1,1])
local marg = r(b)[1,1]
post results ("Base Model") ([work]_b[adj_div_8_leave_count]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')


restore


**** run using alternative instrument
eststo clear
preserve
keep if has_datevar==1
drop bar_adj_div_8_leave_count
bys empid: egen bar_alt_leave_nosick=mean(alt_leave_nosick)
eststo: heckprobit matched_injury bar_alt_leave_nosick bar_max_rate  an_age max_rate seniority_rank i.analysis_workdate i.grouped_div if has_datevar==1, select(work =  bar_alt_leave_nosick bar_max_rate  alt_leave_nosick  an_age max_rate seniority_rank i.analysis_workdate i.grouped_div) vce(cluster empid)
estadd scalar atanrho = [/athrho]
estadd scalar atanrho_se = _se[/athrho]
estadd scalar disprho = tanh([/athrho])
unique employee_name
local emp = r(unique)
estadd local ci_rho = "("+strofreal(tanh([/athrho]+_se[/athrho]*invttail(`emp', 0.025)), "%11.2f")+ ", " + strofreal(tanh([/athrho]-_se[/athrho]*invttail(`emp', 0.025)), "%11.3f") +")"
lincom [work]_b[alt_leave_nosick]
local se_i = r(se)
nlcom tanh([/athrho])
local rho = tanh([/athrho])
local se_rho = sqrt(r(V)[1,1])
esttab est1  using out/01_11_heckprob_nosick.tex, unstack se replace nomtitle keep(bar_* an_age max_rate seniority_rank alt_leave_nosick) scalar("disprho Rho" "ci_rho Rho 95\% CI") label eqlabels("Injury" "Work")  nonumbers
margins if dayofweek>0 & dayofweek<5, predict(pmargin)
local se_m = sqrt(r(V)[1,1])
local marg = r(b)[1,1]
post results ("Sick Time Excluded from Leave") ([work]_b[alt_leave_nosick]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')
restore


**** run using week dayofweek fe
preserve

heckprobit matched_injury bar_adj_div_8_leave_count bar_max_rate  an_age max_rate seniority_rank i.an_week i.dayofweek i.grouped_div if has_datevar==1, select(work =  bar_adj_div_8_leave_count bar_max_rate  adj_div_8_leave_count  an_age max_rate seniority_rank i.an_week i.dayofweek i.grouped_div) vce(cluster empid) difficult
lincom [work]_b[adj_div_8_leave_count]
local se_i = r(se)
nlcom tanh([/athrho])
local rho = tanh([/athrho])
local se_rho = sqrt(r(V)[1,1])
margins if dayofweek>0 & dayofweek<5, predict(pmargin)
local se_m = sqrt(r(V)[1,1])
local marg = r(b)[1,1]
post results ("Broader Date FE") ([work]_b[adj_div_8_leave_count]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')
restore

**** run without strains
eststo clear
preserve
replace matched_injury = 0 if natureofinjury=="Strain"
heckprobit matched_injury bar_adj_div_8_leave_count bar_max_rate  an_age max_rate seniority_rank i.an_week i.dayofweek i.grouped_div, select(work =  bar_adj_div_8_leave_count bar_max_rate  adj_div_8_leave_count  an_age max_rate seniority_rank i.an_week i.dayofweek i.grouped_div) vce(cluster empid)
lincom [work]_b[adj_div_8_leave_count]
local se_i = r(se)
nlcom tanh([/athrho])
local rho = tanh([/athrho])
local se_rho = sqrt(r(V)[1,1])
margins if dayofweek>0 & dayofweek<5, predict(pmargin)
local se_m = sqrt(r(V)[1,1])
local marg = r(b)[1,1]
post results ("Strains Not Considered Injuries") ([work]_b[adj_div_8_leave_count]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')
restore

**** run using different thresholds of payouts.
*** run using dayofweek and week fixed effects due to convergence issues.

foreach t of numlist 0 200 400 {
    preserve
    summ medpd, d
    replace matched_injury = 0 if medpd<=`t'
    heckprobit matched_injury bar_adj_div_8_leave_count bar_max_rate  an_age max_rate seniority_rank i.an_week i.dayofweek i.grouped_div if has_datevar==1, select(work =  bar_adj_div_8_leave_count bar_max_rate  adj_div_8_leave_count  an_age max_rate seniority_rank i.an_week i.dayofweek i.grouped_div) vce(cluster empid) difficult
     lincom [work]_b[adj_div_8_leave_count]
    local se_i = r(se)
    nlcom tanh([/athrho])
    local rho = tanh([/athrho])
    local se_rho = sqrt(r(V)[1,1])
	margins if dayofweek>0 & dayofweek<5, predict(pmargin)
	local se_m = sqrt(r(V)[1,1])
	local marg = r(b)[1,1]
    post results ("Med. Exp. $\leq$`t' Not Injury") ([work]_b[adj_div_8_leave_count]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')

    restore
}


*** make table
postclose results

preserve
use data/01_11_robustness, clear
mkmat instrument - se_m, mat(R) rownames(name)
esttab matrix(R, fmt(4 4 4 4 4 4)) using out/01_11_robustness.tex, substitute(_ " ") nomtitles collabels("Leave Coef." "Coef SE" "Rho" "Rho SE" "Avg. Pop. Inj. Rate" "Avg. Pop. Inj. Rate SE") replace

restore


log close

