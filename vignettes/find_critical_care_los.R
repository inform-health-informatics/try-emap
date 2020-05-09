# Steve Harris
# 2020-05-08
# Using data files from 1+2 below
# Part 1: Identify critical care admissions
# Part 2: define the outcome


# This file:
# Additional: Calculate LoS (length of stay)

# Load libraries
library(tidyverse)
library(lubridate) # not part of tidyverse
library(RPostgres)
# YMMV but I use data.table much more than tidyverse; Apologies if this confuses
library(data.table)


# Load data
# =================
dtcc <- readr::read_csv("data/secure/critical_care_bed_moves_and_outcomes.csv")
setDT(dtcc)
head(dtcc)

# Define critical care as either T03 or P03
dtcc[, cc := ifelse(department == "UCH T03 INTENSIVE CARE" | department == "UCH P03 CV", TRUE,FALSE)]
# View(dtcc[,.(mrn,age,sex,death_date,admission,discharge,department,department_i,bed,dpt_admit_dt,dpt_disch_dt)])
# Drop all non critical care rows


dtcc[, bed_los := (discharge - admission)/ddays(1)]
dtcc[cc ==TRUE, cc_los := sum(bed_los), by= mrn]
# View(dtcc)

dt_los <- dtcc[cc == TRUE, .(
  admission = min(admission), 
  cc_los = min(cc_los, na.rm = TRUE),
  age=min(age),
  sex=min(sex),
  dead=max(!is.na(death_date))
  ), by=mrn]
dt_los

summary(dt_los)

ggplot(dt_los, aes(x=cc_los)) + geom_density()
ggplot(dt_los, aes(x=cc_los, colour=dead==1)) + geom_density()

ggplot(dt_los, aes(x=admission, y=cc_los)) + geom_point() + geom_smooth() + scale_y_sqrt()

