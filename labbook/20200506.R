# Steve Harris
# 2020-05-06
# Let's calculate the ICNARC acute physiology score for patients admitted to the ICU, and then plot this against their outcome

# Load libraries
library(tidyverse)
library(lubridate)
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


# Part 1: create a table of ICU admissions
# Part 2: define the outcome
# Part 3: define the admitting physiology

# Part 1
# ======
query <- "SELECT * FROM uds.star.bed_moves"
dt <- DBI::dbGetQuery(ctn, query)
setDT(dt)


# View(unique(dt[,.(department)]))
# First find all MRNs that have been to a critical care area
mrncc <- unique(dt[department == "UCH T03 INTENSIVE CARE" |
            department == "UCH P03 CV" |
             department == "UCH T07 HDRU"][,.(mrn)])
# then select all bedmoves related to those patients
dtcc <- dt[mrncc, on="mrn"][order(mrn,admission)]
head(dtcc)

# Now collapse by department to appropriately define ICU admission
# dtcc <- dtcc[,.(mrn,admission,discharge,department)]

# define updates where the location changes; then keep those and the NAs
# checks to see if the department has changed compared to the prev entry
dtcc[order(mrn,admission), 
     department_jump := shift(.SD, type="lag"), 
     by=mrn, 
     .SDcols="department"][
     , department_jump :=  department_jump != department][]

# now need logic to check whether the gap between times is too big (i.e. a re-admission or not)
# Specify gap between times for a new location to be considered a 're-admission'

dtcc[order(mrn,admission),  
     time_jump := shift(.SD, type="lag"),  
     by=mrn,  .SDcols="discharge"][,
           time_jump := (admission-time_jump)]
# View(dtcc[unique(dtcc[time_jump>0][,.(mrn)]), on="mrn"])

# Now to collapse over ward episodes, just keep where either ward_jump | time_jump is true
# keep all time_jumps > a window
time_jump_window  <- dhours(4)
temp <- dtcc[department_jump | abs(time_jump) > time_jump_window | is.na(department_jump) | is.na(time_jump)]
# now number the department moves
temp[order(mrn,admission), department_i := seq_len(.N), by=.(mrn)][]

# finally join this back on to dtcc
dtcc <- temp[dtcc, on=.NATURAL]
# then roll the department variable forwards
dtcc[order(mrn,admission), department_i := nafill(department_i, type='locf'), by=mrn]
dtcc


stop()
head(dtcc,20)
dtcc[order(mrn,admission), ward_move := shift(.SD, type="lag"), by=mrn ]


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
