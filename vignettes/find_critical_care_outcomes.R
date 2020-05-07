# Steve Harris
# 2020-05-06
# Calculate the severity of illness models for critical care
# Part 1: Identify critical care admissions
# Part 2: define the outcome
# Part 3: define the admitting physiology

# This file:
# Part 2 of 3: define outcomes / collect sex and age

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

# Load demographics
# =================
# This query calls a complex view of 'star' and takes a minute or so
query <- "SELECT * FROM uds.star.demographics"
dt <- DBI::dbGetQuery(ctn, query)
setDT(dt)
head(dt)

# Now load the critical care bed moves table you built in part 1
message('*** Check that you have built an up-to-date version of bed moves before you run this')
dtcc <- readr::read_csv("data/secure/critical_care_bed_moves.csv")
setDT(dtcc)

# Join on MRN
dtcc <- dt[,.(mrn,birthdate,sex,death_date)][dtcc,on="mrn"]
# Convert DoB to age in years
dtcc[, age:=floor((admission-birthdate)/ dyears(1))]
dtcc[, birthdate := NULL]

head(dtcc)
# Save this 
fwrite(dtcc, file="data/secure/critical_care_bed_moves_and_outcomes.csv")

# dtp <- unique(dtcc[,.(mrn,age,death=!is.na(death_date))])
# ggplot(dtp, aes(x=age,colour=death)) + geom_density()


