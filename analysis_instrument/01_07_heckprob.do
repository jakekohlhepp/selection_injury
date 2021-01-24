clear all
cap log close
set type double
log using log/01_07_heckprob.log, replace
set more off
set scheme cleanplots


use data/01_01_estimation_sample, clear
summ matched_injury if work==1
cap eststo clear
estimates use out/01_01_heckprob_results.ster
estimates esample: if sample_marked
estimates store est1
*** save table of estimates
estadd scalar atanrho = [/athrho]
estadd scalar atanrho_se = _se[/athrho]
estadd scalar disprho = tanh([/athrho])
unique employee_name
local emp = r(unique)
estadd local ci_rho = "("+strofreal(tanh([/athrho]+_se[/athrho]*invttail(`emp', 0.025)), "%11.2f")+ ", " + strofreal(tanh([/athrho]-_se[/athrho]*invttail(`emp', 0.025)), "%11.3f") +")"
esttab est1  using out/1_07_heckprob.tex, unstack star(* 0.10 ** 0.05 *** 0.01) se replace nomtitle keep(bar_* an_age is_holiday prcp tmax adj_count_any_leave lag_first_contact seniority_rank max_rate) scalar("disprho Rho" "ci_rho Rho 95\% CI") label eqlabels("Injury" "Work")  nonumbers

** test 
** table of average elasticies (work, injury given work)
eststo m1: margins , eyex(adj_count_any_leave lag_first_contact  seniority_rank max_rate) predict( psel) vce(unconditional) post
estimates restore est1
eststo m2: margins , eyex(adj_count_any_leave lag_first_contact  seniority_rank max_rate) predict( pcond) vce(unconditional) post
esttab m1 m2  using out/1_07_average_elast.tex, unstack se replace nomtitle label eqlabels("Work" "Injury Conditional on Work")  nonumbers

** some margins plot
estimates restore est1
margins, predict(pcond) at(lag_first_contact =(0(10)130)) vce(unconditional)
marginsplot, xlabel(0(10)130) recast(line) recastci(rarea) plot1opts(lcolor(blue)) ciopt(color(black%20)) derivlabels mcompare(bonferroni) ytitle("Pr(Injury=1|Work=1)") nolabels
graph export out/01_07_marginsplot_connections.pdf, replace

** some margins plot
estimates restore est1
margins, predict(pcond) at(adj_count_any_leave =(0(1)26)) vce(unconditional)
marginsplot, xlabel(0(5)26) recast(line) recastci(rarea) plot1opts(lcolor(blue)) ciopt(color(black%20)) derivlabels mcompare(bonferroni) ytitle("Pr(Injury=1|Work=1)") nolabels
graph export out/01_07_marginsplot_leave.pdf, replace

*** marginal probability of injury - trick margins to do several values 
estimates restore est1
margins, expression(normal((xb(matched_injury)-tanh([/athrho])*adj_count_any_leave)/(1-tanh([/athrho])^2)^(1/2))) at(adj_count_any_leave=(-0.5(0.02)0)) vce(unconditional)
marginsplot, xlabel(-0.5(0.1)0) recast(line) recastci(rarea) plot1opts(lcolor(blue)) ciopt(color(black%20)) derivlabels mcompare(bonferroni) ytitle("Marginal Probability of Injury") xtitle("Unobserved Resistance to Work") nolabels
graph export out/01_07_mpi.pdf, replace

* compare 50th to 75th - for abstract
estimates restore est1
margins, expression(normal((xb(matched_injury)-tanh([/athrho])*(-0.675))/(1-tanh([/athrho])^2)^(1/2))/normal((xb(matched_injury)-tanh([/athrho])*(0))/(1-tanh([/athrho])^2)^(1/2))) vce(unconditional)


** graph estimated time-invariant resistances to work
estimates restore est1
predictnl fe_work=[work]_b[bar_adj_count_any_leave]*bar_adj_count_any_leave + [work]_b[bar_max_rate]*bar_max_rate+[work]_b[bar_an_age]*bar_an_age+[work]_b[bar_lag_first_contact]*bar_lag_first_contact
label variable fe_work "Time-Constant Work Heterogeneity"
predictnl fe_inj=[matched_injury]_b[bar_adj_count_any_leave]*bar_adj_count_any_leave + [matched_injury]_b[bar_max_rate]*bar_max_rate+[matched_injury]_b[bar_an_age]*bar_an_age+[matched_injury]_b[bar_lag_first_contact]*bar_lag_first_contact
label variable fe_inj "Time-Constant Injury Heterogeneity"
preserve
bys empid: keep if _n==1
twoway scatter fe_inj fe_work
graph export out/01_07_het_scatter.pdf, replace

restore

* for visualization, use these parameters:
summ fe_work fe_inj
corr fe_work fe_inj

***** do work elasticities at different levels of unobserved injury.

postfile workelast resistance elast se inj ll ul  using data/01_07_workelast, replace
estimates restore est1
predict xb,xb

forvalues j = -1(0.1)1 {
    estimates restore est1
    margins, expression(normal((xb(work)-tanh([/athrho])*`j')/(1-tanh([/athrho])^2)^(1/2))) eyex(max_rate) vce(unconditional)
    local h = r(table)[1,1]
    local ll = r(table)[5,1]
    local ul = r(table)[6,1]
    local se = r(table)[2,1]
    estimates restore est1
    gen _temp = xb>=`j'
    qui summ _temp
    local inj = r(mean)
    post workelast (`j') (`h') (`se') (`inj') (`ll') (`ul')
    drop _temp
}
postclose workelast

use data/01_07_workelast, clear
gen num=_n
keep if mod(num,3)==0 | _n==1 | _n==_N
drop num
* graph elasticity
label variable resistance "Unobserved Injury Propensity"
label variable elast "Labor Supply Elasticity"
twoway rarea ll ul resistance, sort color(gs14) || lowess elast resistance, color(blue) legend(off)
graph export out/01_07_laborsupply_elast.pdf, replace
keep elast resistance se
expand 2, gen(_tag)
local more = _N+1
set obs `more'
replace resistance = -99 if missing(resistance)
sort resistance _tag
replace resistance = . if resistance==-99
tostring  elast se, force replace format(%8.3fc)
tostring  resistance, force replace format(%8.1fc)
replace elast = "(" + se +")" if _tag==1
replace resistance="" if _tag==1
drop _tag se

foreach var of varlist * {
    local varlabel : var label `var'
    replace `var' = "`varlabel'" if _n==1
}
export delimited  using out/01_07_elasticity_table.txt, replace delimiter(tab) novarnames



log close



