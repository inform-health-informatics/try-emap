# Load libraries
library(tidyverse)
library(RPostgres)
# YMMV but I use data.table much more than tidyverse; Apologies if this confuses
library(data.table)

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


query <- "SELECT * FROM uds.star.flowsheets"
dt <- DBI::dbGetQuery(ctn, query)
setDT(dt)


dt[order(-flowsheet_datetime)][mrn=='98006480']



# Look for Tower Wards
tower_wards <- grep("UCH T.*", unique(dt$department), value=TRUE)

# Recent admissions to T03 Critical Care
head(dt[order(-admission)][department == "UCH T03 INTENSIVE CARE"])
# Recent admissions to P03 Critical Care (COVID Pods)
head(dt[order(-admission)][department == "UCH P03 CV"])


# Inspect current inpatients
query <- "SELECT * FROM uds.star.bed_moves WHERE department = 'UCH P03 CV'"
dtt03P <- DBI::dbGetQuery(ctn, query)
setDT(dtt03P)
dtt03P[is.na(discharge)][order(department,room,bed),.(mrn,admission,department,room,bed)]

# add in manual check results
dtt03P[mrn=='98006480', hand_validation_note := 'not in P03: in UCH T03 INTENSIVE CARE / BY02-17']
dt[order(-admission)][mrn=='98006480']

dtt03P[mrn=='41408340', hand_validation_note := 'not in P03: in UCH T03 INTENSIVE CARE / SR06-06 which happened 1730hrs 04/05/2020']
dt[order(-admission)][mrn=='41408340']

dtt03P[mrn=='41305935', hand_validation_note := 'not in P03: deceased; BY01-10 now occupied by 21195157']
dt[order(-admission)][mrn=='41305935']


View(dtt03P[is.na(discharge)])


# Inspect current inpatients
dtt03 <- dt[department == "UCH T03 INTENSIVE CARE"]
dtt03[is.na(discharge)][order(department,room,bed),.(department,room,bed,mrn,admission)]

# Count inpatients on T03 on 1 April 12pm
# as an exercise that you can then convert to build a report of occupancy over time for any ward

library(lubridate)
ts <- ymd_hm("2020-04-01 12:00")
tdt <- dtt03[admit < ts & (is.na(discharge) | discharge > ts)]
# confirm there are no duplicate beds
assert_that(uniqueN(tdt[,.(ward,room,bed)]) - tdt[,.N] == 0)

count_ward_occupancy_when <- function(dt, ts) {
  tdt <- dt[admit < (ts) & (is.na(discharge) | discharge > (ts))]
  # assert_that(uniqueN(tdt[,.(ward,room,bed)]) - tdt[,.N] == 0)
  # return a count of unique beds in use at the time point provided
  return(uniqueN(tdt[,.(ward,room,bed)]))
}

ts_begin <- ymd_hm("2020-01-01 12:00")
ts_end <- ymd_hm("2020-04-20 12:00")
tss <- seq(ts_begin, ts_end, by="1 hour")

sapply(tss, count_ward_occupancy_when, dt=dtt03)
dtocc <- data.table(ts=tss, occ=sapply(tss, count_ward_occupancy_when, dt=dtt03))
dtocc

library(ggplot2)
ggplot(dtocc, aes(x=ts, y=occ)) + geom_step()
