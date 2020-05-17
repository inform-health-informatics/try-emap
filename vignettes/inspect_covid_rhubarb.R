# Steve Harris
# 2020-05-12
# Examine serum rhubarb for patients with COVID testing

# Load libraries
library(tidyverse)
library(lubridate) # not part of tidyverse
library(RPostgres)
# YMMV but I use data.table much more than tidyverse; Apologies if this confuses
library(data.table)


wdt <- readr::read_csv('data/secure/labs_covid.csv')
setDT(wdt)
pts <- readr::read_csv('data/secure/critical_care_bed_moves_and_outcomes.csv')
setDT(pts)
mrn_cc <- unique(pts[,.(mrn,critcare=max(critcare)==1)])
mrn_cc

# change dates to offset
# just data from first test
tdt <- wdt[result_datetime > covid_t0]
tdt[, days := (result_datetime - covid_t0)/ddays(1), by= mrn]
str(tdt)


# Now let's look at ddimer (local_code == tddi)
# ========================
# View(wdt[1:1e5])
# wdt[1:1e5][local_code == 'tddi']
ddimer <- tdt[local_code == 'tddi']
ddimer <- mrn_cc[ddimer, on='mrn']
ddimer[is.na(critcare), critcare := FALSE]
ddimer <- ddimer[,.(mrn,days,critcare,covid,result_text,value=as.numeric(result_text))]
ddimer
summary(ddimer)


ggplot(ddimer, aes(value)) + geom_density()
ggplot(ddimer, aes(value)) + geom_histogram()
ggplot(ddimer, aes(x=value,colour=covid)) + geom_density()

# d-dimer over time by covid status following the first test
ggplot(ddimer[value>10 & value < 75000],
       aes(x=days, y=value, group=covid, colour=covid)) +
  geom_point() +
  geom_smooth() +
  scale_y_log10() 

# d-dimer over time by covid status following the first test
ggplot(ddimer[value>10 & value < 75000 & covid == TRUE],
       aes(x=days, y=value, group=critcare, colour=critcare)) +
  geom_point() +
  geom_smooth() +
  scale_y_log10() +
  coord_cartesian(xlim=c(0,28))



lymph <- tdt[local_code == 'ly']
lymph <- mrn_cc[lymph, on='mrn']
lymph[is.na(critcare), critcare := FALSE]
lymph <- lymph[,.(mrn,days,critcare,covid,result_text,value=as.numeric(result_text))]
lymph
summary(lymph)


ggplot(lymph, aes(value)) + geom_density() + coord_cartesian(xlim=c(0,5))
ggplot(lymph, aes(x=value,colour=covid)) + geom_density() + coord_cartesian(xlim=c(0,5))

# lymph over time by covid status following the first test
ggplot(lymph[value < 10],
       aes(x=days, y=value, group=covid, colour=covid)) +
  geom_point(alpha=0.1) +
  geom_smooth() +
  scale_y_log10() +
  coord_cartesian(xlim=c(0,28))

# d-dimer over time by covid status following the first test
ggplot(lymph[value<10 & covid == TRUE],
       aes(x=days, y=value, group=critcare, colour=critcare)) +
  geom_point(alpha=0.1) +
  geom_smooth() +
  scale_y_log10() +
  coord_cartesian(xlim=c(0,28))
