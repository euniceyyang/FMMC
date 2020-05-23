/// ----------------------------------------------------------------------------
/// Mock analyses
/// ----------------------------------------------------------------------------
log using 22May2020.txt, t
cd "C:\Users\Eunice\Dropbox\work\data_work\MEPS_programming"
*use mock, clear
use newmock, clear
/// newmock.dta contains MEPS full years, outcome variables (e.g. anyIP, anyOP, etc.) 
/// defined using MEPS files, and predicted values of the key variable (xhat)
/// and of the residual (resid) from the 1st stage regression to be used in the
/// second stage regressions of 2SLS and 2SRI. 


keep if age >= 18
keep if age < 66
gen byte anyminor = (numminor > 0)
save mock_adult, replace

egen stcty = concat(FIPS_st FIPS_cty) 
egen personid = concat(DUPERSID PANEL) 
destring FIPS_st, replace
destring stcty, replace
destring personid, replace
global indiv i.SEX i.RACETH i.educ i.married i.disab_any i.has_prr i.POVCAT i.anyminor c.numMCD c.age

/// ----------------------------------------------------------------------------
/// pooled LPM (OLS) 
/// ----------------------------------------------------------------------------
*eststo: areg anyOP3 FMMC $indiv i.YEAR, absorb(FIPS_st)
*eststo: areg anyOP3 FMMC $indiv i.YEAR, absorb(FIPS_st) vce(cl FIPS_st)
*eststo: areg anyIP3 FMMC $indiv i.YEAR, absorb(FIPS_st) cluster(FIPS_st)
/* vce(cl FIPS_st) and cluster(FIPS_st) are the same */
eststo: areg anyIP3 FMMC i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cluster stcty)	
eststo: areg anyIP3 c.FMMC##i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cluster stcty)	

/* not sure if it makes sense to cluster in smaller (and nested) units
when with 'absorb' the default is to cluster at the absorbed variable level.
does it even run? 
Ans: yes, it runs. 
Also, 'absorb' does NOT seem to automatically cluster the VCE by default; 
which is probably how the a(state) vce(cl cty) was executable as well. 
Also, the resulting standard errors are not necessarily small or large, 
maybe b/c this is a mock dataset. */

eststo: areg anyIP3 FMMC $indiv i.YEAR, absorb(stcty)  vce(cluster FIPS_st)
eststo: areg anyIP3 FMMC $indiv i.YEAR, absorb(stcty)

/* if I am to decide how to 'absorb' and cluster based on theory, 
I'd say i.state (instead of i.county) & cluster(county) */
eststo clear

/// ----------------------------------------------------------------------------
/// pooled logit
/// ----------------------------------------------------------------------------
logit anyIP3 FMMC##i.rural $indiv i.YEAR i.FIPS_st, vce(cl stcty)

/// wait, do I need to do a fixed effect model? does it even make a sense?
*xtset stcty YEAR
*xtreg anyIP3 FMMC $indiv i.YEAR i.FIPS_st, fe vce(cluster FIPS_st)
/* No, it does not run. 
STATA can tell that there are multiple obs within each "panel," the county.
*/

/// ----------------------------------------------------------------------------
/// pooled LPM + IV ==> 2SLS
/// ----------------------------------------------------------------------------

*ivregress 2sls anyIP3 (FMMC=NUMMA) $indiv i.YEAR i.FIPS_st, first vce(cl stcty)
/* <--- WAIT! My 1st stage is on county level, not on individual level?
<--- I went back to the original dataset, trimmed it down to countyxyear level, 
ran the 1st stage, recorded the predicted FMMC (xhat) and the predicted residual (resid),
and saved it, so I can jump to the 2nd stage here. 
*/
areg anyIP3 xhat $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
bootstrap, reps(10) seed(2020) : areg anyIP3 xhat $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
*bootstrap, reps(10) seed(2020) cluster(stcty): areg anyIP3 xhat $indiv i.YEAR, absorb(FIPS_st)
/* the two are equivalent. */


/// ----------------------------------------------------------------------------
/// pooled logit + IV ==> 2SRI 
/// ----------------------------------------------------------------------------

*areg FMMC NUMMA i.YEAR, absorb(FIPS_st) vce(cl stcty)
*predict resid, residuals
*logit anyIP3 FMMC NUMMA resid $indiv i.YEAR i.FIPS_st, vce(robust)
logit anyIP3 FMMC##i.rural NUMMA resid $indiv i.YEAR i.FIPS_st, vce(cl stcty)

/* not sure if robust vce means anything, since we don't believe in the std. error
produced by this logit estimation anyway. 
however, I decided to followed Terza's instructions--
with logit being non-linear, eh, does the standard error get roped into the estimation of coeffs? 
--> the two logit estimations above produce the same coeffs, but different "robust standard errors." 
so i guess the answer is no.
*/

/// bootstrap the coeffs 
/// b/c we don't believe in that "robust standard errors."

/* ditch this first program b/c we have ~~1st stage~~ premade now.
program define std_2sri, eclass
	args yvar xvar zvar
	tempvar omegahat b
	capture drop omegahat
	areg `xvar' `zvar' $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
	predict `omegahat', residuals
	logit `yvar' `xvar' `zvar' `omegahat' $indiv i.YEAR i.FIPS_st, vce(robust) 
	matrix `b' = e(b)
	ereturn post `b'
end
*/

/* 2SRI program that runs the second stage regressions */
program drop twosri
program define twosri, eclass
	args yvar
	tempvar b
	logit `yvar' c.FMMC##i.rural NUMMA resid $indiv i.YEAR i.FIPS_st, vce(cl stcty) 
	matrix `b' = e(b)
	ereturn post `b'
end

/* test run of the program */
twosri anyIP3
bootstrap _b, seed(10110) reps(10): twosri anyIP3


/* what's the point of clustered vce, if we are bootstrapping any way?
program define twosri_0, eclass
	args yvar
	tempvar b
	logit `yvar' FMMC NUMMA resid $indiv i.YEAR i.FIPS_st
	matrix `b' = e(b)
	ereturn post `b'
end
bootstrap _b, seed(10110) reps(10): twosri_0 anyIP3
 ---> The results are the same, indeed!*/


/* wait, if only the coefficients, do I need a special program? */
bootstrap _b, reps(10) seed(10110): logit anyIP3 c.FMMC##i.rural NUMMA resid $indiv i.YEAR i.FIPS_st, vce(cl stcty)
bootstrap _b, reps(10) seed(10110) noisily: logit anyIP3 c.FMMC##i.rural NUMMA resid $indiv i.YEAR i.FIPS_st, vce(cl stcty)

///--------------------------------------------------------------sent to Marisa

/// average marginal effects with 2SRI for FMMC

/*
program define ame, rclass
	args yvar xvar
	tempvar pred_0 pred_1 tempx	
	capture drop me_on_`yvar'
	
	gen `tempx' = `xvar'
	*display "before switch"
	*su `tempx'
	
	logit `yvar' `tempx' NUMMA resid $indiv i.YEAR i.FIPS_st
	predict `pred_0'
	replace `tempx' = `xvar' + 1 

	display "after switch"
	su `tempx'
	
	predict `pred_1'
	gen me_on_`yvar' = `pred_1' - `pred_0'
	su me_on_`yvar'
	return scalar ame_on_`yvar'=r(mean)
end

log using noisy_boot.txt, replace text

bootstrap r(ame_on_anyIP3), noisily reps(30) seed(8282): ame anyIP3 FMMC

*/
program drop ame_2sri
program define ame_2sri, rclass
	args yvar
	tempvar pred_0 pred_1 tempx counter
	capture drop me_on_`yvar'
	replace counter = counter +1
	display "this repetition is" "    " counter
	
	gen `tempx' = FMMC
	su `tempx'
	logit `yvar' `tempx' NUMMA resid $indiv i.YEAR i.FIPS_st
	predict `pred_0'
	replace `tempx' = FMMC + 1 
	su `tempx'
	predict `pred_1'
	gen me_on_`yvar' = `pred_1' - `pred_0'
	su me_on_`yvar'
	return scalar ame_on_`yvar'=r(mean)
end

gen counter = 0
ame_2sri anyIP3
bootstrap r(ame_on_anyIP3), reps(10) seed(10110) noisily: ame_2sri anyIP3
bootstrap r(ame_on_anyIP3), reps(100) cluster(FIPS_st) seed(10011) noisily: ame_2sri anyIP3


/// -------------- All the outcomes
/// 1. "Continuous" variables that start from zero to larger numbers
local conti_zero IPnights1 IPnights3 Q_rating 

eststo: areg IPnights3 FMMC i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
eststo: areg IPnights3 c.FMMC##i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
eststo: areg IPnights3 xhat i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
bootstrap, reps(10) seed(2020) : areg IPnights3 xhat i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
esttab
eststo clear

/// 1. "Continuous" variables that start from one, conditional on having any visits
/// (or are they two-parts?)
local conti_one numOP1 numOP3
eststo: areg numOP3 FMMC i.rural $indiv i.YEAR if numOP3 > 0, absorb(FIPS_st) vce(cl stcty)
eststo: areg numOP3 c.FMMC##i.rural $indiv i.YEAR if numOP3 > 0, absorb(FIPS_st) vce(cl stcty) 
eststo: areg numOP3 xhat i.rural $indiv i.YEAR if numOP3 >0, absorb(FIPS_st) vce(cl stcty)
bootstrap, reps(10) seed(2020) : areg IPnights3 xhat i.rural $indiv i.YEAR if numOP3 >0, absorb(FIPS_st) vce(cl stcty)
esttab 
eststo clear

/// 1. binary variables for which the whole sample has values  
local binary_all anyIP1 anyIP3 anyOP1 anyIP3 anyED1 anyED3 Q_flu Q_USC

/// 1. binary variables for which limited observations have values
local binary_lim ACSC_CCC1sel ACSC_CCC1234sel Q_specialist Q_listen Q_explain Q_respect Q_enough Q_pap Q_breast Q_mammo Q_brstmamm Q_colosig Q_a1c Q_eye 
su Q_specialist
areg Q_specialist c.FMMC##i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cluster stcty)	
logit Q_specialist c.FMMC##i.rural $indiv i.YEAR i.FIPS_st, vce(cl stcty)
areg Q_specialist xhat i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
bootstrap, reps(10) seed(2714) : areg Q_specialist xhat i.rural $indiv i.YEAR, absorb(FIPS_st) vce(cl stcty)
logit Q_specialist c.FMMC##i.rural NUMMA resid $indiv i.YEAR i.FIPS_st, vce(cl stcty)
twosri Q_specialist
bootstrap _b, seed(10110) reps(10): twosri Q_specialist
ame_2sri Q_specialist
bootstrap r(ame_on_anyIP3), reps(10) seed(10011): ame_2sri anyOP3
bootstrap r(ame_on_anyOP3), reps(100) cluster(FIPS_st) seed(10011) noisily: ame_2sri anyOP3



/// ----------------------------- what if we restrict the study sample to individuals with 2 observation points?
duplicates tag DUPERSID PANEL, generate(dup)
keep if dup ==1
save mockpanel, replace 

xtset personid YEAR
bysort personid: egen mstcty= mean(stcty)
count if stcty ~= mstcty

xtreg anyIP3 FMMC, fe vce(cluster stcty)
xtreg anyIP3 c.FMMC##i.rural i.YEAR i.FIPS_st, fe vce(cluster stcty)
xtreg anyIP3 c.FMMC##i.rural $indiv i.YEAR i.FIPS_st, fe vce(cluster stcty)
/* note that i.FIPS_st will be all washed out*/


/// ------------------------------ What if we restrict the study sample to include only 1 observation from each individuals? 
/// ------------------------------ Try keep if numMCD==12
/// ------------------------------ state- level analyses

areg anyIP3 xhat_st
