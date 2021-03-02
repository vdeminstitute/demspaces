Readme for expgdp_v6.0

Kristian Skrede Gleditsch 
ksg@essex.ac.uk

This version: 9 September 2014

* Description of version 6.0 of the Expanded
	GDP data

The core input data used is PWT 8.0. 
Unlike previous versions of the GDP data this
reports PPP estimates of real GDP rather than 
per capita GDP. 

1) Variable definitions

statenum - Numeric country identifier
statid 	 - Three letter acronym country identifier

For a list of the country id and numeric codes, see 
http://privatewww.essex.ac.uk/~ksg/statelist.html.
Further details are available in case description file
and the paper describing the data

Gleditsch, Kristian S. & Michael D. Ward. 1999. 
	"Interstate System Membership: A Revised List of 
	the Independent States since 1816." 
	International Interactions 25: 393-413


year 	- year of observation
pop 	- population, see also item 3) below 
realgdp	- total real GDP, 2005 
rgdppc	- real GDP per capita, 2005 prices
cgdppc	- GDP per capita, current prices
origin	- origin code for observation


2) Table of origin codes (GDP estimates, see item 3 
	for details on population figures and important 
	exceptions)

0	- From PWT 8.0 (but see expections for population 
	figures in item 3 below)
-1	- From PWT 5.6
-2	- From Maddison Project Database
1	- Imputations for lead/tails based on first/last
	available value, deflated to current value for 
	gdppc using the GDP deflator from the Bureau
	of Economic Analysis 
2	Interpolated value (within series)
3	Estimates based on figures from World Bank Global development indicators,
	using shares to reference countries. 
	(See ksgmdw/scaling.asc for details)


3) Population figures: origins and exceptions

a) All missing population figures in the PWT data have 
been replaced by population figures from the Expanded 
Population Data v.2.0, compiled by Kristian Skrede Gleditsch.
This file is is provided as ksgmdw/countrypopestimates.asc, see 
the associated readme file for details on the origin codes. 
No documention is available as of yet for these data. These estimates 
are generally based on country specific censuses, and the 
particular references for each are available on request. 


b) The PWT populations estimates have been retained
when available, with some exceptions

The PWT project lists population figures
for countries that experience large boundary changes based 
on the current size of the existing state. This means that 
the PWT population figures for the Federal Republic 
of Germany *before* the end of the German Democratic Republic
reflect the population size of the two Germanies combined. 
Likewise, pre-1991 population figures for the Soviet Union 
reflect the size of present day Russia, even though this is 
only about half the size of former Soviet Union. I am
grateful to Ye Wang from the PWT project for explicity 
confirming this to me. 

Since the present size of a state seems inappropriate for
historical comparisons, the current version of the data 
replaces the PWT figures with estimates from the 
Expanded Population Data v.2.0 in the following instances:

A. Population of states prior to merging with other states 
i) Federal Republic of Germany through 1990 (prior to 
	inclusion of former Democratic Republic of Germany)
ii) Democratic Republic of Vietnam through 1975 (prior
	to inclusion of former Republic of (South) Vietnam
iii) Arab Republic of (North) Yemen through 1990 (prior to 
	merger with former People's Republic of (South) Yemen

B. Population of states prior to secession of new states
i) Pakistan through 1970 (prior to secession of Bangladesh)
ii) Soviet Union through 1990 (prior to the secession of 
	multiple former Soviet Republics and the new
	Russian Federation)
iii) Yugoslavia through 1991 (prior to the independence of
	Bosnia, Croatia, Slovenia, and Macedonia)

