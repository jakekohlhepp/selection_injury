clear all
cap log close
set type double
log using log/01_03_summary_stats.log, replace
set more off
set scheme cleanplots

//Purpose: create summary tables

* do variation description tables
insheet using /out/list_var_desc.csv, clear comma
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


use data/01_01_estimation_sample, clear
gen real_week = an_week
bys empid (matched_injury analysis_workdate): gen ever_injured = matched_injury[_N]==1
label define injgroup -1 "All" 0 "Not Injured" 1 "Injured"
label values ever_injured injgroup

*** injury frequency
preserve
collapse (sum) matched_injury, by(empid)
label variable matched_injury "Total Injuries"
estpost tabulate matched_injury, sort
esttab using out/01_03_injcount.tex, cells("b(label(freq)) pct(fmt(2))") varlabels(`e(labels)', blist(Total "{hline @width}{break}")) nonumber nomtitle noobs varwidth(30) addnotes("Among estimation sample: Full-time officers between Jan. 2015 and Sept. 2016.") replace


restore


*** basics - age, division changes, tenure by injury groups.
preserve
eststo clear
drop if work==0 & leave_hours>0
sort ever_injured empid analysis_workdate
lab def inj 0 "Not Injured" 1 "Injured", modify
label values ever_injured inj
bys empid main_div (analysis_workdate): gen div_count = _n==1
bys empid (analysis_workdate): egen div_total = total(div_count)
label variable div_total "Divisions Worked In"
bys empid (analysis_workdate): keep if _n==1
estpost tabstat age_20150101 tenure div_total, statistics(mean sd p10 p50 p90 ) by(ever_injured) column(statistics)
esttab using out/01_03_demographic.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90") nomtitle nonumber replace label
restore
*** types of injury
preserve
eststo clear

keep if matched_injury==1
estpost tabulate claimcause, sort
esttab using out/01_03_claimcause.tex, cells("b(label(freq)) pct(fmt(2))") varlabels(`e(labels)', blist(Total "{hline @width}{break}")) nonumber nomtitle noobs varwidth(30) replace
estpost tabulate natureofinj, sort
esttab using out/01_03_nature_inj.tex, cells("b(label(freq)) pct(fmt(2))") varlabels(`e(labels)', blist(Total "{hline @width}{break}")) nonumber nomtitle noobs varwidth(30)  replace
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


*** individual level heterogeneity
preserve
eststo clear
gen week4 = floor(real_week/4)
collapse (sum) daysworked = work  (max) max_date = analysis_workdate, by(empid week4 ever_injured first_inj_date)
drop if daysworked==0
estpost tabstat daysworked if max_date<=first_inj_date, statistics(mean sd p10 p50 p90) by(ever_injured)
esttab using out/01_03_4week_work.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90") nomtitle nonumber replace
restore

*** leave - by division - sick and leave
preserve
drop if work==0 & leave_hours>0
eststo clear
replace grouped_div = 888 if (grouped_div>=800 & grouped_div<=810) | grouped_div==828 | grouped_div==824
bys grouped_div analysis_workdate (empid): keep if _n==1
lab def inj 999 "Other" 888 "800 - 810, 824, 828,", modify
lab values grouped_div inj
label variable div_count_any_leave "Officers with Positive Leave"
label variable div_count_any_sick "Officers with Positive Sick"
label variable div_leavehours "Total Leave Hours"
estpost tabstat div_count_any_leave div_count_any_sick div_leavehours, statistics(mean sd p10 p50 p90) by(grouped_div) columns(statistics)
esttab using out/01_03_leave_bydiv.tex, cells("mean(fmt(2)) sd(fmt(2)) p10 p50 p90") nomtitle nonumber replace label
restore


*** plot the percentage of rest of division working 
preserve
drop if work==0 & leave_hours>0
bys main_div analysis_workdate (empid): egen count_working = total(work)
bys main_div analysis_workdate (empid): egen total_indiv_notleave = total(leave_hours==0 | work==1)
bys main_div analysis_workdate: keep if _n==1
gen pct_working = count_working/total_indiv_notleave
label variable pct_working "% of Officers Not on Leave Working"
label variable div_count_any_leave "# Officers On Leave"
twoway (scatter pct_working div_count_any_leave, msize(tiny) mcolor(green) msymbol(O) jitter(3))
graph export out/01_03_leave_pct_work.pdf, replace
corr pct_working div_count_any_leave if pct_working<=0.2
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


*** do graphs of instrument relevance
preserve
bys adj_count_any_leave: egen mean_work = mean(work)
twoway histogram adj_count_any_leave,bin(20) fraction ylabel(0(0.1)0.3, nogrid) xlabel(, grid gmax) name(hx, replace) fysize(25) 
collapse (mean) work, by(adj_count_any_leave)
twoway lowess  work adj_count_any_leave , xsca(alt) xlabel(, grid gmax) name(yx, replace) ytitle("Smoothed Injury Probability")
graph combine yx hx,  rows(2) cols(1) imargin(zero) graphregion(margin(l=22 r=22))
graph export out/01_03_leave_instrument_viz.pdf, replace
restore

preserve
bys adj_count_any_leave: egen mean_work = mean(work)
twoway histogram lag_first_contact,bin(38) fraction ylabel(0(0.06)0.18, nogrid) xlabel(, grid gmax) name(hx, replace) fysize(25)
gen floor_first_contact = floor(lag_first_contact/5)*5
label variable floor_first_contact "Cumulative Officer Potential Contacts"
collapse (mean) work, by(floor_first_contact)
twoway lowess  work floor_first_contact , xsca(alt) xlabel(, grid gmax) name(yx, replace) ytitle("Smoothed Injury Probability")
graph combine yx hx,  rows(2) cols(1) imargin(zero) graphregion(margin(l=22 r=22))
graph export out/01_03_contacts_instrument_viz.pdf, replace
restore


log close


