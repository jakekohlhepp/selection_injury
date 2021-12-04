clear all
cap log close
set type double
log using log/01_01_mk_sample.log, replace
set more off
set scheme cleanplots

** Purpose: Estimate additional quantities from the model.
use ../mkdata/data/01_05_working_with_leave, clear
encode employee_name, gen(empid)
gen year = year(analysis_workdate)
gen month = month(analysis_workdate)
gen dayofweek = dow(analysis_workdate)
gen week = week(analysis_workdate)
label define weekday 0 "Sunday" 1 "Monday" 2 "Tuesday" 3 "Wednesday" 4 "Thursday" 5 "Friday" 6 "Saturday"
label values dayofweek weekday
isid employee_name analysis_workdate

gen grouped_div = main_div if main_div>=800
replace grouped_div = 999 if main_div<=800
egen grouped = group(grouped_div analysis_workdate)
gen isweekend = (dayofweek==0 | dayofweek==6)
*** Purpose: Sample restrictions for all analysis programs.


* assume that the data begins in earnest in january of 2015, and trails off in september of 2016.
unique employee_name
keep if analysis_workdate<d(01sep2016) & analysis_workdate>=d(01jan2015)
unique employee_name

* remove part-time employees, defined as those who work less leave+actual work time for more than 3 months.
* construct 4 day periods.
bys empid (analysis_workdate): gen _week = an_week-an_week[1]
gen _grouping4 = floor(_week/4)
gen _tot_time=leave_hours+tot_hours
bys empid _grouping4 (analysis_workdate): egen _tot4weeks = total(_tot_time)
gen _part_time = _tot4weeks<=60
bys empid (analysis_workdate): egen _part_time_count = total(_part_time)
unique empid if _part_time_count>=3

* per suggestion, what is share of hours worked by these part-time employees.
gen _par = _part_time_count>=3
egen _parhours = total(tot_hours*_par)
egen _hours = total(tot_hours)
di _parhours/_hours[1]

drop if _part_time_count>=3

* there are only one day gaps between obs.
bys employee_name (analysis_workdate ): assert analysis_workdate-analysis_workdate[_n-1]==1 if _n>1

* longest gap of no work no leave is 16 days.
gen _gap = leave_hours==0 & tot_hours==0
bys employee_name (analysis_workdate ): gen _stint = _gap!=_gap[_n-1]
bys employee_name (analysis_workdate ): replace _stint=sum(_stint)
bys employee_name _stint (analysis_workdate ): gen stint_length= _N
assert stint_length<=16 if _gap==1
drop stint_length _part_time_count _part_time _tot4weeks _grouping4 _tot_time _parhours _hours _par


* 10 people have injuries on non-work days. 
unique employee_name if matched_injury ==1 & tot_hours==0
gen _tag = matched_injury ==1 & tot_hours==0
* 4 we associate these with the day before
bys employee_name (analysis_workdate): gen _daybefore=1 if tot_hours>0 & _tag[_n+1]==1
bys employee_name (analysis_workdate): gen _daybeforefix=1 if _daybefore[_n-1]==1
count if _daybefore==1
assert r(N)==4
count if _daybeforefix==1
assert r(N)==4
replace matched_injury=1 if _daybefore==1
replace matched_injury = 0 if _daybeforefix==1
* fill in all variables
foreach var of varlist medpd natureofinj claimcause {
    bys empid (analysis_workdate): replace `var' = `var'[_n-1] if _daybefore==1

}

* for six others, we assume injury occured immediately, which is why leave hours is not 0.
assert leave_hours>=8 if _tag==1 & _daybeforefix!=1
gen inj_immediately=_tag==1 & _daybeforefix!=1
gen work = inj_immediately==1 | tot_hours>0
label variable work "Either tot_hours>0 or inj_imm==1"
drop _daybefore _daybeforefix _tag
count if work==1 & tot_hours==0
assert r(N)==6

* make time based on numbers of days worked.
gen _workcounter = work
bys employee_name (analysis_workdate): gen days_worked_since20150101 = sum(_workcounter)
bys employee_name (analysis_workdate): egen tot_days_worked_fullperiod = sum(_workcounter)
drop _workcounter

* exclude anyone that has no time worked in period - this is 9 people.
drop if tot_days_worked_fullperiod==0


*** create some more instrument/helper variables
gen workflag = work==1 | leave_hours >0
bys employee_name (analysis_workdate): gen stints = workflag!=workflag[_n-1]
bys employee_name (analysis_workdate): replace stints = sum(stints)
bys employee_name stints (analysis_workdate): gen stint_length = _N
bys employee_name: egen modelength = mode(stint_length ) if workflag ==1

* need to control for seniority, time at company, age, hours during last 5 shifts
assert !missing(original_hire_date)
gen tenure = (analysis_workdate - dofc(original_hire_date))/365.25
bys analysis_workdate main_div (tenure empid): egen seniority_rank = rank(tenure), field
label variable tenure "Tenure (years)"

bys employee_name (yearsoldonworkdate analysis_workdate): gen an_age = yearsoldonworkdate[1] -(analysis_workdate[1]-d(01jan2015))/365.25
bys employee_name (yearsoldonworkdate analysis_workdate): replace an_age = an_age + (analysis_workdate-d(01jan2015))/365.25
assert !missing(an_age)
gen workhours_last6 = tot_hours_lag1 + tot_hours_lag2 + tot_hours_lag3 + tot_hours_lag4 + tot_hours_lag5 + tot_hours_lag6

* age as of 20150101
bys employee_name (yearsoldonworkdate analysis_workdate): gen age_20150101 = yearsoldonworkdate-(analysis_workdate-d(01jan2015))/365.25
bys employee_name (age_20150101 analysis_workdate): replace age_20150101 = age_20150101[1] if missing(age_20150101)
assert !missing(age_20150101)
bys employee_name (age_20150101 analysis_workdate): assert round(age_20150101-age_20150101[1],0.01)==0
bys employee_name (analysis_workdate): replace age_20150101 = age_20150101[1]
label variable age_20150101 "Age"
label variable max_rate "Wage"
label variable an_age "Age"
label variable seniority_rank "Seniority Rank"
label variable pct_others_indiv_leave "Leave of Coworkers (%)"
label variable adj_div_leave_hours "Leave Hours of Coworkers"

* create value holding date of first observed injury
bys empid matched_injury (analysis_workdate): gen first_inj_date = analysis_workdate if matched_injury==1
bys empid (first_inj_date analysis_workdate): replace first_inj_date = first_inj_date[1]

* what was div day before
bys empid (analysis_workdate): gen div_before = main_div[_n-1]

drop if work==0 & leave_hours>0



label variable matched_injury "Injury"
label variable an_age "Age"
label variable is_holiday "Holiday"
label variable prcp "Amount Rain (in.)"
label variable tmax "Max. Daily Temp."
label variable pct_others_indiv_leave "Leave of Coworkers (%)"
label variable adj_div_leave_hours "Leave of Coworkers (hours)"
label variable adj_div_8_leave_count "Coworkers on Leave"
label variable max_rate "Wage"
label variable tenure "Tenure (years)"
label variable seniority_rank "Seniority Rank"

foreach var of varlist adj_div_8_leave_count max_rate {
    bys empid: egen bar_`var' = mean(`var')
    local label: variable label `var'
    label variable bar_`var' "Avg. `label'"
}


* drop all non-work days before first work day after injury.
gen lastinj = analysis_workdate if matched_injury==1
bys empid (analysis_workdate): replace lastinj = lastinj[_n-1] if matched_inj==0
bys empid lastinj work (analysis_workdate): gen firstworkday = analysis_workdate if work==1 &_n==2
bys empid lastinj (analysis_workdate): replace firstworkday = analysis_workdate[1] if lastinj==.
bys empid lastinj (analysis_workdate): replace firstworkday = firstworkday[_n-1] if firstworkday==.
replace firstworkday =0 if matched_injury==1
keep if analysis_workdate >=firstworkday

* also exclude first day worked after injury.
drop if firstworkday == analysis_workdate

* analysis has date dummies. only keep observations with variation within date.
cap eststo clear
bys analysis_workdate (matched_injury): gen has_datevar = matched_injury[1]!=matched_injury[_N]

save data/01_01_estimation_sample, replace
log close

