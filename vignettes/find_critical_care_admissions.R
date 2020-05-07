# Steve Harris
# 2020-05-06
# Calculate the severity of illness models for critical care
# Part 1: Identify critical care admissions
# Part 2: define the outcome
# Part 3: define the admitting physiology

# This file:
# Part 1 of 3: Identify critical care admissions

# Let's calculate the ICNARC acute physiology score for patients admitted to the
# ICU, and then plot this against their outcome First we need to identify
# patients admitted to a critical care area (easy-ish) Then we need to define
# the beginning of their admission. This is harder because they move between
# critical care areas, and because they may be readmitted.

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

# Load bed moves
# ==============
# THis query returns approx 1e6 rows so it takes a minute or so
query <- "SELECT * FROM uds.star.bed_moves"
dt <- DBI::dbGetQuery(ctn, query)
setDT(dt)


# The line below is a quick trick to inspect all departments
# View(dt[,.N,by=department][order(-N)])
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
# now number the department moves: department_i
temp[order(mrn,admission), department_i := seq_len(.N), by=.(mrn)][]
# # then create an reversed version (department_r) that you can use to identify the last move
# temp[order(mrn,-admission), department_r := seq_len(.N), by=.(mrn)][]

# finally join this back on to dtcc
# dtcc[, c("department_i", "department_r") := NULL]
dtcc <- temp[dtcc, on=.NATURAL]

# then roll the department variable forwards and back
dtcc[order(mrn,admission), department_i := nafill(department_i, type='locf'), by=mrn][]
# dtcc[order(mrn,admission), department_r := nafill(department_r, type='locf'), by=mrn][]

# drop intermediate columns
dtcc[, (c("department_jump", "time_jump", "hl7_location")) := NULL] # drop these intermediate columns

# department admission
dtcc[order(mrn,admission), dpt_admit_dt := min(admission), by=.(mrn,department_i) ]
# department discharge
dtcc[order(mrn,admission), dpt_disch_dt := max(discharge), by=.(mrn,department_i) ]

fwrite(dtcc, file="data/secure/critical_care_bed_moves.csv")


