# Steve Harris
# 2020-05-12
# Examine serum rhubarb for patients with COVID testing

# Load libraries
library(tidyverse)
library(lubridate) # not part of tidyverse
library(RPostgres)
# YMMV but I use data.table much more than tidyverse; Apologies if this confuses
library(data.table)
library(Hmisc)
library(cowplot)

# This section builds and loads the constituent data
# ==================================================
wdt <- readr::read_csv('data/secure/labs_covid.csv')
setDT(wdt)
pts <- readr::read_csv('data/secure/critical_care_bed_moves_and_outcomes.csv')
setDT(pts)
pts
mrn_cc <- pts[,.(age=max(age,na.rm=TRUE),
                 sex=head(sex,1),
                 death_date=max(death_date,na.rm=TRUE))
                       ,by=mrn]
describe(mrn_cc)

# Need to 'zero' everything with respect to an initial time
# covid_t0 is the datetime of the first covid test
tdt <- wdt[result_datetime > covid_t0]
tdt[, days := (result_datetime - covid_t0)/ddays(1), by= mrn]
# View(tdt)

# This section should refactored so that is can work with different labs

# Now let's look at CRP (local code = cpr)
# ========================================
lab_label <- "CRP"
llocal_code <- "crp"

lab <- tdt[local_code == llocal_code]
lab <- mrn_cc[lab, on='mrn']
lab[, dead := !is.na(death_date)]
str(lab)
lab <- lab[,.(mrn,days,age,sex,dead,death_date,covid,result_text,value=as.numeric(result_text))]

lab[, dead:=factor(dead, levels=c(TRUE,FALSE), labels=c("Non-survivor", "Survivor"))]
lab[, covid:=factor(covid, levels=c(TRUE,FALSE), labels=c("COVID-Pos", "COVID-Neg"))]

describe(lab)

# Simple inspection of distribution
# ggplot(lab, aes(value)) + geom_density()
p_dens <- ggplot(lab, aes(x=value,colour=dead)) + geom_density() + theme_cowplot()
p_dens
# ggplot(lab, aes(x=value)) + geom_density() + facet_wrap(~covid)
# ggplot(lab, aes(x=value)) + geom_density() + facet_wrap(dead~covid)

# box plot wins
p_box <- ggplot(lab, aes(x=dead,y=value)) +
  geom_boxplot() +
  facet_wrap(~covid) +
  ggtitle(lab_label) +
  theme_cowplot()
p_box

# next just inspect a few trajectories
set.seed(20200517)
# mrn_p <- sample(unique(lab[covid=="COVID-Pos"]$mrn), 8)
# mrn_n <- sample(unique(lab[covid=="COVID-Neg"]$mrn), 8)
mrn_p <- sample(unique(lab[dead=="Non-survivor"]$mrn), 8)
mrn_n <- sample(unique(lab[dead=="Survivor"]$mrn), 8)
mrn_pn <- c(mrn_p, mrn_n)

# lab over time by covid status following the first test
p_i <- ggplot(lab[mrn %in% mrn_pn],
       aes(x=days, y=value, colour=dead)) +
  geom_point() +
  geom_smooth(se=FALSE) +
  facet_wrap(~mrn) +
  coord_cartesian(xlim=c(0,21),
                  ylim=c(0,600)) +
  theme_cowplot()
p_i

# lab over time by covid status following the first test
p_sm <- ggplot(lab,
       aes(x=days, y=value, group=dead, colour=dead)) +
  geom_point(alpha=0.1) +
  geom_smooth() +
  coord_cartesian(xlim=c(0,21)) +
  theme_cowplot()
p_sm

cowplot::plot_grid(p_dens, p_box, p_sm, p_i)

