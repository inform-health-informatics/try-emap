# Steve Harris
# Created 2020-05-06
# Change log
# 2020-05-09
# - work to define department at the functional rather than the ward level
# i.e. P03 and T03 are both critical care
# - plot LoS over time using R plotly



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


column_jump <- function(dt, col, order_vars, group, col_jump) {
        # helper function for collapse_over
        # Input: a data.table
        # Output: a data.table with a column (col) that flags 'steps'
        
        # define updates where the location changes; then keep those and the NAs
        # checks to see if the department has changed compared to the prev entry
        
        dt[order(get(order_vars)), 
             (col_jump) := shift(.SD, type="lag"), 
             by=list(get(group)), 
             .SDcols=col][
             , (col_jump) :=  get(col_jump) != get(col)]
        return(dt)
        
}

time_jump <- function(dt, in_time, out_time, order_vars, group) {
        # helper function for collapse_over
        # Input: a data.table with cols for in and out times (e.g. admission and discharge)
        # Output: a data.table with a column that flags 'steps' in a time-series
        
        # now need logic to check whether the gap between times is too big (i.e. a re-admission or not)
        # Specify gap between times for a new location to be considered a 're-admission'
        col_jump <- 'out2in_jump'
        
        dt[order(get(order_vars)), 
             (col_jump) := shift(.SD, type="lag"), 
             by=list(get(group)), 
             .SDcols=out_time][
             , (col_jump) :=  get(in_time) - get(col_jump)]
        return(dt)
        
}


collapse_over <- function(dt, col, in_time, out_time, order_vars, group, time_jump_window=dhours(4)) {
        # defines ward transitions based on a time series in of ward names
        # and a gap of sufficent size in the time that a re-admission is likely
        tdt <- data.table::copy(dt)
        col_jump <- paste0(col, '_jump')
        
        tdt <- column_jump(tdt, col, order_vars, group, col_jump)
        tdt <- time_jump(tdt, in_time, out_time, order_vars, group)
        
        # Now to collapse over ward episodes, just keep where either ward_jump | time_jump is true
        # keep all time_jumps > a window
        temp <- tdt[get(col_jump) | abs(out2in_jump) > time_jump_window | is.na(get(col_jump)) | is.na(out2in_jump)]
        # now number the department moves: department_i
        col_i <- paste0(col, '_i')
        temp[order(get(order_vars)), (col_i) := seq_len(.N), by=.(get(group))][]
        
        # finally join this back on to dt
        tdt <- temp[tdt, on=.NATURAL]
        
        # then roll the department variable forwards and back
        tdt[order(get(order_vars)), (col_i) := nafill(get(col_i), type='locf'), by=.(get(group))][]
        
        # drop intermediate columns
        tdt[, (c(col_jump, "out2in_jump")) := NULL] # drop these intermediate columns
        
        # department admission
        col_in <- paste0(col,'_',in_time)
        tdt[order(get(order_vars)), (col_in) := min(get(in_time)), by=.(get(group),get(col_i)) ]
        
        # department discharge
        col_out <- paste0(col,'_',out_time)
        tdt[order(get(order_vars)), (col_out) := max(get(out_time)), by=.(get(group),get(col_i)) ]
        
        return(tdt)
}

# Load bed moves
# ==============
# THis query returns approx 1e6 rows so it takes a minute or so
query <- "SELECT * FROM uds.star.bed_moves"
rdt <- DBI::dbGetQuery(ctn, query)
setDT(rdt)
wdt <- data.table::copy(rdt)

# The line below is a quick trick to inspect all departments
# View(dt[,.N,by=department][order(-N)])

# First find all MRNs that have been to a critical care area
# Narrow definition of critical care
critical_care_departments <- c( "UCH T03 INTENSIVE CARE", "UCH P03 CV" )
summary(wdt[department %in% critical_care_departments])
# Broad definition of critical care
# critical_care_departments <- c( "UCH T03 INTENSIVE CARE", "UCH P03 CV" , "UCH T07 HDRU")

wdt[, critcare := department %in% critical_care_departments]
mrncc <- unique(wdt[critcare == TRUE][,.(mrn)])

# then select all bedmoves related to those patients
wdt <- wdt[mrncc, on="mrn"][order(mrn,admission)]
head(wdt)

# Now collapse by department to appropriately define department level moves
tdt <- collapse_over(wdt, col='department', in_time='admission', out_time='discharge', order_vars=c('mrn','admission'), group='mrn')
# Now collapse by 'critcare' to appropriately define critical care admission periods
tdt <- collapse_over(tdt, col='critcare', in_time='admission', out_time='discharge', order_vars=c('mrn','admission'), group='mrn')

wdt <- tdt
head(wdt)
fwrite(wdt, file="data/secure/critical_care_bed_moves.csv")


