clear all
cap log close
set type double
log using log/01_11_robustness.log, replace
set more off
set scheme cleanplots

**** perform robustness checks. for each model, store ratio of leave/age, rho and margins call.
use data/01_01_estimation_sample, clear


foreach var of varlist adj_nosick_leave {
    by empid: egen bar_`var' = mean(`var')
    local label: variable label `var'
    label variable bar_`var' "Avg. `label'"
}


label variable adj_nosick_leave "Division Leave (No Sick)"
label variable bar_adj_nosick_leave "Avg. Leave (No Sick)"


postfile results str50 name double( instrument se_i rho se_r margin se_m) using data/01_11_robustness, replace
local emp = r(unique)
local emp = r(unique)

**** main model (no changes)
eststo clear
preserve
cap eststo clear
estimates load out/01_07_heckprob_results.ster
estimates esample: if sample_marked
lincom [work]_b[adj_count_any_leave]
local se_i = r(se)
nlcom tanh([/athrho])
local rho = tanh([/athrho])
local se_rho = sqrt(r(V)[1,1])
margins, expression(normal((xb(matched_injury)-tanh([/athrho])*(-0.675))/(1-tanh([/athrho])^2)^(1/2))/normal((xb(matched_injury)-tanh([/athrho])*(0))/(1-tanh([/athrho])^2)^(1/2)) -1) vce(unconditional)
local se_m = sqrt(r(V)[1,1])
local marg = r(b)[1,1]
post results ("Base Model") ([work]_b[adj_count_any_leave]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')


restore

**** run using alternative instrument
preserve
drop bar_adj_count_any_leave
eststo: heckprobit matched_injury bar_* an_age i.month i.dayofweek i.grouped_div is_holiday prcp tmax max_rate, select(work = bar_* an_age i.grouped_div i.month i.dayofweek is_holiday prcp tmax adj_nosick_leave lag_first_contact seniority_rank max_rate) vce(cluster empid)
estadd scalar atanrho = [/athrho]
estadd scalar atanrho_se = _se[/athrho]
estadd scalar disprho = tanh([/athrho])
lincom [work]_b[adj_nosick_leave]
local se_i = r(se)
nlcom tanh([/athrho])
local rho = tanh([/athrho])
local se_rho = sqrt(r(V)[1,1])
esttab est1  using out/1_11_heckprob_nosick.tex, unstack se replace nomtitle keep(bar_* an_age is_holiday prcp tmax adj_nosick_leave lag_first_contact seniority_rank max_rate) scalar("disprho Rho" "ci_rho Rho 95\% CI") label eqlabels("Injury" "Work")  nonumbers
margins, expression(normal((xb(matched_injury)-tanh([/athrho])*(-0.675))/(1-tanh([/athrho])^2)^(1/2))/normal((xb(matched_injury)-tanh([/athrho])*(0))/(1-tanh([/athrho])^2)^(1/2)) -1) vce(unconditional)
local se_m = sqrt(r(V)[1,1])
local marg = r(b)[1,1]
post results ("Sick Time Excluded from Leave") ([work]_b[adj_nosick_leave]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')
restore

**** run without strains
eststo clear
preserve
drop bar_adj_nosick_leave
replace matched_injury = 0 if natureofinjury=="Strain"
heckprobit matched_injury bar_* an_age i.month i.dayofweek i.grouped_div is_holiday prcp tmax max_rate, select(work = bar_* an_age i.grouped_div i.month i.dayofweek is_holiday prcp tmax adj_count_any_leave lag_first_contact seniority_rank max_rate) vce(cluster empid)

lincom [work]_b[adj_count_any_leave]
local se_i = r(se)
nlcom tanh([/athrho])
local rho = tanh([/athrho])
local se_rho = sqrt(r(V)[1,1])
margins, expression(normal((xb(matched_injury)-tanh([/athrho])*(-0.675))/(1-tanh([/athrho])^2)^(1/2))/normal((xb(matched_injury)-tanh([/athrho])*(0))/(1-tanh([/athrho])^2)^(1/2)) -1) vce(unconditional)
local se_m = sqrt(r(V)[1,1])
local marg = r(b)[1,1]
post results ("Strains Not Considered Injuries") ([work]_b[adj_count_any_leave]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')


restore

**** run using different thresholds of payouts.

foreach t of numlist 0 200 400 {
    preserve
    drop bar_adj_nosick_leave
    summ medpd, d
    replace matched_injury = 0 if medpd<=`t'
    heckprobit matched_injury bar_* an_age i.month i.dayofweek i.grouped_div is_holiday prcp tmax max_rate, select(work = bar_* an_age i.grouped_div i.month i.dayofweek is_holiday prcp tmax adj_count_any_leave lag_first_contact seniority_rank max_rate) vce(cluster empid)

     lincom [work]_b[adj_count_any_leave]
    local se_i = r(se)
    nlcom tanh([/athrho])
    local rho = tanh([/athrho])
    local se_rho = sqrt(r(V)[1,1])
margins, expression(normal((xb(matched_injury)-tanh([/athrho])*(-0.675))/(1-tanh([/athrho])^2)^(1/2))/normal((xb(matched_injury)-tanh([/athrho])*(0))/(1-tanh([/athrho])^2)^(1/2)) -1) vce(unconditional)
    local se_m = sqrt(r(V)[1,1])
    local marg = r(b)[1,1]
    post results ("Med. Exp. $\leq$`t' Not Injury") ([work]_b[adj_count_any_leave]) (`se_i') (`rho') (`se_rho') (`marg') (`se_m')

    restore
}


*** make table
postclose results

preserve
use data/01_11_robustness, clear
mkmat instrument - se_m, mat(R) rownames(name)
esttab matrix(R, fmt(4 4 4 4 4 4)) using out/01_11_robustness.tex, substitute(_ " ") nomtitles collabels("Leave Coef." "Coef SE" "Rho" "Rho SE" "\%. Incr." "\% SE") replace

restore


*** relax normality
*drop bar_adj_nosick_leave
*xi: snp2s matched_injury bar_* an_age max_rate, select(work = bar_* an_age adj_count_any_leave lag_first_contact seniority_rank max_rate) dplot(out/01_11_normality.pdf)



log close

