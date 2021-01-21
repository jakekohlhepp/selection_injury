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

use data/pay_data, clear
gen analysis_workdate=dofc(work_date)
format analysis_workdate %td
merge m:1 cleaned_variation_desc using `info'
assert _m==3
drop _m 

gen leave_code = out_type==1
bys employee_name work_date (work): gen any_work=work[_N]==1
* save file of the person's main div .

** find the main division worked and the typical payrate. use work paycodes.
preserve
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

restore

*** count on each date the number of unique people in division (at all)
preserve
duplicates drop div analysis_workdate employee_name,force 
collapse (sum) main_div_emp_unique = work, by(div analysis_workdate)
rename div main_div
tempfile unique_count
save `unique_count'
restore



*** for each date, compute number of people the person hasd worked at the same time in the same div as.

levelsof employee_name,local(emps)
local h = 0
tempfile res
foreach e of local emps{
    preserve
     gen _tag = employee_name=="`e'"
    qui summ analysis_workdate if  employee_name=="`e'"
    drop if analysis_workdate<r(min)
    keep if work==1
    if _N== 0{
        restore
        continue
    }
    keep div analysis_workdate employee_name _tag
    duplicates drop
    bys div analysis_workdate (_tag analysis_workdate employee_name): replace _tag = _tag[_N]
    * label the first time for each emp they worked with target emp
    bys employee_name _tag (analysis_workdate): gen first_contact = _tag if _n==1
    replace first_contact = 0 if missing(first_contact)
    * last time each emp is observed
    by employee_name (_tag analysis_workdate): gen ever_tagged = _tag[_N]
    bys employee_name (analysis_workdate): gen last_observed = -1 if _n==_N & ever_tagged==1 & employee_name!="`e'"
    replace last_observed =0 if missing(last_observed)
    collapse (sum) first_contact last_observed, by(analysis_workdate)
    sort analysis_workdate
    replace first_contact = first_contact+last_observed[_n-1]
    * minus 1 for self.
    replace first_contact = sum(first_contact)
    replace first_contact = first_contact -1 if first_contact>0
    * pre-lag for merge
    replace analysis_workdate = analysis_workdate+1
    gen employee_name = "`e'"
    gen lag_first_contact = first_contact
    keep employee_name analysis_workdate lag_first_contact
    if `h'==0 save `res'
    else {
    append using `res'
    save `res', replace
    }
    restore
    local h = 1
}

* compute count of employees with temporary variation in rate up
preserve

keep if variation_description=="TEMPORARY VARIATION IN RATE - UP"
collapse (sum) pay_amount hours, by(employee_name div analysis_workdate)
assert hours >=0
gen _counter = hours>0
collapse (sum) var_up_count = _counter, by( div analysis_workdate)
rename div main_div
tempfile  varup
save `varup'
restore

* only leave pay codes, and only among people that did NOT come in at all.
keep if leave_code==1 & any_work==0

* examine the effective rate.
gen test_rate = pay_amount/hours
tab test_rate,m

* collapse to day-code. allow summing across categories
assert hours!=.
preserve
keep if sick_subset==1
tempfile add
save `add'
restore
replace sick_subset=.
append using `add'

collapse (sum) tot_hours = hours, by(employee_name work_date div variation_desc sick_subset)
tab tot_hours,m

* collapse to person-day. zero out negatives within category.
replace tot_hours=0 if tot_hours<0

* distinguish the two types of leave
gen sick_hours =tot_hours if sick_subset==1
replace sick_hours =0 if sick_subset!=1
collapse (sum) tot_hours sick_hours, by(employee_name work_date div)

* note one person has sick time in two divs: EMPLOYEE 319. need to handle this person specially - split 
*hours generally look reasonable.
tab tot_hours,m
assert tot_hours>=0

* collapse sick time by division, also count number of people taking sick.
gen div_count_any_leave = tot_hours>0
gen div_count_any_sick = sick_hours>0
gen div_count_8_leave = tot_hours>=8
gen div_count_8_sick = sick_hours>=8
collapse (sum) div_leavehours = tot_hours div_sickhours=sick_hours div_count_any_* div_count_8_*, by(work_date div)
label variable div_count_8_leave "# in Main Div who Take 8 or More Hours Leave Time"
label variable div_count_any_leave "# in Main Div who Take Any Leave Time"
label variable div_count_8_sick "# in Main Div w 8 or More Hours Sick Time"
label variable div_count_any_sick "# in Main Div w Any Leave Time"
gen analysis_workdate=dofc(work_date)
format analysis_workdate %td
isid div analysis_workdate
drop work_date
rename div main_div
tempfile bydiv
save `bydiv'
reshape wide div_leavehours div_sickhours div_count_any_* div_count_8_*, i(analysis_workdate) j(main_div)
merge 1:m analysis_workdate using `bydiv'
assert _m==3
drop _m
save `bydiv', replace

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


* merge the total sick hours by div.
merge m:1 main_div analysis_workdate using `bydiv'
* unmatched dates are mainly prior to 2015 and in divs 0, 378 and 809:
tab analysis_workdate main_div if _m==2
drop if _m==2
drop _m

* if any of the merged variables are missing, this means they are 0:

foreach var of varlist div_* {
     
     replace `var' = 0 if missing(`var')
}

* before any drops, compute the number of people recorded as working in a division in a day.

bys main_div analysis_workdate (employee_name): egen tot_working_indiv = total(tot_hours>0)
label variable tot_working_indiv "# Working in Division"

merge m:1 main_div analysis_workdate using `varup'
assert _m!=2
replace var_up_count = 0 if _m==1
assert !missing(var_up_count)
drop _m

*** merge on the cumulative contacts
merge m:1 analysis_workdate employee_name using `res'
bys employee_name (analysis_workdate): replace lag_first_contact= 0 if _n==1
bys employee_name (analysis_workdate): replace lag_first_contact= lag_first_contact[_n-1] if missing(lag_first_contact)
assert !missing(lag_first_contact) if analysis_workdate<d(01sep2016) & analysis_workdate>=d(01jan2015) & tot_hours>0
drop if _m==2
drop _m

*** save the number of days worked in last month.
encode employee_name, gen(empid)
xtset empid analysis_workdate 
gen _work=tot_hours>0
forvalues j=1/28{
gen _lagwork`j' = l`j'._work
}
bys empid (analysis_workdate): egen _first_date = min(analysis_workdate)
gen _help = analysis_workdate - _first_date
forvalues v=1/28{
egen _pastwork`v'=rowtotal(_lagwork1-_lagwork`v') if _help==`v'
}
egen _pastwork_else=rowtotal(_lagwork1-_lagwork28) if _help>28
gen _pastwork0 = 0 if _help==0
egen pastwork = rowmin(_pastwork*)
drop _work _lagwork* _help _pastwork*

*** count number of unique divisions worked so far.
bys empid main_div ( analysis_workdate): gen _tag = _n==1
bys empid ( analysis_workdate): gen divs_seen = sum(_tag)

*** merge unique division count
merge m:1 main_div analysis_workdate using `unique_count'
tab main_div if _m==1 & analysis_workdate<d(01sep2016) & analysis_workdate>=d(01jan2015)
replace main_div_emp_unique = 0 if _m==1 & analysis_workdate<d(01sep2016) & analysis_workdate>=d(01jan2015)
assert !missing(main_div_emp_unique) if analysis_workdate<d(01sep2016) & analysis_workdate>=d(01jan2015)
drop if _m==2
drop _m
drop _tag


compress
save data/01_05_working_with_leave, replace
log close

