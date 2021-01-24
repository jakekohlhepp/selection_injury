clear all
cap log close
set type double
log using log/01_07b_more_model_estimates.log, replace
set more off
set scheme cleanplots

** Purpose: Estimate additional quantities from the model.
use data/01_01_estimation_sample, clear
cap eststo clear
estimates use out/01_01_heckprob_results.ster
estimates esample: if sample_marked
estimates store est1

eststo m1: margins , dydx(adj_count_any_leave lag_first_contact  seniority_rank max_rate) predict( psel) vce(unconditional) post
estimates restore est1
eststo m2: margins , dydx(adj_count_any_leave lag_first_contact  seniority_rank max_rate) predict( pcond) vce(unconditional) post
esttab m1 m2  using out/1_07b_average_partial_effects.tex, unstack star(* 0.10 ** 0.05 *** 0.01) se replace nomtitle label eqlabels("Work" "Injury Conditional on Work")  nonumbers

estimates restore est1
* conditional injury rate
summ matched_injury if work==1
margins, predict(pcond) vce(unconditional)
* unconditional injury rate
margins, predict(pmargin) vce(unconditional)

* mean and variance of injury fixed effects
estimates restore est1
predictnl fe_work=[work]_b[bar_adj_count_any_leave]*bar_adj_count_any_leave + [work]_b[bar_max_rate]*bar_max_rate+[work]_b[bar_an_age]*bar_an_age+[work]_b[bar_lag_first_contact]*bar_lag_first_contact
label variable fe_work "Time-Constant Work Heterogeneity"
predictnl fe_inj=[matched_injury]_b[bar_adj_count_any_leave]*bar_adj_count_any_leave + [matched_injury]_b[bar_max_rate]*bar_max_rate+[matched_injury]_b[bar_an_age]*bar_an_age+[matched_injury]_b[bar_lag_first_contact]*bar_lag_first_contact
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

