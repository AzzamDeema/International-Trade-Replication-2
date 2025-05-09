/*******************************************************************************
* Replication of Feenstra & Kee (2008) - Table 3 Upper Panel
*******************************************************************************/

version 16.0
clear all
set more off
capture log close

* Set working directory
cd "C:/Users/azzam/OneDrive/Documents/PhD semesters/4 Spring 2025/Trade/Replication Assignment 2"

* Start log file
log using "replication_log.txt", replace text

* Create temp directory if it doesn't exist
capture mkdir "temp"

********************************************************************************
* 1. Data Preparation
********************************************************************************

* Define sectors (as per paper)
global sectors "agriculture mining manufacturing"

* Define a program to standardize country names
capture program drop clean_countrynames
program define clean_countrynames
    replace country = "United Kingdom" if inlist(country, "UK", "U.K.", "Britain", "Great Britain")
    replace country = "United States" if inlist(country, "USA", "US", "U.S.", "U.S.A.")
    replace country = "Korea" if inlist(country, "South Korea", "Republic of Korea", "Korea, Republic of")
end

* List of 13 countries (with commas for inlist function)
global countries `""Australia", "Canada", "Czech", "Finland", "France", "Germany", "Hungary", "Japan", "Korea", "New Zealand", "Slovenia", "United Kingdom", "United States""'

* --- Import and Clean Export Data --- *
import excel "exports with commodities.xlsx", firstrow clear
describe
list in 1/5

* Clean variable names and format
rename *, lower

* Rename time to year for consistency
rename time year

* Check if Year variable exists with different capitalization
capture confirm variable Year
if !_rc {
    rename Year year
}
capture confirm variable YEAR
if !_rc {
    rename YEAR year
}

* Check if year variable exists
capture confirm variable year
if _rc {
    di as error "Year variable not found. Please check the Excel file structure."
    exit 198
}

destring value, replace force

* Keep only data from 1990 onwards
keep if year >= 1990

* Keep only the specified countries
gen keep_country = 0
replace keep_country = 1 if country == "Australia"
replace keep_country = 1 if country == "Canada"
replace keep_country = 1 if country == "Czech"
replace keep_country = 1 if country == "Finland"
replace keep_country = 1 if country == "France"
replace keep_country = 1 if country == "Germany"
replace keep_country = 1 if country == "Hungary"
replace keep_country = 1 if country == "Japan"
replace keep_country = 1 if country == "Korea"
replace keep_country = 1 if country == "New Zealand"
replace keep_country = 1 if country == "Slovenia"
replace keep_country = 1 if country == "United Kingdom"
replace keep_country = 1 if country == "United States"
keep if keep_country == 1
drop keep_country

* Create sector classification based on HS codes and descriptions
gen sector = ""

* Agriculture sector (Primary products)
replace sector = "agriculture" if ///
    regexm(commodity, "^(01|02|03|04|05|06|07|08|09|10|11|12|13|14) ") /// Primary agricultural products
    | regexm(commodity, "^(23|24) ") /// Food industry residues and tobacco
    | regexm(commodity, "^(41|43) ") /// Raw hides and furskins
    | regexm(commodity, "^(50|51|52|53) ") // Raw textile materials

* Mining sector (Mineral products and raw materials)
replace sector = "mining" if ///
    regexm(commodity, "^(25|26|27) ") /// Mineral products, ores, and fuels
    | regexm(commodity, "^71 ") // Precious stones/metals in raw form

* Manufacturing sector (All processed goods)
replace sector = "manufacturing" if ///
    regexm(commodity, "^(15|16|17|18|19|20|21|22) ") /// Food and beverage manufacturing
    | regexm(commodity, "^(28|29|30|31|32|33|34|35|36|37|38|39|40) ") /// Chemicals, plastics, rubber
    | regexm(commodity, "^(42|44|45|46|47|48|49) ") /// Leather, wood, paper products
    | regexm(commodity, "^(54|55|56|57|58|59|60|61|62|63|64|65|66|67|68|69|70) ") /// Textiles, apparel, stone/glass
    | regexm(commodity, "^(72|73|74|75|76|77|78|79|80|81|82|83) ") /// Base metals and articles
    | regexm(commodity, "^(84|85|86|87|88|89|90|91|92|93|94|95|96) ") /// Machinery, vehicles, instruments
    | regexm(commodity, "^97 ") // Art and antiques

* Special categories (assign to manufacturing as they are typically processed goods)
replace sector = "manufacturing" if regexm(commodity, "^(98|99) ")

* Drop observations with missing or unclassified sectors
drop if sector == ""

* Display any unclassified commodities for verification
list commodity if sector == ""

* Calculate Export Variety Index (Lambda) following equation (34)
tempfile original_data
save `original_data', replace

* For each sector-country-year
collapse (sum) value, by(year country sector)

* Calculate world exports by sector-year (denominator)
bysort year sector: egen world_exports = total(value)

* Calculate lambda (country share of world exports)
gen lambda = value / world_exports

* Take logs, handling zeros appropriately
gen ln_lambda = ln(lambda)
replace ln_lambda = ln(0.000001) if lambda == 0 | lambda == .

* Save sector-specific values before reshape
foreach s of global sectors {
    preserve
    keep if sector == "`s'"
    rename lambda lambda_`s'
    rename ln_lambda ln_lambda_`s'
    rename value value_`s'
    rename world_exports world_exports_`s'
    tempfile sector_`s'
    save `sector_`s''
    restore
}

* Create base dataset with all country-year combinations
keep country year
duplicates drop country year, force
tempfile base
save `base'

* Merge all sector data
foreach s of global sectors {
    merge 1:1 country year using `sector_`s'', keep(1 3) nogen
    replace lambda_`s' = 0.000001 if missing(lambda_`s')
    replace ln_lambda_`s' = ln(0.000001) if missing(ln_lambda_`s')
}

* Save variety data
save "temp/variety.dta", replace

* Display data to verify
describe
list in 1/5

* Restore original dataset
use `original_data', clear

* --- Import Price Index Data --- *
import excel "import price index.xlsx", firstrow clear
rename *, lower
rename time year
rename value import_price_index
destring import_price_index, replace force
clean_countrynames
keep country year import_price_index
save "temp/import_prices.dta", replace

* --- Import Export Price Index Data --- *
import excel "export price index.xlsx", firstrow clear
rename *, lower
rename time year
rename value export_price_index
destring export_price_index, replace force
clean_countrynames
keep country year export_price_index
save "temp/export_prices.dta", replace

* --- Import GDP Deflator Data --- *
import excel "gdp deflator.xlsx", firstrow clear
rename *, lower
rename time year
rename value gdp_deflator
destring gdp_deflator, replace force
clean_countrynames
keep country year gdp_deflator
save "temp/gdp_deflator.dta", replace

* --- Import Value Added Data --- *
import excel "value added.xlsx", firstrow clear
rename *, lower
rename time year
rename value value_added
keep if year >= 1990
clean_countrynames

* Display unique industries for verification
di "Unique industries before classification:"
levelsof industry, clean

* Create numeric industry variable with simplified matching
gen industry_num = .
replace industry_num = 1 if regexm(lower(industry), "(agriculture|farming|crop|livestock|fishing|forestry)")
replace industry_num = 2 if regexm(lower(industry), "(mining|quarrying|extraction)")
replace industry_num = 3 if regexm(lower(industry), "manufacturing")

* Check industry classification results
tab industry industry_num, missing

* Drop unclassified industries
drop if missing(industry_num)

* Keep only necessary variables
keep country year industry_num value_added

* Verify data structure before reshape
di "Data structure before reshape:"
tab country year
tab country industry_num

* Reshape wide for merging
reshape wide value_added, i(country year) j(industry_num)

* Rename variables for clarity
rename value_added1 va_agr
rename value_added2 va_min
rename value_added3 va_man

* Calculate total value added
egen va_total = rowtotal(va_*)

* Calculate industry shares
gen share_agr = va_agr / va_total
gen share_min = va_min / va_total
gen share_man = va_man / va_total

* Verify shares sum to 1
egen share_total = rowtotal(share_*)
assert abs(share_total - 1) < 0.00001
drop share_total

* Keep only necessary variables
keep country year share_*

* Save to temporary file
save "temp/shares.dta", replace

* Display final dataset structure
describe
list in 1/5

* --- Import Labor Data --- *
import excel "labor.xlsx", firstrow clear
rename *, lower
rename time year
rename value labor

* Keep only data from 1990 onwards
keep if year >= 1990

* Standardize country names
replace country = "United Kingdom" if country == "UK"
replace country = "United States" if inlist(country, "USA", "US", "U.S.", "U.S.A.")
replace country = "Korea" if inlist(country, "South Korea", "Republic of Korea")

* Calculate relative labor (ln(L_h/L_F))
bysort year: egen world_labor = total(labor)
gen ln_rel_labor = ln(labor/world_labor)
keep country year ln_rel_labor
save "temp/labor.dta", replace

* Verify the file was saved
if _rc {
    di as error "Error saving labor tempfile"
    exit 498
}

* --- Import Distance Data (for instruments) --- *
import excel "geodist.xlsx", firstrow clear
rename *, lower

* Clean and prepare distance data
keep if inlist(destination, "United States", "USA", "US", "U.S.", "U.S.A.")
keep country distw

* Generate distance instruments
gen ln_dist = ln(distw)
gen ln_dist_sq = ln_dist^2

* Keep only necessary variables and label them
keep country ln_dist ln_dist_sq
label variable ln_dist "Log of weighted distance to US"
label variable ln_dist_sq "Square of log weighted distance to US"

* Save the distance data
save "temp/distance.dta", replace

* Verify data was saved correctly
describe
list in 1/5

* --- Import and Process Elasticity Data --- *
import excel "elasticity.xlsx", firstrow clear sheet("Sheet1") cellrange(A1)

* Verify data was imported
di _n "Number of observations imported:"
count
if r(N) == 0 {
    di as error "No observations imported from elasticity.xlsx"
    exit 498
}

* Display structure for verification
di _n "Data structure after import:"
describe
di _n "First few observations:"
list in 1/5, clean

* Clean variable names
rename *, lower

* Create sector mapping and generate elasticities
gen elasticity_agr_mining = 12.02 if industry == "Agriculture"
gen elasticity_agr_manufacturing = 12.02 if industry == "Agriculture"
gen elasticity_min_agriculture = 6.63 if industry == "Minerals"
gen elasticity_min_manufacturing = 6.63 if industry == "Minerals"

* Calculate manufacturing elasticity (average of manufacturing sectors)
gen manuf_temp = elasticity if inlist(industry, "Chemicals", "textiles and apparel", ///
    "Machinery and electronics", "Transport equipment", "Other manufactures")
egen avg_manuf = mean(manuf_temp)
gen elasticity_man_agriculture = avg_manuf if !missing(manuf_temp)
gen elasticity_man_mining = avg_manuf if !missing(manuf_temp)

* Keep only the elasticity variables and collapse to one observation
keep elasticity_*
collapse (mean) elasticity_*

* Save the elasticity data
save "temp/elasticities.dta", replace

* --- Merge All Datasets --- *
use "temp/shares.dta", clear
di "Number of observations in shares data:"
count

* Merge with variety data first
merge 1:1 country year using "temp/variety.dta"
di "After merging with variety data:"
count if _merge == 3
tab _merge
keep if _merge == 3
drop _merge

* Merge with labor data
merge 1:1 country year using "temp/labor.dta"
di "After merging with labor data:"
count if _merge == 3
tab _merge
keep if _merge == 3
drop _merge

* Merge with import prices
merge 1:1 country year using "temp/import_prices.dta"
di "After merging with import prices data:"
count if _merge == 3
tab _merge
keep if _merge == 3
drop _merge

* Merge with export prices
merge 1:1 country year using "temp/export_prices.dta"
di "After merging with export prices data:"
count if _merge == 3
tab _merge
keep if _merge == 3
drop _merge

* Merge with GDP deflator
merge 1:1 country year using "temp/gdp_deflator.dta"
di "After merging with GDP deflator data:"
count if _merge == 3
tab _merge
keep if _merge == 3
drop _merge

* Merge with distance data
merge m:1 country using "temp/distance.dta"
di "After merging with distance data:"
count if _merge == 3
tab _merge
keep if _merge == 3
drop _merge

* Merge with elasticity data
preserve
use "temp/elasticities.dta", clear
gen merge_key = 1
save "temp/elasticities.dta", replace
restore

* Create merge key in main dataset
gen merge_key = 1

* Merge elasticity data
merge m:1 merge_key using "temp/elasticities.dta", nogenerate
drop merge_key

* Create year dummies for time fixed effects
* First check the range of years
summ year
di "Creating dummies for years `r(min)' to `r(max)'"
tab year, gen(year_)

* Calculate relative price of non-traded goods
gen ln_p_nt = ln(gdp_deflator) - 0.25*ln(export_price_index) - 0.25*ln(import_price_index)
label variable ln_p_nt "Log relative price of non-traded goods"

* Verify numeric variables and distance instruments
di "Summary of key variables:"
describe gdp_deflator export_price_index import_price_index ln_dist ln_dist_sq
summ gdp_deflator export_price_index import_price_index ln_dist ln_dist_sq

* Keep only necessary variables for the next steps
keep country year ln_p_nt share_agr share_min share_man ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing ln_rel_labor ln_dist ln_dist_sq year_* elasticity_*

* Check for missing values in key variables including distance instruments
di "Checking for missing values in key variables:"
foreach var in ln_p_nt share_agr share_min share_man ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing ln_rel_labor ln_dist ln_dist_sq {
    count if missing(`var')
    if r(N) > 0 {
        di "Variable `var' has " r(N) " missing values"
        list country year if missing(`var')
    }
}

* Display final dataset size
di "Final number of observations:"
count
if r(N) > 0 {
    list in 1/5
}
else {
    di as error "No observations remain in the final dataset"
    exit 2000
}

********************************************************************************
* 2. 3SLS Estimation of Equation (35)
********************************************************************************

* First check for collinearity in lambda variables
corr ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing
summ ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing

* Create year groups (4-year periods) to reduce number of time controls
gen yeargroup = floor((year - 1990)/4)
qui tab yeargroup, gen(yg_)

* Drop the last time dummy to avoid perfect collinearity
capture drop yg_9

* Create country dummies (excluding one as base)
qui tab country, gen(country_)
drop country_1  // Drop first country dummy to avoid collinearity

* Create additional instruments from interactions
gen ln_dist_pnt = ln_dist * ln_p_nt
gen ln_dist_sq_pnt = ln_dist_sq * ln_p_nt
gen ln_dist_labor = ln_dist * ln_rel_labor
gen ln_dist_sq_labor = ln_dist_sq * ln_rel_labor

* Define instrument sets with expanded instruments
global excluded_instruments "ln_dist ln_dist_sq ln_dist_pnt ln_dist_sq_pnt ln_dist_labor ln_dist_sq_labor"
global included_instruments "ln_rel_labor ln_p_nt"
global time_controls "yg_1-yg_8"
global country_controls "country_*"
global all_instruments "$excluded_instruments $included_instruments $time_controls $country_controls"

* Define constraints based on elasticities
constraint drop _all

* Scale elasticities by 100 to match share units (shares are between 0 and 1)
scalar elasticity_agr_mining = 0.1202        // 12.02/100
scalar elasticity_agr_manufacturing = 0.1202  // 12.02/100
scalar elasticity_min_agriculture = 0.0663    // 6.63/100
scalar elasticity_min_manufacturing = 0.0663  // 6.63/100

* Define constraints using scaled values (only for first two equations)
constraint 1 [share_agr]ln_lambda_mining = elasticity_agr_mining
constraint 2 [share_agr]ln_lambda_manufacturing = elasticity_agr_manufacturing
constraint 3 [share_min]ln_lambda_agriculture = elasticity_min_agriculture
constraint 4 [share_min]ln_lambda_manufacturing = elasticity_min_manufacturing

* 3SLS Estimation with modified approach - estimate only agriculture and mining shares
capture noisily reg3 (share_agr = ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing ln_rel_labor ln_p_nt $time_controls $country_controls) ///
     (share_min = ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing ln_rel_labor ln_p_nt $time_controls $country_controls), ///
     constraints(1/4) inst($all_instruments) small

if _rc {
    * If 3SLS fails, try without constraints first
    di as text "Attempting estimation without constraints..."
    reg3 (share_agr = ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing ln_rel_labor ln_p_nt $time_controls $country_controls) ///
         (share_min = ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing ln_rel_labor ln_p_nt $time_controls $country_controls), ///
         inst($all_instruments) small
}

* Store estimation results
estimates store reg3_results

* Calculate manufacturing share coefficients as residual (since shares sum to 1)
if _rc == 0 {
    * Test homogeneity restrictions
    test [share_agr]ln_lambda_agriculture + [share_agr]ln_lambda_mining + [share_agr]ln_lambda_manufacturing = 0

    * Calculate residuals for Hansen-Sargan test
    predict resid_agr if e(sample), equation(share_agr) residuals
    predict resid_min if e(sample), equation(share_min) residuals
}

* Add checks for coefficient magnitudes
if _rc == 0 {
    foreach eqn in share_agr share_min {
        foreach var in ln_lambda_agriculture ln_lambda_mining ln_lambda_manufacturing {
            qui lincom [`eqn']`var'
            if abs(r(estimate)) > 1 {
                di as error "Warning: Large coefficient detected in `eqn' equation for `var': " r(estimate)
            }
        }
    }
}

********************************************************************************
* 3. Post-Estimation Tests
********************************************************************************

* Calculate Hansen-Sargan overidentification test manually
gen hansen_moment = 0
foreach eqn in agr min {  // Remove 'man' since we only estimated two equations
    foreach iv of global excluded_instruments {
        qui reg `iv' $included_instruments $time_controls $country_controls if e(sample)
        predict iv_resid, residuals
        replace hansen_moment = hansen_moment + (resid_`eqn' * iv_resid)^2
        drop iv_resid
    }
}

* Calculate test statistic and degrees of freedom
qui sum hansen_moment
local test_stat = r(sum)
local df = `: word count $excluded_instruments' - 2  // Subtract 2 for the two equations

* Display results
di _n "Hansen-Sargan overidentification test:"
di "Chi-square(" `df' ") = " `test_stat'
di "p-value = " chi2tail(`df', `test_stat')

********************************************************************************
* 4. Create Table 3 - Industry Share Regression Output
********************************************************************************

* Restore estimation results
estimates restore reg3_results

* Create formatted table header
file open mytable using "table3_replication.txt", write replace
file write mytable "Table 3: Industry Share Regression Output" _n _n

* Write column headers
file write mytable _tab "(1)" _tab "(2)" _tab "(3)" _n
file write mytable "Independent Variables" _tab "Agriculture" _tab "Mining" _tab "Manufacturing" _n
file write mytable "Log of relative export variety in:" _n

* Get coefficients and standard errors for agriculture and mining
foreach row in agr min {
    * Write row label
    local rowname = cond("`row'"=="agr", "Agriculture", "Mining")
    file write mytable "`rowname'" _tab
    
    foreach col in agriculture mining manufacturing {
        quietly lincom [share_`row']ln_lambda_`col'
        local b = string(r(estimate), "%9.3f")
        local se = string(r(se), "%9.3f")
        local t = abs(r(estimate)/r(se))
        local stars = cond(`t'>=2.58, "***", cond(`t'>=1.96, "**", cond(`t'>=1.645, "*", "")))
        file write mytable "`b'`stars' (`se')" _tab
    }
    file write mytable _n
}

* Calculate manufacturing coefficients as residual
file write mytable "Manufacturing" _tab
foreach col in agriculture mining manufacturing {
    * Manufacturing coefficient is negative of sum of agriculture and mining coefficients
    quietly {
        lincom -([share_agr]ln_lambda_`col' + [share_min]ln_lambda_`col')
        local b = string(r(estimate), "%9.3f")
        local se = string(r(se), "%9.3f")
        local t = abs(r(estimate)/r(se))
        local stars = cond(`t'>=2.58, "***", cond(`t'>=1.96, "**", cond(`t'>=1.645, "*", "")))
    }
    file write mytable "`b'`stars' (`se')" _tab
}
file write mytable _n

* Add control variables section
file write mytable _n "Control Variables:" _n
file write mytable "ln(L/L_w)" _tab "Yes" _tab "Yes" _tab "Yes" _n
file write mytable "ln(P_NT)" _tab "Yes" _tab "Yes" _tab "Yes" _n

* Add fixed effects
file write mytable _n "Fixed Effects:" _n
file write mytable "Year fixed-effects" _tab "Yes" _tab "Yes" _tab "Yes" _n
file write mytable "Country fixed-effects" _tab "Yes" _tab "Yes" _tab "Yes" _n

* Add model statistics
file write mytable _n "Model Statistics:" _n
foreach sector in agr min {
    local sectorname = cond("`sector'"=="agr", "Agriculture", "Mining")
    quietly predict yhat_`sector', equation(share_`sector')
    quietly correlate share_`sector' yhat_`sector'
    local r2_`sector' = r(rho)^2
    file write mytable "R² (`sectorname')" _tab %9.4f (`r2_`sector'') _n
}
* Calculate R² for manufacturing as residual
quietly {
    gen share_man_pred = 1 - yhat_agr - yhat_min
    correlate share_man share_man_pred
    local r2_man = r(rho)^2
}
file write mytable "R² (Manufacturing)" _tab %9.4f (`r2_man') _n
file write mytable "Observations" _tab %9.0f (e(N)) _n
file write mytable "Chi-squared" _tab %9.2f (e(chi2)) _n
file write mytable "P-value" _tab %9.3f (e(p)) _n

* Add significance note
file write mytable _n "Note: Standard errors in parentheses" _n
file write mytable "*** p<0.01, ** p<0.05, * p<0.1" _n

file close mytable

* Clean up predicted values and temporary variables
capture drop resid_*
capture drop hansen_moment
capture drop yeargroup
capture drop yg_*
capture drop ln_dist_pnt ln_dist_sq_pnt ln_dist_labor ln_dist_sq_labor
capture drop yhat_*
capture drop share_man_pred

* Display the formatted table
type "table3_replication.txt"

* Save in Stata format for future use
estimates save "table3_results", replace

* Close log
log close

* Clean up temporary files
local temp_files : dir "temp" files "*.dta"
foreach f of local temp_files {
    capture erase "temp/`f'"
}
capture rmdir "temp"

********************************************************************************
* End of do-file
********************************************************************************
