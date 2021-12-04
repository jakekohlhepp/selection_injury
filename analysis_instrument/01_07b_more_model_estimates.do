clear all
cap log close
set type double
log using log/01_07b_more_model_estimates.log, replace
set more off
set scheme cleanplots

** Purpose: Estimate additional quantities from the model.
use data/01_01_estimation_sample, clear
cap eststo clear
estimates use out/01_02_heckprob_results.ster
estimates esample: if sample_marked
keep if has_datevar==1
estimates store est1


estimates restore est1
* conditional injury rate
summ matched_injury if work==1
margins, predict(pcond) predict(pmargin) vce(unconditional)

* unconditional injury rate
margins, predict(pmargin) vce(unconditional)


* counterfactual injury probablity point estimate
margins if dayofweek>0 & dayofweek<5, predict(pmargin)
summ matched_injury if dayofweek>0 & dayofweek<5

predict psel, psel
bys dayofweek: summ psel 

*** compute lower bound of counterfactual injury probability on weekday.
drop v*
estimates restore est1
local i = 0
forvalues x = 0.01(0.01)0.98{
local i = `i'+1
predictnl v`i' = normal((xb(matched_injury)-tanh([/athrho])*invnormal(`x') )/(1-tanh([/athrho])^2)^(1/2))

}
gen v0 = 0
replace v`i' = v`i' /2

preserve
keep if dayofweek>0 & dayofweek<5
collapse (mean) v*
egen tot = rowtotal(v*)
replace tot = 0.01*tot
tab tot
restore
*** upper bound is just 2%

*** estimate work probability with respect to injury.
estimates restore est1
margins if dayofweek<5 & dayofweek>0, expression(normal((xb(work)+tanh([/athrho])*invnormal(adj_div_8_leave_count) )/(1-tanh([/athrho])^2)^(1/2))) at(adj_div_8_leave_count=(0.001(0.09)0.901))
marginsplot, xlabel(0(0.2)0.9) recast(line) recastci(rarea) plot1opts(lcolor(black)) ciopt(fcolor(black%0) lcolor(black) lpattern(dash)) mcompare(bonferroni) ytitle("Daily Labor Supply") xtitle("Quantiles of Private Injury Risk") nolabels title("")
graph export out/01_07b_labor_supply.pdf, replace

****

estimates restore est1
eststo m1: margins if dayofweek<5 & dayofweek>0, dydx(adj_div_8_leave_count  seniority_rank max_rate) predict( psel) post
estimates restore est1
eststo m2: margins if dayofweek<5 & dayofweek>0, dydx(adj_div_8_leave_count  seniority_rank max_rate) predict( pcond) post
esttab m1 m2  using out/1_07b_average_partial_effects.tex, unstack star(* 0.10 ** 0.05 *** 0.01) se replace nomtitle label eqlabels("Work" "Injury Conditional on Work")  nonumbers

* mean and variance of injury fixed effects
estimates restore est1
predictnl fe_work=[work]_b[bar_adj_div_8_leave_count]*bar_adj_div_8_leave_count + [work]_b[bar_max_rate]*bar_max_rate
label variable fe_work "Time-Constant Work Heterogeneity"
predictnl fe_inj=[matched_injury]_b[bar_adj_div_8_leave_count]*bar_adj_div_8_leave_count + [matched_injury]_b[bar_max_rate]*bar_max_rate
label variable fe_inj "Time-Constant Injury Heterogeneity"
summ fe_work,d
local v1 = r(Var)
summ fe_inj,d
local v2 = r(Var)
corr fe_work fe_inj
local cov = r(rho) * (`v1'*`v2')^(1/2)
local rho = tanh([/athrho])
di (`rho'+`cov')/(1+`v1')^(1/2)/(1+`v2')^(1/2)


log close

