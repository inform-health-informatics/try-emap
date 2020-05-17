# Steve Harris
# 2020-05-12
# Find all patients with a COVID test

# Load libraries
library(tidyverse)
library(lubridate) # not part of tidyverse
library(RPostgres)
# YMMV but I use data.table much more than tidyverse; Apologies if this confuses
library(data.table)

# Grab user name and password. I store my 'secrets' in an environment file that
# remains out of version control (.Renviron). You can see an example in
# 'example-config-files'. The .Renviron should be at the root of your project or
# in your 'home'.
ctn <- DBI::dbConnect(RPostgres::Postgres(),
                      host = Sys.getenv("UDS_HOST"),
                      port = 5432,
                      user = Sys.getenv("UDS_USER"),
                      password = Sys.getenv("UDS_PWD"),
                      dbname = "uds")


# We have 2 databases
# 'star'  : live (within minutes), complete, with the history of all information but in a 'star' schema so harder to use
# 'ops'   : based on the OMOP schema, and up-to-date within 12-24 hours; patient centric, easier to use

# A series of pre-built views are available on 'star' that make it easier to use
# - bed_moves: patient movements from bed to bed within the bed
# - demographics: direct patient identifiers including vital status and date of death
# - flowsheets: derived from both flowsheet via caboodle and via HL7 where the interfaces have been built (e.g. vital signs) 
# - labs: derived from the HL7 stream from HSL

# We have copies of the queries that create these views stores in snippets/SQL
# You can load these as follows if you wish e.g.
# query <- read_file("snippets/SQL/bed_moves.sql")

# Load physiology
# ===============
warning('FIXME: date time fields for CORP are not always being parsed correctly')

# Picks up 2036N + 293P tests roughly; I think these are Crick results (RESP, CORP)
query <- "SELECT * FROM uds.star.labs WHERE local_code = 'CORP' OR  battery_code = 'NCOV' OR battery_code = 'RCOV' OR local_code = 'CCOV' or local_code = 'ACOV'"
dt <- DBI::dbGetQuery(ctn, query)
setDT(dt)
dt_covid <- data.table::copy(dt)
# View(dt_covid[,.N,by=.(battery_code,result_text)][order(-N)])


# All patients with COVID tests
mrn_covid <- unique(dt[,.(mrn)])

# All labs (so can inner join and pull the remainder)
# This query calls approx 1e7 rows so takes a few minutes
query <- "SELECT * FROM uds.star.labs"
rdt <- DBI::dbGetQuery(ctn, query)
setDT(rdt)

# Inner join: so now we have all tests for these patients
wdt <- rdt[mrn_covid,on="mrn"]
rm(rdt)

wdt[, battery_code := str_to_lower(battery_code)]
wdt[, local_code := str_to_lower(local_code)]
wdt[, result_text := str_to_lower(result_text)]
wdt[, mapped_name := str_to_lower(mapped_name)]

wdt[, covid := NA]

wdt[local_code == 'acov']
wdt[local_code == 'acov',.N,by=result_text]
wdt[local_code == 'acov'  & str_detect(result_text, 'not detected'), covid := FALSE ]
wdt[local_code == 'acov'  & (result_text == 'positive' ), covid := TRUE ]
wdt[local_code == 'acov',.N,by=covid][order(-N)]

wdt[local_code == 'ccov']
wdt[local_code == 'ccov',.N,by=result_text]
wdt[local_code == 'ccov'  & str_detect(result_text, 'not detected'), covid := FALSE ]
wdt[local_code == 'ccov'  & (result_text == 'positive' ), covid := TRUE ]
wdt[local_code == 'ccov',.N,by=covid][order(-N)]

# colindale results?
wdt[battery_code == 'rcov']
# View(wdt[battery_code == 'rcov',.N,by=result_text][order(-N)])
wdt[battery_code == 'rcov'  & str_detect(result_text, 'not detected'), covid := FALSE ]
wdt[battery_code == 'rcov'  & (result_text == 'positive' | result_text == 'detected'), covid := TRUE ]
wdt[battery_code == 'rcov',.N,by=covid][order(-N)]


# full resp screen
# View(wdt[battery_code == 'resp' & local_code == 'corp'])
wdt[, covid := NA]
wdt[battery_code == 'resp' & local_code == 'corp' & result_text == 'not detected', covid := FALSE ]
wdt[battery_code == 'resp' & local_code == 'corp' & result_text == 'positive', covid := TRUE ]

# just covid tests
# View(wdt[battery_code == 'ncov' ])
wdt[battery_code == 'ncov' & result_text == 'not detected', covid := FALSE ]
wdt[battery_code == 'ncov' & result_text == 'positive', covid := TRUE ]

# all tests
wdt[,.N,by=covid]



# View(wdt[mrn=='05036086'])
# tdt <- wdt[mrn=='05036086'][,.(mrn,result_datetime,result_text,covid )]

# tdt <- tdt[is.na(covid)] # use this to artificially drop the covid row for testing
# tdt[, covid_t0 := NULL]
# tdt[!is.na(covid), covid_t0 := min(result_datetime), by=mrn]
# tdt[, covid_t0 := min(covid_t0, na.rm=TRUE), by=mrn]

# forward fill covid status
wdt <- wdt[order(mrn,result_datetime)]
# capture first covid test; 2nd line just updates over the patient
wdt[, covid_t0 := NULL]
wdt[!is.na(covid), covid_t0 := min(result_datetime), by=mrn]
wdt[, covid_t0 := min(covid_t0, na.rm=TRUE), by=mrn]
# mrns <- unique(wdt[,.(mrn)])
# View(wdt[mrns[1:2], on='mrn'][,.(mrn,result_datetime,result_text,covid, covid_t0)])


wdt[, covid_locf := as.numeric(covid)]
wdt[, covid_locf := nafill(covid_locf, type="locf"),by=mrn]
wdt[, covid := covid_locf == 1]
wdt[, covid_locf := NULL]

# save
fwrite(wdt, 'data/secure/labs_covid.csv')

