***************************************
* 0. Install required package if not already installed
***************************************
ssc install estout, replace

***************************************
* 1. Read raw data and prepare variables
***************************************
import delimited "/Users/zhaorunping/Desktop/Research_Onging/2502_Haas_Matteo/log/ratewatch_AllBanks_uniformpricing_newest_multi_branches.csv", clear

* Keep only the required variables (including county and primarycompany)
keep accountnumber productdescription datesurveyed inst_nm rate apy zip msa cbsa county primarycompany

* Generate the 'month' variable (extract pattern "YYYY-MM")
gen month = substr(datesurveyed, 1, 7)

* Rename original zip variable to zip_9digit, and create zip_5digit and zip_3digit
rename zip zip_9digit
gen zip_5digit = substr(zip_9digit, 1, 5)
gen zip_3digit = substr(zip_9digit, 1, 3)

* Drop data from the year 2014
drop if substr(datesurveyed, 1, 4) == "2014"

***************************************
* 2. Filter data for INTCK2.5K and for March 2019
***************************************
* Note: Adjust the month pattern as needed (assuming format is "2019/3/")
keep if productdescription == "INTCK2.5K" & month == "2019-03"
* Remove "Wells Fargo Bank, National Association"
* drop if inst_nm == "Wells Fargo Bank, National Association"

count
if r(N) < 10 {
    display "Not enough observations for regression."
    exit
}

***************************************
* 3. Save the filtered regression dataset (Excluding Wells Fargo)
***************************************
export delimited using "/Users/zhaorunping/Desktop/Research_Onging/2502_Haas_Matteo/Mixed-Banking/Figures similar to Granja and Paixo Uniform Pricing Paper/data/intermediate/INTCK2.5K_2019-03_data_multi-branches.csv", replace

***************************************
* 4. Process categorical variables
***************************************
* Convert inst_nm from a string to a numeric variable using egen group,
* while retaining original text as value labels
egen inst_nm_id = group(inst_nm), label
drop inst_nm
rename inst_nm_id inst_nm

* Encode other categorical variables if they are not already numeric
foreach var in zip_9digit zip_5digit zip_3digit msa cbsa county primarycompany {
    capture confirm numeric variable `var'
    if _rc {
        encode `var', gen(`var'_num)
        drop `var'
        rename `var'_num `var'
    }
}

***************************************
* 5. Run regressions (Excluding Wells Fargo)
***************************************
* Regression 1: Using inst_nm as fixed effects
regress rate i.inst_nm
estimates store model_inst

* Regression 2: Using zip_3digit as fixed effects
regress rate i.zip_3digit
estimates store model_zip3

***************************************
* 6. Automatically generate coeflabels mappings (including reference group)
***************************************
* Generate mapping for inst_nm
local mapping_inst ""
levelsof inst_nm, local(inst_levels)
foreach lev of local inst_levels {
    local lbl : label (inst_nm) `lev'
    local mapping_inst `mapping_inst' "`lev'.inst_nm" "`lbl'"
}

* Generate mapping for zip_3digit
local mapping_zip3 ""
levelsof zip_3digit, local(zip3_levels)
foreach lev of local zip3_levels {
    local lbl : label (zip_3digit) `lev'
    local mapping_zip3 `mapping_zip3' "`lev'.zip_3digit" "`lbl'"
}

***************************************
* 7. Output complete regression results side by side using esttab
***************************************
esttab model_inst model_zip3 using "/Users/zhaorunping/Desktop/Research_Onging/2502_Haas_Matteo/Mixed-Banking/Figures similar to Granja and Paixo Uniform Pricing Paper/data/intermediate/INTCK2.5K_2019-03_regression_multi-branches_results.txt", replace ///
    title("Multi-branches Regression Results: Fixed Effects Comparison") ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2 r2_a, fmt(0 3 3) labels("Observations" "R-squared" "Adj. R-squared")) ///
    baselevels coeflabels(`mapping_inst' `mapping_zip3')
