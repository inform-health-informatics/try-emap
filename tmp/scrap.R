# Steve Harris
# 2020-05-12
# Find all patients with a COVID test

# Load libraries
library(tidyverse)
library(lubridate) # not part of tidyverse
library(RPostgres)
# YMMV but I use data.table much more than tidyverse; Apologies if this confuses
library(data.table)
library(stringr)

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
query <- "SELECT * FROM uds.star.labs WHERE local_code = 'CORP' OR  battery_code = 'NCOV'"
dt <- DBI::dbGetQuery(ctn, query)
setDT(dt)
dt_covid <- data.table::copy(dt)

View(dt_covid[,.N,by=.(battery_code,result_text)][order(-N)])



dt_covid[,.N,by=covid]

# All patients with COVID tests
mrn_covid <- unique(dt[,.(mrn)])

# All labs (so can inner join and pull the remainder)
# This query calls approx 1e7 rows so takes a few minutes
query <- "SELECT * FROM uds.star.labs"
rdt <- DBI::dbGetQuery(ctn, query)
setDT(rdt)

# Inner join: so now we have all tests for these patients
wdt <- rdt[mrn_covid,on="mrn"]

wdt[, battery_code := str_to_lower(battery_code)]
wdt[, local_code := str_to_lower(battery_code)]
wdt[, result_text := str_to_lower(result_text)]
wdt[, covid := NA]
wdt[battery_code == 'resp' & result_text == 'not detected', covid := FALSE ]
wdt[battery_code == 'ncov' & result_text == 'not detected', covid := FALSE ]
wdt[battery_code == 'resp' & result_text == 'positive', covid := TRUE ]
wdt[battery_code == 'ncov' & result_text == 'positive', covid := TRUE ]

# save for ongoing work

fwri(wdt, 'data/secure/labs_covid.R')


# Inspect
dt[,.N,by=mapped_name][order(-N)]
# NOTE: many caboodle rows do not have their mapped names

dt[, short_name := NULL]
dt[mapped_name == "Oxygen saturation in Blood", short_name := "spo2"]
dt[mapped_name == "Respiratory rate", short_name := "rr"]
dt[mapped_name == "Heart rate", short_name := "hr"]
dt[mapped_name == "Body temperature", short_name := "tc"]

dt_phys <- dt[!is.na(short_name)]

# Back to the bed moves and outcomes data
# Now define the first critical care admission
cc_wards <- c("UCH T03 INTENSIVE CARE", "UCH P03 CV", "UCH T07 HDRU")
dtcc_1 <- dtcc[department %in% cc_wards & admission == dpt_admit_dt][
  ,.(mrn,department,department_i,dpt_admit_dt,
     age,sex,death_date)]

# Rolling join
dtcc_1[, join_time := dpt_admit_dt]
setkey(dtcc_1, mrn, join_time)
dt_phys[, join_time := flowsheet_datetime]
setkey(dt_phys, mrn, join_time)

# View(dtcc_1[dt_phys, roll=TRUE])
dt_phys <- dtcc_1[dt_phys, roll=TRUE][,.(mrn,department,department_i,dpt_admit_dt,
                                         age,sex,death_date,
                                         csn,flowsheet_datetime,short_name,result=result_as_real)]
dt_phys[, result_delta := (flowsheet_datetime - dpt_admit_dt)/dhours(1)]
dt_phys24 <- dt_phys[result_delta < 24]
dt_phys24 <- dcast.data.table(dt_phys24,
                              mrn + department + department_i + age + sex + death_date + dpt_admit_dt ~ short_name, 
                              fun=list(min,max), value.var='result' )

# Join back to beds & demographics
dt_phys24

# Inspect
ggplot(dt_phys24, aes(x=result_min_spo2, y=result_max_rr, colour=!is.na(death_date))) + geom_point() + geom_smooth()
ggplot(dt_phys24, aes(x=dpt_admit_dt, y=result_max_rr)) + geom_point() + geom_smooth()
ggplot(dt_phys24, aes(x=dpt_admit_dt, y=result_max_hr)) + geom_point() + geom_smooth()
ggplot(dt_phys24, aes(x=dpt_admit_dt, y=result_max_tc)) + geom_point() + geom_smooth()
ggplot(dt_phys24, aes(x=dpt_admit_dt, y=result_min_spo2)) + geom_point() + geom_smooth()
ggplot(dt_phys24, aes(x=dpt_admit_dt, y=age)) + geom_point() + geom_smooth()
ggplot(dt_phys24, aes(x=dpt_admit_dt, y=age, colour=!is.na(death_date))) + geom_point() + geom_smooth()

# TODO report los by source of admission
dtcc[department_i == 1 & department == "UCH T03 INTENSIVE CARE" & admission > ymd_hm("2020-03-13 00:00")][order(admission,mrn)][,.(admission,mrn,discharge,department,bed,age,sex)]

