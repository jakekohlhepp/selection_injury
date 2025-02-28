clear all
cap log close
cap ssc install binscatter2
set type double
log using log/01_03_descriptives.log, replace
set more off
set scheme cleanplots




********** descripitive statistics of estimation sample.
*** includes dates with no variation.

use data/01_01_estimation_sample, clear
gen real_week = an_week
bys empid (matched_injury analysis_workdate): gen ever_injured = matched_injury[_N]==1
label define injgroup -1 "All" 0 "Not Injured" 1 "Injured"
label values ever_injured injgroup


*** do graphs of instrument relevance
preserve
** remove those on leave

twoway histogram adj_div_8_leave_count,bin(20) fraction ylabel(0(0.1)0.3, nogrid) xlabel(, grid gmax) name(hx, replace) fysize(25)
collapse (mean) work,by(adj_div_8_leave_count)
twoway scatter  work adj_div_8_leave_count , xsca(alt) xlabel(, grid gmax) name(yx, replace) ytitle("Work Probability")
graph combine yx hx,  rows(2) cols(1) imargin(zero) graphregion(margin(l=22 r=22))
graph export out/01_03_leave_instrument_viz.pdf, replace
restore

**** by day of week
preserve
gen r_adj_div_8_leave_count = round(adj_div_8_leave_count,2)
collapse (mean) work,by(r_adj_div_8_leave_count dayofweek)
twoway scatter  work r_adj_div_8_leave_count if r_adj_div_8_leave_count<30 & dayofweek>0 & dayofweek<6,  ytitle("Work Probability") by(dayofweek, legend(off))
twoway scatter  work r_adj_div_8_leave_count if r_adj_div_8_leave_count<30 & (dayofweek==0 | dayofweek==6),  ytitle("Work Probability") by(dayofweek, legend(off))


restore

*** do graphs of selection
preserve
twoway histogram adj_div_8_leave_count,bin(20) fraction ylabel(0(0.1)0.3, nogrid) xlabel(, grid gmax) name(hx, replace) fysize(28)
collapse (mean) matched_injury ,by(adj_div_8_leave_count)
replace matched_injury = matched_injury*100
twoway scatter  matched_injury adj_div_8_leave_count , ylabel(0(0.1)0.3) xsca(alt) xlabel(, grid gmax) name(yx, replace) ytitle("Injury Rate (%)") 
graph combine yx hx,  rows(2) cols(1) imargin(zero) graphregion(margin(l=22 r=22))
graph export out/01_03_selection_binned.pdf, replace
restore


*** main summary table - officer level

preserve
sort empid analysis_workdate
by empid: egen div_total = nvals(main_div) 
collapse (sum) daysworked=work tot_inj=matched_injury (count) days=work, by(empid div_total age_20150101)
assert !missing(age_20150101)
isid empid
label variable div_total "Divisions Worked"
label variable days "Days Observed"
label variable daysworked "Days Worked"
label variable tot_inj "Injuries Observed"

estpost tabstat  days daysworked tot_inj div_total age_20150101, statistics(mean sd p10 p50 p90 ) column(statistics)
esttab using out/01_03_descriptive_officer.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90") collabels("Mean" "Std. Dev." "p10" "p50" "p90") nomtitle nonumber replace label

restore

*** main summary table - officer-date level
preserve


label variable work "Worked"
gen onleave=leave_hours>0
label variable work "Worked"
label variable onleave "On Leave"
label variable matched_injury "Injured"
label variable leave_hours "Hours on Leave"
label variable varot_hours "Overtime Pay Hours"
label variable tot_hours "Hours Worked"

estpost tabstat  work tot_hours varot_hours onleave leave_hours matched_injury adj_div_8_leave_count max_rate seniority_rank, statistics(mean sd p10 p50 p90 ) column(statistics)
esttab using out/01_03_descriptive_officer_date.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90") collabels("Mean" "Std. Dev." "p10" "p50" "p90") nomtitle nonumber replace label

restore


*** distribution across divisions - leave, working, total
preserve
eststo clear

bys analysis_workdate main_div (empid): egen work_count_div = total(work)
gen leave = leave_hours>0
bys analysis_workdate main_div (empid): egen leave_count_div = total(leave)
bys analysis_workdate main_div (empid):gen tot_indiv = _N
bys analysis_workdate main_div (empid): keep if _n==1
eststo clear
keep if main_div>=812 & main_div<=819
bys main_div: eststo: quietly estpost sum leave_count_div work_count_div tot_indiv , listwise
esttab using out/01_03_dists_by_div.tex, cells("mean(fmt(2)) sd(fmt(2))") label nodepvar replace
restore

*** work patterns - hours worked daily
preserve
eststo clear
gen over_8 = tot_hours>8
gen over_12 = tot_hours>12
keep if work==1
sort ever_injured empid analysis_workdate
lab def inj 0 "Not Injured" 1 "Injured", modify
label values ever_injured inj
estpost tabstat tot_hours, statistics(mean sd p10 p50 p90) by(ever_injured)
esttab using out/01_03_daily_hours.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90 ") nomtitle nonumber replace
restore
* test different averages - robust to clustering
reg tot_hours ever_injured if work==1, cluster(empid)

reg tot_hours ever_injured if work==1 & analysis_workdate<=first_inj_date, cluster(empid)

*** work patterns - hours worked weekly
eststo clear
preserve
eststo clear
collapse (sum) daysworked = work (max) max_date = analysis_workdate, by(empid real_week ever_injured first_inj_date)
drop if daysworked==0
estpost tabstat daysworked, statistics(mean sd p10 p50 p90 ) by(ever_injured)
esttab using out/01_03_week_work.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90 ") nomtitle nonumber replace
restore

*** work patterns - hours worked in 4 weeks.
preserve
eststo clear
gen week4 = floor(real_week/4)
collapse (sum) daysworked = work  (max) max_date = analysis_workdate, by(empid week4 ever_injured first_inj_date)
drop if daysworked==0
estpost tabstat daysworked if max_date<=first_inj_date, statistics(mean sd p10 p50 p90) by(ever_injured)
esttab using out/01_03_4week_work.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90") nomtitle nonumber replace
restore

eststo clear
preserve
keep if work==1
estpost tabulate dayofweek, sort
esttab using out/01_03_dayofweek.tex, cells("b(label(freq)) pct(fmt(2)) cumpct(fmt(2))") varlabels(`e(labels)', blist(Total "{hline @width}{break}")) nonumber nomtitle noobs varwidth(15) replace

restore

*** pay statistics - weekly
eststo clear
preserve
drop if work==0 & leave_hours>0
replace ot_pay_amount = 0 if ot_pay_amount==.
replace work_pay_amount = 0 if work_pay_amount==.
collapse (max) max_rate (sum) ot_pay_amount work_pay_amount, by(empid real_week)
gen pct_ot = ot_pay_amount/(work_pay_amount + ot_pay_amount)
label variable max_rate "Hourly Wage"
label variable ot_pay_amount "Overtime Pay"
label variable work_pay_amount "Regular Pay"
label variable pct_ot "Proportion OT"
estpost tabstat max_rate work_pay_amount ot_pay_amount pct_ot, statistics(mean sd p10 p50 p90) columns(statistics)
esttab using out/01_03_paystats.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90") nomtitle nonumber label replace

restore

* do variation description tables
insheet using ../mkdata/out/list_var_desc.csv, clear comma
drop if missing(variation_desc)
rename variation_desc cleaned_variation_desc
replace cleaned_variation_desc= subinstr(cleaned_variation_desc, "%", "\%",1)
gen cat = "work" if work==1
replace cat = "leave" if out_type==1
replace cat = "other" if missing(cat)
keep  cleaned_variation_desc cat
tempfile full
save `full'
clear
set obs 1
gen _ord = 0
gen work = "Work"
gen leave = "Leave"
gen other = "Other"
tempfile top
save `top'
use `full', clear
keep if cat=="other"
sort cleaned_variation_desc
gen _ord=_n
rename cleaned_variation_desc other
tempfile other
save `other'
use `full', clear
keep if cat=="leave"
sort cleaned_variation_desc
gen _ord=_n
rename cleaned_variation_desc leave
tempfile leave
save `leave'
use `full', clear
keep if cat=="work"
sort cleaned_variation_desc
rename cleaned_variation_desc work
gen _ord = _n
merge 1:1 _ord using `leave'
drop _m
merge 1:1 _ord using `other'
drop _m
merge 1:1 _ord using `top'
drop _m
sort _ord
export delimited work leave other using out/01_03_variation_list.txt, replace delimiter(tab) novarnames



*** do binned scatter of injury on leave.


log close
