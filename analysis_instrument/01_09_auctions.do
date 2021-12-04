clear all
cap log close
set type double
log using log/01_09_auctions.log, replace
set more off
set scheme cleanplots

*** Purpose: perform auction simulations.
use data/01_01_estimation_sample, clear
keep if has_datevar==1 & dayofweek<5 & dayofweek>0
cap eststo clear
estimates use out/01_02_heckprob_results.ster
estimates esample: if sample_marked
qui count if sample_marked
local N = r(N)
estimates store est1

***** chunk added for this module only*****
* proxy the normal amount of labor as the number of standard hours divided by 8
bys grouped_div (empid analysis_workdate):  egen div_tot_standard = total(varstandard_hours)
bys grouped_div (empid analysis_workdate):  egen div_tot_shifts = total(work)
gen frac_additional = (div_tot_shifts-div_tot_standard/8)/div_tot_shifts
replace frac_additional = 0 if frac_additional<0
bys analysis_workdate grouped_div (empid): egen day_div_shifts = total(work)
gen additional_shifts = round(day_div_shifts*frac_additional)
gen regular_shifts = day_div_shifts-additional_shifts
egen total_overall_shifts = total(work)

****** chunk added for this module only ******
predict zb, xbsel
predict raw_zb, xbsel
predict xb, xb
replace raw_zb = raw_zb - max_rate*[work]_b[max_rate] - adj_div_8_leave_count*[work]_b[adj_div_8_leave_count]

local rho = tanh([/athrho])


*******************************************************************************************************


**** begin simulation. - assume iid across periods.
* set weight for time invariant
* set weights from fitting xtprobit.
local w1 = 0.5
local w2 = 0.5
* need temporary id.
encode employee_name, gen(_idemp) 
 gen mergenum=_n
sort grouped_div analysis_workdate empid

tempfile orig
save `orig'

matrix V1 = (1-`w1',`rho'*(1-`w1') \ `rho'*(1-`w1'),1-`w1')
matrix V2 = (`w1',`rho'*`w1' \ `rho'*`w1',`w1')
matrix M = (0 \ 0)
local obs = _N
unique empid
local emps = r(unique)



tempfile empnormal
tempfile normals
local x= 0
local y = 0


matrix V1 = (1-`x',`rho'*((1-`x')*(1-`y'))^(1/2) \ `rho'*((1-`x')*(1-`y'))^(1/2),1-`y')
    matrix V2 = (`x',`rho'*((`x')*(`y'))^(1/2) \ `rho'*((`x')*(`y'))^(1/2),`y')

* specify 

postfile auctions round workweight injweight listres auctionres bestresult total_shifts using data/01_09_auctionsim_results, replace


forvalues g = 1(1)1000{
    * draw time shocks
    clear
     drawnorm e1 e2, n(`obs') cov(V1) means(M)
    gen mergenum = _n
    save `normals', replace
    
    * draw emp shocks
    clear
     drawnorm c1 c2, n(`emps') cov(V2) means(M)
    gen _idemp = _n
    save `empnormal', replace
    
    use `orig', clear
    qui merge 1:1 mergenum using `normals'
    assert _m==3
    drop _m
    qui merge m:1 _idemp using `empnormal'
    assert _m==3
    drop _m
    
    gen _willwork = zb>e1+c1
    * for the list - randomly assign among positive, if not enough, pick randomly among remainder.
    gen _assignnum = runiform()
    gsort grouped_div analysis_workdate -_willwork _assignnum
    by grouped_div analysis_workdate: gen list_work = _n<=day_div_shifts
    
    ** for the auction
    * randomly divide daily pool of workers
    gen _splitnum = runiform()
    bys grouped_div analysis_workdate _willwork (_splitnum): gen _reg = 1 if _n<=regular_shifts & _willwork==1
    
    * if still missing regular shifts, assign the rest to _additional
    bys grouped_div analysis_workdate (_splitnum): egen _totreg = total(_reg)
    replace additional_shifts = additional_shifts + regular_shifts-_totreg
    
    * assign shifts using auction
    gen _val = raw_zb-e1-c1
    gsort grouped_div analysis_workdate _reg -_val empid
    by grouped_div analysis_workdate _reg: gen _win = 1 if _n<=additional_shifts & _reg!=1
    
    * now calculate injury rates.
    qui gen _inj = xb> (c2+e2)
    
    count if list_work==1 & _inj==1
    local lres=r(N)
     count if _inj==1 & (_win==1 | _reg==1)
    local ares = r(N)
    
    * lower bound
    gen _bestord = xb -e2-c2
    gen _randord = runiform()
    bys grouped_div analysis_workdate _willwork (_randord): gen _regbest = _n<=regular_shifts & _willwork==1
    bys grouped_div analysis_workdate _regbest (_bestord): gen _bestwork = _n<=additional_shifts if _regbest!=1
    count if _inj==1 & (_bestwork==1 | _regbest==1)
    local bres = r(N)
    local tot = total_overall_shifts[1]
    post auctions (`g') (`x') (`y') (`lres') (`ares') (`bres') (`tot')
    

}
postclose auctions

* additional processing
use data/01_09_auctionsim_results, clear

gen pctdiff = (auctionres - listres)/listres
gen diff = (auctionres - listres)/total_shifts
summ pctdiff, d
summ diff, d

gen pctdiff2 = (auctionres-bestres )/auctionres
gen diff2 = (auctionres-bestres )/total_shifts
summ pctdiff2, d
summ diff2, d

*** distributions
replace listres = listres/`N'
replace auctionres = auctionres/`N'
replace bestresult = bestresult/`N'

label variable listres "Random List"
label variable auctionres "Shift Auction"
label variable bestresult "Full Information"
* add this to notes: "Uses Epanechnikov kernel, with STATA's default bandwith optimizer."
twoway kdensity bestresult || kdensity auctionres || kdensity listres , xtitle("Injury Rate (Injuries/Shifts Worked)") ytitle("Density") legend(label(1 "Full Information") label( 2 "Shift Auction") label( 3 "Random List") position(6) cols(3))
graph export out/01_09_distribution_plots.pdf, replace
estpost tabstat listres auctionres bestresult, statistics(mean p5 p95) columns(statistics)
esttab using out/01_09_auction.tex, cells("mean(fmt(4)) p5(fmt(4)) p95(fmt(4))") label nomtitle nonumber replace
 
log close



