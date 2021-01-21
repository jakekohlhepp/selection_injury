clear all
cap log close
set type double
log using log/01_09_auctions.log, replace
set more off
set scheme cleanplots

*** Purpose: perform auction simulations.
use data/01_01_estimation_sample, clear
cap eststo clear
estimates load out/01_07_heckprob_results.ster
estimates esample: if sample_marked

***** chunk added for this module only*****
* proxy the normal amount of labor as the number of standard hours divided by 8
bys main_div (empid analysis_workdate):  egen div_tot_standard = total(varstandard_hours)
bys main_div (empid analysis_workdate):  egen div_tot_shifts = total(work)
*bys main_div (empid analysis_workdate): 
gen frac_additional = (div_tot_shifts-div_tot_standard/8)/div_tot_shifts
replace frac_additional = 0 if frac_additional<0
bys analysis_workdate main_div (empid): egen day_div_shifts = total(work)
gen additional_shifts = round(day_div_shifts*frac_additional)
gen regular_shifts = day_div_shifts-additional_shifts
egen total_overall_shifts = total(work)

****** chunk added for this module only ******
cap eststo clear
estimates load out/01_07_heckprob_results.ster
predict zb, xbsel
predict raw_zb, xbsel
predict xb, xb
replace raw_zb = raw_zb - max_rate*[work]_b[max_rate] - adj_count_any_leave*[work]_b[adj_count_any_leave]

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
sort main_div analysis_workdate empid

tempfile orig
save `orig'

matrix V1 = (1-`w1',`rho'*(1-`w1') \ `rho'*(1-`w1'),1-`w1')
matrix V2 = (`w1',`rho'*`w1' \ `rho'*`w1',`w1')
matrix M = (0 \ 0)
local obs = _N
unique empid
local emps = r(unique)



**** find weight to match observed number of injuries.
* try all weights between 0.01 and 1 by 0.01 (100 weights) - assume unit variances, and correlation only between effects of the same type.

/*
postfile calibration workweight injweight round injcount  using data/01_09_calibration, replace
forvalues y = 0(0.1)1{
forvalues x = 0(0.1)1{
    forvalues r = 1(1)20{
    matrix V1 = (1-`x',`rho'*((1-`x')*(1-`y'))^(1/2) \ `rho'*((1-`x')*(1-`y'))^(1/2),1-`y')
    matrix V2 = (`x',`rho'*((`x')*(`y'))^(1/2) \ `rho'*((`x')*(`y'))^(1/2),`y')
    qui{
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

        gen _work = zb>(c1+e1)
        gen _inj = xb> (c2+e2)
        qui count if _inj==1 & _work==1
        post calibration (`x') (`y') (`r') (r(N))
       }
    }
    di "y=`y', x=`x' complete"
 }
}
postclose calibration
*/

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
    gsort main_div analysis_workdate -_willwork _assignnum
    by main_div analysis_workdate: gen list_work = _n<=day_div_shifts
    
    ** for the auction
    * randomly divide daily pool of workers
    gen _splitnum = runiform()
    bys main_div analysis_workdate _willwork (_splitnum): gen _reg = 1 if _n<=regular_shifts & _willwork==1
    
    * if still missing regular shifts, assign the rest to _additional
    bys main_div analysis_workdate (_splitnum): egen _totreg = total(_reg)
    replace additional_shifts = additional_shifts + regular_shifts-_totreg
    
    * assign shifts using auction
    gen _val = raw_zb-e1-c1
    gsort main_div analysis_workdate _reg -_val empid
    by main_div analysis_workdate _reg: gen _win = 1 if _n<=additional_shifts & _reg!=1
    
    * now calculate injury rates.
    qui gen _inj = xb> (c2+e2)
    
    count if list_work==1 & _inj==1
    local lres=r(N)
     count if _inj==1 & (_win==1 | _reg==1)
    local ares = r(N)
    
    * lower bound
    gen _bestord = xb -e2-c2
    gen _randord = runiform()
    bys main_div analysis_workdate _willwork (_randord): gen _regbest = _n<=regular_shifts & _willwork==1
    bys main_div analysis_workdate _regbest (_bestord): gen _bestwork = _n<=additional_shifts if _regbest!=1
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
replace listres = listres/181597
replace auctionres = auctionres/181597
replace bestresult = bestresult/181597

label variable listres "Random List"
label variable auctionres "Shift Auction"
label variable auctionres "Full Information"
* add this to notes: "Uses Epanechnikov kernel, with STATA's default bandwith optimizer."
twoway kdensity bestresult || kdensity auctionres || kdensity listres , xtitle("Injury Rate (Injuries/Shifts Worked)") ytitle("Density") legend(label(1 "Full Information") label( 2 "Shift Auction") label( 3 "Random List") position(6) cols(3))
graph export out/01_09_distribution_plots.pdf, replace

log close



