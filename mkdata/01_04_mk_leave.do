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
rename div main_div
keep employee_name analysis_workdate main_div  flag_div_corrected
tempfile maindiv
save `maindiv'


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
assert tot_hours==0 if main_div ==.

* fill back main_div and standard rate.
gsort employee_name -analysis_workdate
by employee_name: replace main_div = main_div[_n-1] if main_div==.
assert !missing(main_div )

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
gen _test = leave_hours>=8 & tot_hours==0

bys main_div analysis_workdate: egen adj_div_8_leave_count = total(_test)
replace adj_div_8_leave_count = adj_div_8_leave_count - _test 
drop _test


compress
save data/01_05_working_with_leave, replace
log close

