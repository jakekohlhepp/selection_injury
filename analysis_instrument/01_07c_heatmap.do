clear all
cap postclose
cap log close
cap ssc install heatmap
cap ssc install palettes
cap  ssc install colrspace, replace
set type double
set scheme cleanplots
log using log/01_07c_heatmap.log, replace
set more off



use data/01_01_estimation_sample, clear
keep if has_datevar==1
cap eststo clear
estimates use out/01_02_heckprob_results.ster
estimates esample: if sample_marked

** derive mte as function of propensity score.
** use this process:
** 0 get propensity score. bin by 0.01
predict psel, psel
gen r_psel = floor(psel*100)/100

** 1. get estimation sample. expand sample and make one ob for 29 values of u (from 0.7 to 0.99)
gen raword = _n
expand 99
bys raword: gen v = _n*0.01
* only want to display people who have resistance

** 3. estimate mte function for each one.
predictnl mte=normal((xb(matched_injury)-tanh([/athrho])*invnormal(v))/(1-tanh([/athrho])^2)^(1/2))
** 4. then take average in each u and p bin.
keep if dayofweek>0 & dayofweek<5
summ psel
drop if v<=r(min)
preserve
collapse (mean) mte , by(v r_psel)
label variable v "Private Component (Resistance)"
label variable r_psel "Predictable Component (Propensity Score)"
label variable mte "MTE (Injury %.)"
replace mte = mte*100
hexplot mte  r_psel v, color(plasma, reverse) cuts(0(0.05)3) ylabel(, nogrid) xlabel(, nogrid) keylabels(1(10)60, format(%8.1f)) legend(subtitle("MTE (Injury %)")) xscale(titlegap(8))
graph export out/01_07c_hexplot.pdf,replace
restore


** compute relative variance by each component. can use correlation because independent
reg mte v psel
reg mte v
reg mte psel

* variation explained by 
di 0.0728/0.4037
di 0.3309/0.4037


**** do this more analytically.
**** compare xb - r phi(res) and za and phi(res)
**** coeff on phi(res) is known to be -rho.
**** then share is just 
use data/01_01_estimation_sample, clear
keep if dayofweek>0 & dayofweek<5
keep if has_datevar==1
cap eststo clear
estimates use out/01_02_heckprob_results.ster
estimates esample: if sample_marked
predictnl xb = xb(matched_injury)
summ xb,d
local xb_sd = r(sd)^2
predictnl za = xb(work)
corr za xb
local rho_ob = r(rho)^2
local totalvar = `rho_ob'*`xb_sd'+tanh([/athrho])^2
di (`rho_ob'*`xb_sd')/`totalvar'
di (tanh([/athrho])^2)/`totalvar'



log close
