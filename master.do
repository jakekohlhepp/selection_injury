**** MASTER DO FILE
*** RUN ALL PROGRAMS TO REPLICATE PAPER.
*** NEED DIRECTORY STRUCTURE+PROGRAMS AND RAW DATA FILES
**** MUST SET WORKING DIRECTORY TO THE FOLDER WHICH CONTAINS MKDATA AND ANALYSIS_INSTRUMENT
**** Create the data
* must have these two raw data files
confirm file mkdata/20170803_payworkers_comp/data/anonymized_data_073117.dta
confirm file mkdata/20190811_weather/data/1834210.csv
confirm file mkdata/20190814_fed_holidays/data/us-federal-holidays-2011-2020.csv
* there should be one handwritten file which identifies which pay codes are work/overtime/leave
confirm file mkdata/out/list_var_desc.csv
cd mkdata/
cd 20190811_weather/
do process_weather

cd ../20190814_fed_holidays/
do process_holidays

* separate pay and worker's comp. perform checks
cd ../
do 01_01_mk_working

* make pay data daily and collapse to person-day
do 01_02_mk_expanded_pay

* make leave by division
do 01_04_mk_leave

**** Do analysis
cd ../analysis_instrument/
* make analysis sample and also run main model.
do 01_01_mk_sample

* run main model.
do 01_02_run_heckprob

* summary stats
do 01_03_descriptives


* fixed effects iv (proxy model)
do 01_05_xtiv
* we fit using MLE, so optimization will change based on random starting point. need to set seed
set seed 4563

* main estimates/tables.
do 01_07_heckprob

* compute more structural estimates from main model
do 01_07b_more_model_estimates

* make heatmap and lower bound estimates of ATE
do 01_07c_heatmap

* compute value of injury.
do 01_08_valueinj

* perform auction simulations
do 01_09_auctions

* perform instrument checks on proxy fe-iv model
do 01_10_instrument_check

* perform robustness analyses.
do 01_11_robustness.do

cd ../
* run this in unix to check output the same.
* diff -r -q /path/to/dir1 /path/to/dir2