clear
cap log close
set type double
log using log/01_02_mk_expanded_pay.log, replace
set more off 
cap ssc install unique
local print_pic ="yes"
set scheme cleanplots 
//Purpose: Expand the pay data to have an ob for every day for each person and to do cumulative sums of each var. 

*** create some charts with various statistics of the two data sources.
use data/pay_data, clear
gen year = year(dofc(work_date))
* histograms of pay codes. 
gen month=mofd(dofc(work_date))
format month %tmCCYY
label variable month "Month of Work Date"
gen outlier = 1 if year(dofc(work_date))<=2013
drop if outlier==1
hist month, discrete density
if "`print_pic'"=="yes" graph export out/freq_work.pdf, replace
tostring year, replace
bys employee_name year: gen unique_emps=1 if _n==1
bys variation_desc year: gen unique_codes=1 if _n==1
bys employee_name work_date: gen unique_persondays=1 if _n==1
tempfile all
save `all'
replace year = "Overall"
replace unique_emps = .
drop unique_codes
bys variation_desc: gen unique_codes=1 if _n==1
bys employee_name: replace unique_emps=1 if _n==1
append using `all'
gen recs=1
collapse (count) recs unique_persondays unique_emps unique_codes , by(year)
outsheet using out/01_02_work_data_counts.csv, comma replace

use data/workers_comp, clear
tempfile forgrand
save `forgrand'
preserve
replace natureofinjury = "All Types"
append using `forgrand'
gen emp_count =1 
replace natureofinjury = subinstr(natureofinjury, "Multiple", "Mult",.) if strpos(natureofinjury, "Mult ")>0
replace natureofinjury = subinstr(natureofinjury, "Incl", "Include",.) if strpos(natureofinjury, "Incl ")>0
replace natureofinjury = subinstr(natureofinjury, " (e.g.,", "",.) if strpos(natureofinjury, " (e.g., ")>0
replace natureofinjury = subinstr(natureofinjury, ",", "",.)
collapse (count) emp_count, by(natureofinjury)
gen last = natureofinjury == "All Types"
sort last natureofinjury
gen percent = emp_count/emp_count[_N]
gen ovrl = natureofinjury=="All Types"
gsort ovrl -emp_count 
drop ovrl
outsheet using out/01_02_nature.csv, comma replace
restore
preserve
replace claimcausegroup = "All Types"
append using `forgrand'
gen emp_count =1 
collapse (count) emp_count, by(claimcausegroup)
gen last = claimcausegroup == "All Types"
sort last claimcausegroup
gen percent = emp_count/emp_count[_N]
gen ovrl = claimcausegroup=="All Types"
gsort ovrl -emp_count 
outsheet using out/01_02_cause.csv, comma replace
restore
gen month=mofd(doi)
label variable month "Month of Date of Injury"
format month %tmCCYY
gen outlier = 1 if year(doi)<=2013
hist month, discrete density  subtitle("Outliers Included")
if "`print_pic'"=="yes" graph export out/01_02_freq_compclaims.pdf, replace
hist month if outlier!=1, discrete density subtitle("Outliers Excluded")
if "`print_pic'"=="yes" graph export out/01_02_freq_compclaims_nooutliers.pdf, replace
****

use data/pay_data, clear
gen term_observed = cleaned_variation_desc =="TERMINATION CODE /  HOURS NO PAY"
* only work pay codes.
keep if work==1 | strpos(variation_description, "IOD")>0 | out_type==1 | term_observed==1
* examine the effective rate.
gen test_rate = pay_amount/hours
* remove 0 test rates from hours worked.
drop if test_rate==0 & work==1

* zero out hours for iod shifts, termination shifts.
gen iod_flag = 1 if strpos(variation_description, "IOD")>0
* are the following unique within person-day?
bys employee_name work_date: assert dept==dept[1]
bys employee_name work_date: assert job_class_title==job_class_title[1]

* collapse to day. we allow corrections (negatives to cancel out hours)
gen varot_hours = hours if strpos(lower(variation_description), "overtime")>0
replace varot_hours= 0 if missing(varot_hours)
gen varstandard_hours = hours if strpos(lower(variation_description), "overtime")==0
replace varstandard_hours=0 if missing(varstandard_hours)

gen types = "not leave" if work==1 | iod_flag==1 | term_observed==1
replace types = cleaned_variation_desc if out_type==1
assert !missing(types)

* by person, choose the var_rate that is highest. note that all regular base rates are less than 40.
* so any rates over 40 are clearly not work pay rates.
assert var_rate<34 if work==1
tab variation_description if var_rate>34
by employee_name work_date: egen max_rate = max(var_rate)
assert max_rate>=0
replace max_rate = -99 if max_rate>34


gen ot_pay_amount = pay_amount*(strpos(lower(variation_description), "overtime")>0)
gen work_pay_amount = pay_amount*work
collapse (sum) tot_hours = hours varstandard_hours varot_hours work_pay_amount ot_pay_amount (firstnm) iod_flag term_observed, by(employee_name work_date dept yearsoldonworkdate job_class_title div types sick_subset maximum_gap_2015 max_rate gap_end)

* for the categories of leave time, zero out negatives so things don't cancel across categories
replace tot_hours=0 if tot_hours<0 & types!="not leave"

* now collapse to just leave vs not leave.
replace types = "leave" if types!="not leave"
preserve
keep if sick_subset==1
tempfile add
save `add'
restore
replace sick_subset=.
append using `add'

collapse (sum) tot_hours varstandard_hours varot_hours work_pay_amount ot_pay_amount (firstnm) iod_flag term_observed, by(employee_name work_date dept yearsoldonworkdate job_class_title div types sick_subset maximum_gap_2015 max_rate gap_end)

* now create separate var for leave time and zero out tot_hours for leave time and sum it all.
gen leave_hours = tot_hours if types=="leave"
replace leave_hours =0 if types=="not leave"
assert !missing(leave_hours)
gen sick_hours = tot_hours if sick_subset==1
replace sick_hours=0 if sick_subset!=1
replace tot_hours=0 if types=="leave"
collapse (sum) tot_hours leave_hours sick_hours varstandard_hours varot_hours work_pay_amount ot_pay_amount (firstnm) iod_flag term_observed, by(employee_name work_date dept yearsoldonworkdate job_class_title div maximum_gap_2015 max_rate gap_end)

bys employee_name work_date (tot_hours div): assert _N<=2
bys employee_name work_date (tot_hours div): gen div1 = div[1]
bys employee_name work_date (tot_hours div): gen div2 = div[2]
bys employee_name work_date (tot_hours div): gen lhours_1 = leave_hours[1]
bys employee_name work_date (tot_hours div): gen lhours_2 = leave_hours[2]
bys employee_name work_date (tot_hours div): gen shours_1 = sick_hours[1]
bys employee_name work_date (tot_hours div): gen shours_2 = sick_hours[2]
collapse (sum) leave_hours tot_hours sick_hours varstandard_hours varot_hours work_pay_amount ot_pay_amount (firstnm) iod_flag term_observed, by(employee_name work_date dept yearsoldonworkdate job_class_title div1 div2 maximum_gap_2015 max_rate lhours_1 lhours_2 shours_1 shours_2 gap_end)

isid employee_name work_date

*** tabulate rates
summ max_rate, d
count if max_rate==-99
assert max_rate<=34
* allow fill down for these rates
assert !missing(max_rate)
replace max_rate=. if max_rate==-99
bys employee_name (work_date): replace max_rate=max_rate[_n-1] if missing(max_rate)
assert !missing(max_rate)


**** NOTE: We zero one situation with negative total hours (36 total but only 1 after 01jan2015)
gen flag_hours_zeroed = tot_hours<0
replace tot_hours=0 if tot_hours<0
gen analysis_workdate=dofc(work_date)
format analysis_workdate %td

************** merge on injuries.
gen doi = analysis_workdate
merge m:1 employee_name doi using data/workers_comp, keepusing(timeofinj natureofinjury bodypart claimcause claimcausegroup contribcause medpd)
format doi %td

* check merge
bys employee_name (_m analysis_workdate ): gen flag=1 if _m[1]==_m[_N] & _m[1]==2
assert flag!=1
drop flag 
replace analysis_workdate = doi if missing(analysis_workdate)
gen matched_injury =_m==3
drop _m

* fix variables
replace tot_hours = 0 if missing(tot_hours)
replace varstandard_hours=0 if missing(varstandard_hours)
replace varot_hours = 0 if missing(varot_hours)
replace leave_hours = 0 if missing(leave_hours)
replace sick_hours=0 if missing(sick_hours)

sort employee_name analysis_workdate

qui levelsof employee_name, local(emps)
tempfile all
save `all'
clear
tempfile output
save `output', emptyok
foreach emp of local emps {
	use `all', clear
	keep if employee_name=="`emp'"
	tsset, clear
	tsset analysis_workdate
	tsfill
	replace employee_name = employee_name[1]
    replace maximum_gap_2015=maximum_gap_2015[1]
	append using `output'
	save `output', replace
	
}

replace tot_hours = 0 if missing(tot_hours) // this is crucial.
replace leave_hours = 0 if missing(leave_hours)
replace sick_hours =0 if missing(sick_hours)
replace matched_injury = 0 if matched_injury==.
isid employee_name analysis_workdate
sort employee_name analysis_workdate
by employee_name: replace dept=dept[_n-1] if missing(dept)
by employee_name: replace max_rate=max_rate[_n-1] if missing(max_rate)

assert tot_hours!=.
gen not_worked = tot_hours==0 //important flag.
label variable not_worked "Created to denote observations created to fill in time gaps."
foreach var of varlist tot_hours varstandard_hours varot_hours {
	replace `var' = 0 if missing(`var')
	by employee_name: gen cum_`var'=`var' if _n==1
	by employee_name: replace cum_`var'=cum_`var'[_n-1]+`var' if _n!=1

}

label variable cum_varot_hours "Cum. Sum. of all OT Hours Based on Var Desc."

drop work_date
assert !missing(analysis_workdate)

*** for the gap: fill the gap backwards until we observe leave hours or work hours.
gsort employee_name -analysis_workdate
by employee_name: replace gap_end = gap_end[_n-1] if tot_hours==0 & leave_hours==0
* for things not in the gap, set gap to -1
replace gap_end = -1 if missing(gap_end)
replace gap_end = -1 if gap_end==analysis_workdate


************** re-attach identifying information like hire date, etc. 
merge m:1 employee_name using data/employee_data, keepusing(original_hire_date job_end_date job_status)
assert _m!=1
drop if _m==2
drop _m
assert !missing(original_hire_date) & !missing(job_status)

* make a rolling varcode ot for the last seven days.
bys employee_name (analysis_workdate): gen roll_7days_varot_hours = varot_hours+varot_hours[_n-1]+varot_hours[_n-2]+ varot_hours[_n-3]+varot_hours[_n-4]+varot_hours[_n-5]+varot_hours[_n-6] if _n>=7
label variable roll_7days_varot_hours "Rolling sum of OT Based on var Desc"

***** WEEKLY *************************************
* a week is defined as Sunday to Saturday. 
* all hours over 40 are considered weekly overtime. 
gen an_week = wofd(analysis_workdate)
gen an_month= mofd(analysis_workdate)
format an_week %tw 
bys employee_name an_week (analysis_workdate): gen _temp = max(cum_tot_hours - cum_tot_hours[1]-40+tot_hours[1], 0)
assert _temp!=.
bys employee_name an_week  (_temp analysis_workdate): gen exp_40wk=_temp[_N]>0
bys employee_name an_month  (_temp analysis_workdate): gen m_exp_40wk=_temp[_N]>0
bys employee_name an_month (analysis_workdate): gen m_weekly_overtime_40 = sum(_temp)
label variable m_weekly_overtime_40 "Month sum of all Hours Worked Over 40 in a Week"
label variable exp_40wk "Worked more than 40 hours this week?"
label variable m_exp_40wk "Worked more than 40 hours in a week this month?"
drop _temp 
* all hours over 60 are considered weekly overtime. 
bys employee_name an_week (analysis_workdate): gen _temp = max(cum_tot_hours - cum_tot_hours[1]+tot_hours[1]-60, 0)
assert _temp!=.
bys employee_name an_week  (_temp analysis_workdate): gen exp_60wk=_temp[_N]>0
bys employee_name an_month  (_temp analysis_workdate): gen m_exp_60wk=_temp[_N]>0
bys employee_name an_month (analysis_workdate): gen m_weekly_overtime_60 = sum(_temp)
label variable m_weekly_overtime_60 "Month Sum of all Hours Worked Over 60 in A Week"
label variable exp_60wk "Worked more than 60 hours this week?"
label variable m_exp_60wk "Worked more than 60 hours in a week this month?"
drop _temp 

* all hours over 8 in a day 
gen _temp = max(tot_hours - 8,0)
assert _temp!=.
bys employee_name an_week  (_temp analysis_workdate): gen exp_8day=_temp[_N]>0
bys employee_name an_month  (_temp analysis_workdate): gen m_exp_8day=_temp[_N]>0
bys employee_name an_month (analysis_workdate): gen m_daily_overtime_8 = sum(_temp)
label variable m_daily_overtime_8 "Sum of all Hours Worked Over 8 in a Day this month"
label variable exp_8day "Worked more than 8 hours in a day this week?"
label variable m_exp_8day "Worked more than 8 hours in a day this month?"
* hours worked over 8 in a day in the last 7 days
bys employee_name (analysis_workdate): gen r_over8day_2days = _temp + _temp[_n-1] if _n>=7
label variable r_over8day_2days "Rolling sum of hours over 8, 2 day"
bys employee_name (analysis_workdate): gen r_over8day_7days = _temp + _temp[_n-1] + _temp[_n-2]+_temp[_n-3]+_temp[_n-4]+_temp[_n-5]+_temp[_n-6] if _n>=7
label variable r_over8day_7days "Rolling sum of hours over 8 in a day 7 window"
drop _temp

* all hours over 12 in a day 
gen _temp = max(tot_hours - 12,0)
assert _temp!=.
bys employee_name an_week  (_temp analysis_workdate): gen exp_12day=_temp[_N]>0
bys employee_name an_month  (_temp analysis_workdate): gen m_exp_12day=_temp[_N]>0
bys employee_name (analysis_workdate): gen m_daily_overtime_12 = sum(_temp)
label variable m_daily_overtime_12 "Sum of all Hours Worked Over 12 in a day this month"
label variable exp_12day "Worked more than 12 hours in a day this week?"
label variable m_exp_12day "Worked more than 12 hours in a day this month?"

* hours worked over 12 in a day in the last 7 days
bys employee_name (analysis_workdate): gen r_over12day_7days = _temp + _temp[_n-1] + _temp[_n-2]+_temp[_n-3]+_temp[_n-4]+_temp[_n-5]+_temp[_n-6] if _n>=7
label variable r_over12day_7days "Rolling sum of hours over 12 in a day 7 window"
bys employee_name (analysis_workdate): gen r_over12day_2days = _temp + _temp[_n-1] if _n>=7
label variable r_over12day_2days "Rolling sum of hours over 12, 2 day"
drop _temp

* count of instances with 7 days worked in a week
* Note: considered exposed if the final day of the streak is in the month/week
bys employee_name (analysis_workdate): gen _temp = (tot_hours>0 & !inlist(tot_hours[_n-1], .,0)  & !inlist(tot_hours[_n-2], .,0) & !inlist(tot_hours[_n-3], .,0) & !inlist(tot_hours[_n-4], .,0) & !inlist(tot_hours[_n-5], .,0) & !inlist(tot_hours[_n-6], .,0) )
assert _temp!=.
bys employee_name an_week  (_temp analysis_workdate): gen exp_7days=_temp[_N]>0
bys employee_name an_month  (_temp analysis_workdate): gen m_exp_7days=_temp[_N]>0
label variable exp_7days "Worked 7 days straight this week?"
label variable m_exp_7days "Worked 7 days straight this month?"
drop _temp

*** more rolling variables: (note not valid for first 7 obs)

* hours worked over 40 in the last 7 days (including the day itself)
bys employee_name (analysis_workdate): gen r_over40_7day = max(cum_tot_hours - cum_tot_hours[_n-6]-40+tot_hours[_n-6], 0) if _n>=7
label variable r_over40_7day "Rolling sum of hours over 40 in 7 day window"
* 2 days
bys employee_name (analysis_workdate): gen r_over40_2day = max(cum_tot_hours - cum_tot_hours[_n-1]-40+tot_hours[_n-1], 0) if _n>=7
label variable r_over40_2day "Rolling sum of hours over 40 in 2 day window"

* hours worked over 60 in the last 7 days (including the day itself)
bys employee_name (analysis_workdate): gen r_over60_7day = max(cum_tot_hours - cum_tot_hours[_n-6]-60+tot_hours[_n-6], 0) if _n>=7
label variable r_over60_7day "Rolling sum of hours over 60 in 7 day window"
* 2 days
bys employee_name (analysis_workdate): gen r_over60_2day = max(cum_tot_hours - cum_tot_hours[_n-1]-60+tot_hours[_n-1], 0) if _n>=7
label variable r_over60_2day "Rolling sum of hours over 60 in 2 day window"

* days worked
bys employee_name (analysis_workdate): gen r_workeddays_7day = tot_hours>0 + tot_hours[_n-1]>0 + tot_hours[_n-2]>0 + tot_hours[_n-3]>0 +tot_hours[_n-4]>0  +tot_hours[_n-5]>0+tot_hours[_n-6]>0 if _n>=7
label variable r_workeddays_7day "Rolling sum of days worked in 7 day window"
bys employee_name (analysis_workdate): gen r_workeddays_2day = tot_hours>0 + tot_hours[_n-1]>0 if _n>=7
label variable r_workeddays_2day "Rolling sum of days worked in 2 day window"

* add on hours worked for each lag
forvalues x = 1(1)6 {
	bys employee_name (analysis_workdate): gen tot_hours_lag`x' =tot_hours[_n-`x']
}


** add on weather
gen date = analysis_workdate

merge m:1 date using 20190811_weather/data/weather_daily
assert _m!=1 if analysis_workdate>=d(01jan2015)
drop if _m==2
drop _m

** add holidays
merge m:1 date using 20190814_fed_holidays/data/holidays
drop if _m==2
gen is_holiday = _m==3
drop _m
drop date

gen rain = prcp>0

label variable is_holiday "HOLIDAY"
label variable tmax "MAX. TEMP."
label variable rain "RAIN"
label variable work_pay_amount "Pay from Work Pay Codes"
label variable ot_pay_amount "Pay from OT Pay Codes"
label variable medpd "Medical Expenses Paid"

confirm variable maximum_gap_2015
compress
save data/working_expanded, replace



log close






