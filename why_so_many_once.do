log using number_check.txt, replace text

/// How come so many people appear only once?
cd "C:\Users\Eunice\Dropbox\work\data_work\MEPS_programming"

local yy = 17
local full = "201" /* full year file */ 

use "C:\MEPS\DATA\H`full'.dta", clear

/// Number of Medicaid months
egen numMCD = anycount(MCDJA`yy'X MCDFE`yy'X MCDMA`yy'X MCDAP`yy'X MCDMY`yy'X MCDJU`yy'X MCDJL`yy'X MCDAU`yy'X MCDSE`yy'X MCDOC`yy'X MCDNO`yy'X MCDDE`yy'X), value(1)
gen byte YEAR = `yy'
keep DUPERSID AGE`yy'X MCD*`yy'X MCR*`yy'X numMCD PANEL KEYNESS INSCOP* SEX YEAR MCREV`yy'
rename AGE`yy'X age
rename MCREV`yy' MCRever
save MEPS`yy', replace

local yy = 16
local full = "192" /* full year file */ 

use "C:\MEPS\DATA\H`full'.dta", clear

egen numMCD = anycount(MCDJA`yy'X MCDFE`yy'X MCDMA`yy'X MCDAP`yy'X MCDMY`yy'X MCDJU`yy'X MCDJL`yy'X MCDAU`yy'X MCDSE`yy'X MCDOC`yy'X MCDNO`yy'X MCDDE`yy'X), value(1)
gen byte YEAR = `yy'
keep DUPERSID AGE`yy'X MCD*`yy'X MCR*`yy'X numMCD PANEL KEYNESS INSCOP* SEX YEAR MCREV`yy'
rename AGE`yy'X age
rename MCREV`yy' MCRever
save MEPS`yy', replace

local yy = 15
local full = "181" /* full year file */ 

use "C:\MEPS\DATA\H`full'.dta", clear

egen numMCD = anycount(MCDJA`yy'X MCDFE`yy'X MCDMA`yy'X MCDAP`yy'X MCDMY`yy'X MCDJU`yy'X MCDJL`yy'X MCDAU`yy'X MCDSE`yy'X MCDOC`yy'X MCDNO`yy'X MCDDE`yy'X), value(1)
gen byte YEAR = `yy'
keep DUPERSID AGE`yy'X MCD*`yy'X MCR*`yy'X numMCD PANEL KEYNESS INSCOP* SEX YEAR MCREV`yy'
rename AGE`yy'X age
rename MCREV`yy' MCRever
save MEPS`yy', replace

local yy = 14
local full = "171" /* full year file */ 

use "C:\MEPS\DATA\H`full'.dta", clear

egen numMCD = anycount(MCDJA`yy'X MCDFE`yy'X MCDMA`yy'X MCDAP`yy'X MCDMY`yy'X MCDJU`yy'X MCDJL`yy'X MCDAU`yy'X MCDSE`yy'X MCDOC`yy'X MCDNO`yy'X MCDDE`yy'X), value(1)
gen byte YEAR = `yy'
keep DUPERSID AGE`yy'X MCD*`yy'X MCR*`yy'X numMCD PANEL KEYNESS INSCOP* SEX YEAR MCREV`yy'
rename AGE`yy'X age
rename MCREV`yy' MCRever
save MEPS`yy', replace

append using MEPS15
append using MEPS16
append using MEPS17

/// How many people appear once vs. twice?
duplicates report DUPERSID PANEL
duplicates tag DUPERSID PANEL, generate(twice)

tab PANEL twice

/// drop individuals who didn't have chance to appear twice
drop if PANEL == 22
drop if PANEL == 18
tab PANEL twice

/// How many do I lose when I drop "negative one" year-olds?
count if age < 0
tab twice if age < 0

/// see if I can learn age information from the other year
sort DUPERSID YEAR
egen secyr=seq(), by(DUPERSID PANEL)
bysort DUPERSID PANEL: egen smaller_age = min(age)
bysort DUPERSID PANEL: egen larger_age = max(age)

gen byte agefix=age if age>=0
replace agefix= larger_age -1 if agefix ==. & secyr ==1
replace agefix= larger_age +1 if agefix ==. & secyr ==2

gen neg_age = (smaller_age == larger_age & larger_age ==-1)
tab neg_age twice
replace age = agefix if neg_age != 1
drop smaller_age larger_age


/// How many do I lose when I drop the elderly?
gen byte elderly = (age > 65) 
tab elderly twice

/// exactly how many move from 65 to 66 over the two appearances? 
count if twice == 1 &  secyr == 1 & age ==65
count if twice == 1 &  secyr == 2 & age ==66
/* 
I don't know why, but there is this one person (DUPERSID =="17951101") 
whose age is recorded as 66 in both years.
I found out by
gen byte mark = (twice ==1 & secyr ==1 & age ==65)
bysort DUPERSID: egen marked = max(mark)
count if secyr ==2 & marked ==1
count if twice ==1 & secyr ==2 & age ==66 & marked !=1
br if twice ==1 & secyr ==2 & age ==66 & marked !=1
*/

/// How many do I lose when I drop any person who had Medicare month?
gen anyMCR = (MCRever ==1)
tab anyMCR twice

/// exactly how many get Medicare in one year but not in the other?
egen byte anyMCR2= max(anyMCR), by(DUPERSID)
tab anyMCR anyMCR2
tab anyMCR2 twice

/// How many do I lose when I limit the sample to ever-Medicaid?
gen anyMCD = (numMCD > 0)
tab anyMCD twice

egen byte anyMCD2 = max(anyMCD), by(DUPERSID)
tab anyMCD anyMCD2
tab anyMCD2 twice

/// In sum, how many person-year observations are in my study sample
/// when I limit the sample to non-negative age, non-elderly, never-Medicare, and 
/// at least one month of Medicaid coverage?

tab PANEL twice if neg_age !=1 & elderly !=1 & anyMCR != 1
tab PANEL twice if neg_age !=1 & elderly !=1 & anyMCR != 1 & anyMCD ==1
duplicates report DUPERSID PANEL if neg_age !=1 & elderly !=1 & anyMCR != 1
duplicates report DUPERSID PANEL if neg_age !=1 & elderly !=1 & anyMCR != 1 & anyMCD ==1
duplicates tag DUPERSID PANEL if neg_age !=1 & elderly !=1 & anyMCR != 1 & anyMCD ==1, generate(twice2)

tab twice2, missing
tab PANEL twice2
