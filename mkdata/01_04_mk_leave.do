clear
cap log close
set type double
log using log/01_04_mk_leave.log, replace
set more off 


//Purpose: Create data-set of leave-time by day by division. merge this on to the final working data-set 
* flag work leave codes based on description - use inputted data
insheet using out/list_var_desc.csv, clear comma
drop if missing(variation_desc)

rename variation_desc cleaned_variation_desc
tempfile info
save `info'

** find the main division worked and the typical payrate. use work paycodes.
use data/pay_data, clear
gen analysis_workdate=dofc(work_date)
format analysis_workdate %td
merge m:1 cleaned_variation_desc using `info'
assert _m==3
drop _m 

gen leave_code = out_type==1
bys employee_name work_date (work): gen any_work=work[_N]==1
replace div =. if div <=808
keep if variation_desc=="CURRENT ACTUAL HOURS WORKED ONLY"
bys employee_name work_date (div): gen tag =div[1]!=div[_N]
tab employee_name if tag==1
* for these 4, code their div manually. it appears that it is clear which div each worked for primarily.
* 379 has 8 and 811. 8 appears to not be a div but some other admin code. code as 811
* 425 has 6 and 811. 6 appears to be admin code so code as 811
* emp 501 has correction. after correction only div 812 remains. code as 812
* emp 583 has correction. 819 appears correct afterwards.
replace div = 811 if employee_name=="EMPLOYEE 379" & tag==1
replace div = 811 if employee_name=="EMPLOYEE 425" & tag==1
replace div = 812 if employee_name=="EMPLOYEE 501" & tag==1
replace div = 819 if employee_name=="EMPLOYEE 583" & tag==1

gen flag_div_corrected = inlist(employee_name, "EMPLOYEE 379", "EMPLOYEE 425", "EMPLOYEE 501", "EMPLOYEE 583") & tag==1
bys employee_name analysis_workdate (div): assert div==div[1]
drop if hours<0
bys employee_name analysis_workdate (div): keep if _n==1
keep employee_name analysis_workdate div  flag_div_corrected
gen main_div=div
tempfile maindiv
save `maindiv'

** save out dates with just bereavement
use data/pay_data, clear
gen analysis_workdate=dofc(work_date)
format analysis_workdate %td
gen bereavement = strpos(strlower(variation_desc), "bereave")>0
gen jury_duty = strpos(strlower(variation_desc), "jury duty")>0
keep if jury_duty==1 | bereavement==1
keep jury_duty bereavement analysis_workdate employee_name
duplicates drop
tempfile other
save `other'

* now add this to the working data. determine which div the employee mainly works
use data/working_expanded, clear
gen took_leave = leave_hours>0

* merge main div
merge 1:1 employee_name analysis_workdate using `maindiv'
assert _m!=2
drop _m

* fill down the main_div
bys employee_name (analysis_workdate): replace main_div = main_div[_n-1] if main_div==.

* otherwise fill in with div1
replace main_div = div1 if div2==. & main_div==.

* then fill down again
bys employee_name (analysis_workdate): replace main_div = main_div[_n-1] if main_div==.


* fill back main_div and standard rate.
gsort employee_name -analysis_workdate
by employee_name: replace main_div = main_div[_n-1] if main_div==.

* those missing division now never have a division
unique employee_name if missing(main_div)
unique employee_name 
drop if missing(main_div)
unique employee_name

* construct leave/sick measures
* all are based on percentages of division
bys main_div analysis_workdate: gen div_emps = _N
bys main_div analysis_workdate: egen tot_working = total(tot_hours)
bys main_div analysis_workdate: egen tot_leave = total(leave_hours)

* leave.
gen _test=leave_hours>0
bys main_div analysis_workdate: egen div_leave_count=total(_test)
gen pct_others_indiv_leave = (div_leave_count - _test)/(div_emps-1)
gen adj_div_leave_count = div_leave_count - _test
* when you are the only person in div on that day, assume 0%
replace pct_others_indiv_leave =  0 if div_emps==1
assert !missing(pct_others_indiv_leave)
assert pct_others_indiv_leave<=1
drop _test

* removing sick
gen _test=leave_hours-sick_hours>=8
bys main_div analysis_workdate: egen alt_leave_nosick = total(_test)
replace alt_leave_nosick =  alt_leave_nosick- _test 
drop _test

gen _test = leave_hours>=8
bys main_div analysis_workdate: egen div_leave_8_count = total(_test)
drop _test

* hours of leave among those who did not work at all
gen _test = leave_hours if tot_hours==0
replace _test = 0 if tot_hours!=0
bys main_div analysis_workdate: egen adj_div_leave_hours = total(_test)
replace adj_div_leave_hours = adj_div_leave_hours - _test 
drop _test


* count of emps on leave who did not work at all and took more than 8 hours of leave
gen adj_leave = leave_hours>=8 & tot_hours==0
bys main_div analysis_workdate: egen tot_div_8_leave_count = total(adj_leave)
bys main_div analysis_workdate: egen adj_div_8_leave_count = total(adj_leave)
replace adj_div_8_leave_count = adj_div_8_leave_count - adj_leave 


* need to control for seniority, time at company, age, hours during last 5 shifts
assert !missing(original_hire_date)
gen tenure = (analysis_workdate - dofc(original_hire_date))/365.25
label variable tenure "Tenure (years)"

* for two emps, original hire date is after the work date.
* either these are non-work days or they occur before analysis window.
assert tot_hours==0 | analysis_workdate<=d(01jan2015) if tenure<0
drop if tenure<0

merge 1:1 employee_name analysis_workdate using `other'
drop if _m==2
drop _m
replace bereavement = 0 if bereavement==.
replace jury_duty = 0 if jury_duty==.


* rank by seniority many different ways
bys analysis_workdate main_div (tenure employee_name): egen seniority_rank_indiv = rank(tenure), field
bys analysis_workdate (tenure employee_name): egen seniority_rank = rank(tenure), field

* get seniority rank in div from prior calendar week
gen lastday_lastweek = analysis_workdate-dow(analysis_workdate)-1
preserve
keep employee_name analysis_workdate seniority_rank_indiv
rename analysis_workdate lastday_lastweek 
rename seniority_rank_indiv lastweek_seniority_rank_indiv
tempfile hold
save `hold'
restore
merge m:1 employee_name lastday_lastweek  using `hold'
drop if _m==2
drop _m

* get seniority rank in entire org for prior month
gen lastday_lastmonth = firstdayofmonth(analysis_workdate)-1
preserve
keep employee_name analysis_workdate seniority_rank
rename analysis_workdate lastday_lastmonth 
rename seniority_rank lastmonth_seniority_rank
tempfile hold
save `hold'
restore
merge m:1 employee_name lastday_lastmonth  using `hold'
drop if _m==2
drop _m


preserve
keep if adj_leave==1
keep seniority_rank_indiv main_div analysis_workdate
bys main_div analysis_workdate (seniority_rank_indiv): gen ord = _n
reshape wide  seniority_rank_indiv,i(main_div analysis_workdate) j(ord)
tempfile bydiv
save `bydiv'
restore
merge m:1 main_div analysis_workdate using `bydiv'
assert _m!=2
drop _m
capture confirm variable seniority_rank_indiv62
assert _rc!=0

* if rank of those out exceeds, increase my rank

gen leave_below = 0

foreach var of varlist seniority_rank_indiv* {
    replace leave_below = leave_below + (seniority_rank_indiv<`var')*(`var'!=.)
}


gen leave_above = 0

foreach var of varlist seniority_rank_indiv* {
    replace leave_above = leave_above + (seniority_rank_indiv>`var')*(`var'!=.)
}

preserve
keep if adj_leave==1
bys analysis_workdate (employee_name): gen ord = _n
keep lastmonth_seniority_rank analysis_workdate ord
reshape wide  lastmonth_seniority_rank,i(analysis_workdate) j(ord)
tempfile byorg
save `byorg'
restore
merge m:1 analysis_workdate using `byorg'
assert _m!=2
drop _m


capture confirm variable lastmonth_seniority_rank277
assert _rc!=0

gen leave_below_lastmonth_org = 0

foreach var of varlist lastmonth_seniority_rank* {
    replace leave_below_lastmonth_org = leave_below_lastmonth_org + (lastmonth_seniority_rank<`var')*(`var'!=.)
}


gen leave_above_lastmonth_org = 0

foreach var of varlist lastmonth_seniority_rank* {
    replace leave_above_lastmonth_org = leave_above_lastmonth_org + (lastmonth_seniority_rank>`var')*(`var'!=.)
}

rename lastmonth_seniority_rank sen_rank_lastmonth_org
rename seniority_rank_indiv sen_rank_today_div

drop seniority_rank_indiv* lastmonth_seniority_rank*

preserve
keep if !missing(job_class_title)
bys employee_name (analysis_workdate): assert job_class_title==job_class_title[1]
keep employee_name job_class_title
duplicates drop
tempfile title
save `title'
restore

compress
save data/01_05_working_with_leave, replace
log close

