clear all
cap log close
set type double
log using log/01_08_valueofinj.log, replace
set more off
set scheme cleanplots
cap estimates clear

use data/01_01_estimation_sample, clear


cap eststo clear
estimates load out/01_07_heckprob_results.ster
estimates esample: if sample_marked

*** compute value
predict xb, xb
summ xb, d
gen flag_median = abs(xb-r(p50))<0.000001
predict zb, xbsel
* get quad weights: https://jblevins.org/notes/quadrature
local w1 = 0.0199532
local w2 = 0.393619
local w3 = 0.945309
local w4 = 0.393619
local w5 = 0.0199532

* get quad points
local x1 = -2.02018
local x2 = -0.958572
local x3 = 0
local x4 = 0.958572
local x5 = -2.02018


*** get as vsi
*qui unique employee_name
local p = 1/_N
local N = _N

foreach m of numlist 1 2{
estimates restore est1
eststo: margins , expression((`w1'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x1'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x1')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w2'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x2'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x2')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w3'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x3'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x3')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w4'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x4'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x4')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w5'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x5'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x5')/(1-tanh([/athrho])^2)^(1/2))+`p')))/c(pi)*`N') post

}

* plot individual values - density

* do just wilingness to pay
foreach m of numlist 1 2{
estimates restore est1
eststo: margins , expression((`w1'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x1'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x1')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w2'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x2'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x2')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w3'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x3'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x3')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w4'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x4'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x4')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w5'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x5'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x5')/(1-tanh([/athrho])^2)^(1/2))+`p')))/c(pi)) post

}

esttab est4 est2 using out/1_08_injvalue.tex, se nodepvar replace label noobs coeflabels(_cons " ") mtitles("Willingness to Pay" "VSI") nonumbers mgroups("Lower Bound (M = 1)", pattern(1)) nostar
esttab est5 est3  using out/1_08_injvalue.tex, se nodepvar nonotes addnotes(" ") label noobs coeflabels(_cons " ") nonumbers mtitles("Willingness to Pay" "VSI")   append mgroups("Upper Bound (M = 2)",pattern(1)) nostar


estimates restore est1
local m = 1

predictnl injvalue = (`w1'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x1'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x1')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w2'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x2'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x2')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w3'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x3'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x3')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w4'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x4'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x4')/(1-tanh([/athrho])^2)^(1/2))+`p'))+`w5'*(-8)*`m'*([matched_injury]_b[max_rate]-tanh([/athrho])*[work]_b[max_rate])^(-1)*(xb(matched_injury)-tanh([/athrho])*`x5'-(1-tanh([/athrho])^2)^(1/2)*invnormal(normal((xb(matched_injury)-tanh([/athrho])*`x5')/(1-tanh([/athrho])^2)^(1/2))+`p')))/c(pi),ci(lower_injval upper_injval)

twoway (kdensity injvalue) if injvalue<=2, xtitle("Willingness to Pay ($)") ytitle("Density")
graph export out/01_08_kdensity.pdf, replace


xtsum injvalue
log close
 

