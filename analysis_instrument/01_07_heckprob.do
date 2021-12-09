clear all
cap log close
set type double
log using log/01_07_heckprob.log, replace
set more off
set scheme cleanplots


use data/01_01_estimation_sample, clear
keep if has_datevar==1
cap eststo clear
estimates use out/01_02_heckprob_results.ster
estimates esample: if sample_marked

estimates store est1

*** save table of estimates
estadd scalar atanrho = [/athrho]
estadd scalar atanrho_se = _se[/athrho]
estadd scalar disprho = tanh([/athrho])
unique employee_name
local emp = r(unique)
estadd local ci_rho = "("+strofreal(tanh([/athrho]+_se[/athrho]*invttail(`emp', 0.025)), "%11.2f")+ ", " + strofreal(tanh([/athrho]-_se[/athrho]*invttail(`emp', 0.025)), "%11.3f") +")"
esttab est1  using out/1_07_heckprob.tex, unstack star(* 0.10 ** 0.05 *** 0.01) se replace nomtitle keep(bar_* adj_div_8_leave_count seniority_rank max_rate) scalar("disprho Rho" "ci_rho Rho 95\% CI") label eqlabels("Injury" "Work")  nonumbers

*** graph of propensities.
estimates restore est1
predict psel, psel
twoway (histogram psel  if work==0,lcolor(gs12) fcolor(gs12) bin(30) frequency ) (histogram psel  if work==1,fcolor(none) lcolor(red) bin(30) frequency)   ,xtitle("Propensity Score")  legend(order(1 "Not Work" 2 "Work" ))
graph export out/01_07_propscore_hist.pdf,replace

twoway  (histogram psel  if dayofweek==6 | dayofweek==0 & work==0,lcolor(gs12) fcolor(gs12) bin(30) frequency ) (histogram psel  if dayofweek==6 | dayofweek==0 & work==1,fcolor(none) lcolor(red) bin(30) frequency)  ,xtitle("Propensity Score")  legend(order(1 "Not Work" 2 "Work" ))
graph export out/01_07_weekend_propscore_hist.pdf,replace

twoway  (histogram psel  if dayofweek<5 & dayofweek>0 & work==0,lcolor(gs12) fcolor(gs12) bin(15) frequency ) (histogram psel  if dayofweek<5 & dayofweek>0 & work==1,fcolor(none) lcolor(red) bin(30) frequency) ,xtitle("Propensity Score")  legend(order(1 "Not Work" 2 "Work" ))
graph export out/01_07_mon_thurs_propscore_hist.pdf,replace


reg adj_div_8_leave_count i.analysis_workdate i.grouped_div  an_age max_rate i.empid
predict res_leave, resid
reg work i.analysis_workdate i.grouped_div  an_age max_rate i.empid
predict workres, resid
reg workres res_leave
predict residpsel
qui summ work if dayofweek<5 & dayofweek>0
replace residpsel = r(mean)+residpsel if dayofweek<5 & dayofweek>0
qui summ work if dayofweek==6 | dayofweek==0
replace residpsel = r(mean)+residpsel if dayofweek==6 | dayofweek==0
twoway (histogram psel  if dayofweek<5 & dayofweek>0 & work==0,lcolor(gs12) fcolor(gs12) bin(15) frequency ) (histogram residpsel  if dayofweek<5 & dayofweek>0 & work==1,fcolor(none) lcolor(red) bin(15) frequency)   ,xtitle("Propensity Score")  legend(order(1 "Not Work" 2 "Work" ))
graph export out/01_07_resid_propscore_hist_mon_thurs.pdf,replace
twoway  (histogram psel  if dayofweek==6 | dayofweek==0 & work==0,lcolor(gs12) fcolor(gs12) bin(15) frequency )  (histogram residpsel  if dayofweek==6 | dayofweek==0 & work==1,fcolor(none) lcolor(red) bin(15) frequency),xtitle("Propensity Score")  legend(order(1 "Not Work" 2 "Work" ))
graph export out/01_07_resid_propscore_hist_weekend.pdf,replace

*** try rescaled onto resistance. only plot over portions where we have good propensity score coverage.
estimates restore est1
margins if dayofweek<5 & dayofweek>0, expression(normal((xb(matched_injury)-tanh([/athrho])*invnormal(adj_div_8_leave_count) )/(1-tanh([/athrho])^2)^(1/2))) at(adj_div_8_leave_count=(0.85(0.01)0.95))

marginsplot, xlabel(0.85(0.01)0.95) recast(line) recastci(rarea) plot1opts(lcolor(black)) ciopt(fcolor(black%0) lcolor(black) lpattern(dash)) derivlabels mcompare(bonferroni) ytitle("Marginal Treatment Effect") xtitle("Private Resistance to Work") nolabels title("")
graph export out/01_07_mte_mon_thurs.pdf, replace

estimates restore est1
margins if dayofweek==6 | dayofweek==0, expression(normal((xb(matched_injury)-tanh([/athrho])*invnormal(adj_div_8_leave_count) )/(1-tanh([/athrho])^2)^(1/2))) at(adj_div_8_leave_count=(0.3(0.01)0.5))

marginsplot, xlabel(0.3(0.01)0.5) recast(line) recastci(rarea) plot1opts(lcolor(black)) ciopt(fcolor(black%0) lcolor(black) lpattern(dash)) derivlabels mcompare(bonferroni) ytitle("Marginal Probability of Injury") xtitle("Private Resistance to Work") nolabels title("")
graph export out/01_07_mte_weekend.pdf, replace


** table of average elasticies (work, injury given work)
estimates restore est1
eststo m1: margins if dayofweek<5 & dayofweek>0, eyex(adj_div_8_leave_count  seniority_rank max_rate) predict( psel) post
estimates restore est1
eststo m2: margins if dayofweek<5 & dayofweek>0, eyex(adj_div_8_leave_count  seniority_rank max_rate) predict( pcond) post
esttab m1 m2  using out/1_07_average_elast.tex, unstack se replace nomtitle label eqlabels("Work" "Injury Conditional on Work")  nonumbers

** some margins plot
estimates restore est1
margins if dayofweek<5 & dayofweek>0, predict(pcond) at(adj_div_8_leave_count =(0(10)100))
marginsplot, xlabel(0(10)100) recast(line) recastci(rarea) plot1opts(lcolor(black)) ciopt(fcolor(black%0) lcolor(black) lpattern(dash)) derivlabels mcompare(bonferroni) ytitle("Pr(Injury=1|Work=1)") nolabels title("")
graph export out/01_07_marginsplot_leave_mon_thurs.pdf, replace

estimates restore est1
margins if dayofweek==6 | dayofweek==0, predict(pcond) at(adj_div_8_leave_count =(0(10)100))
marginsplot, xlabel(0(10)100) recast(line) recastci(rarea) plot1opts(lcolor(black)) ciopt(fcolor(black%0) lcolor(black) lpattern(dash)) derivlabels mcompare(bonferroni) ytitle("Pr(Injury=1|Work=1)") nolabels title("")
graph export out/01_07_marginsplot_leave_weekend.pdf, replace

estimates restore est1
margins, predict(pcond) at(adj_div_8_leave_count =(0(10)100)) vce(unconditional)
marginsplot, xlabel(0(10)100) recast(line) recastci(rarea) plot1opts(lcolor(black)) ciopt(fcolor(black%0) lcolor(black) lpattern(dash)) derivlabels mcompare(bonferroni) ytitle("Pr(Injury=1|Work=1)") nolabels title("")
graph export out/01_07_marginsplot_leave.pdf, replace

** graph estimated time-invariant resistances to work
estimates restore est1
predictnl fe_work=[work]_b[bar_adj_div_8_leave_count]*bar_adj_div_8_leave_count + [work]_b[bar_max_rate]*bar_max_rate
label variable fe_work "Time-Constant Work Heterogeneity"
predictnl fe_inj=[matched_injury]_b[bar_adj_div_8_leave_count]*bar_adj_div_8_leave_count + [matched_injury]_b[bar_max_rate]*bar_max_rate
label variable fe_inj "Time-Constant Injury Heterogeneity"
preserve
bys empid: keep if _n==1
twoway scatter fe_inj fe_work
graph export out/01_07_het_scatter.pdf, replace

restore

* for visualization, use these parameters:
summ fe_work fe_inj
corr fe_work fe_inj

***** do work elasticities at different levels of Private injury.

postfile workelast privaterisk elast se inj ll ul  using data/01_07_workelast, replace
estimates restore est1
predict xb,xb

forvalues j = 0.05(0.05)0.95 {
    estimates restore est1
    margins, expression(normal((xb(work)+tanh([/athrho])*invnormal(`j') )/(1-tanh([/athrho])^2)^(1/2))) eyex(max_rate) vce(unconditional)
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

* graph elasticity
label variable privaterisk "Quantiles of Private Injury Risk"
twoway line elast ll ul privaterisk, sort lpattern(solid dash dash) lcolor(black black black) legend(off) ytitle("Elasticity of Labor Supply")
graph export out/01_07_laborsupply_elast.pdf, replace

keep elast privaterisk se
expand 2, gen(_tag)
local more = _N+1
set obs `more'
replace privaterisk = -99 if missing(privaterisk)
sort privaterisk _tag
replace privaterisk = . if privaterisk==-99
tostring  elast se, force replace format(%8.3fc)
tostring  privaterisk, force replace format(%8.2fc)
replace elast = "(" + se +")" if _tag==1
replace privaterisk="" if _tag==1
drop _tag se

foreach var of varlist * {
    local varlabel : var label `var'
    replace `var' = "`varlabel'" if _n==1
}

keep if mod(_n,3)==0 | _n==1 | _n==_N

export delimited  using out/01_07_elasticity_table.txt, replace delimiter(tab) novarnames



log close



