# Steve Harris
# 2020-05-08

stop("TODO: where admission is missing then assume left_censored and replace with 1/1/2020")

# Load libraries
library(tidyverse)
library(lubridate) # not part of tidyverse
library(RPostgres)
# YMMV but I use data.table much more than tidyverse; Apologies if this confuses
library(data.table)
critical_care_departments <- c( "UCH T03 INTENSIVE CARE", "UCH P03 CV" )

# Load data
# =================
rdt <- readr::read_csv("data/secure/critical_care_bed_moves.csv")
setDT(rdt)
wdt <- data.table::copy(rdt)
wdt
wdt <- unique(wdt[critcare==TRUE,.(mrn,
                            critcare_i,
                            department,
                            admission,
                            discharge
                            )][order(admission)])
head(wdt)
summary(wdt$los)


# now use these data to plot occupancy
# setnames(wdt,c('critcare_admission','critcare_discharge'), c('admission', 'discharge') )
# View(wdt)

ts_begin <- min(wdt$admission, na.rm = TRUE)
ts_end <- max(c(wdt$admission, wdt$discharge), na.rm = TRUE)

tss <- seq(ts_begin, ts_end, by="1 hour")
length(tss)
# alt method of counting occupancy using a cross join
tdt <- data.table::copy(wdt)
# create a unique key for the join
tdt[order(admission), rowid := seq_len(.N)]
setkey(tdt, rowid)
udt <-  tdt[CJ(rowid=rowid, ts=tss)]

# flag inpatient periods
udt[department=="UCH T03 INTENSIVE CARE", inpatient_t03 := NA]
udt[department=="UCH T03 INTENSIVE CARE" & !is.na(admission) & !is.na(discharge), inpatient_t03 := FALSE]
udt[department=="UCH T03 INTENSIVE CARE" & (admission < ts & (discharge > ts | is.na(discharge))), inpatient_t03 := TRUE]
table(udt$inpatient_t03, useNA="always")

udt[department=="UCH P03 CV", inpatient_p03 := NA]
udt[department=="UCH P03 CV" & !is.na(admission) & !is.na(discharge), inpatient_p03 := FALSE]
udt[department=="UCH P03 CV" & (admission < ts & (discharge > ts | is.na(discharge))), inpatient_p03 := TRUE]
table(udt$inpatient_p03, useNA="always")

udt

vdt <- udt[,.(
  inpatients_t03 = sum(inpatient_t03, na.rm=TRUE),
  inpatients_p03 = sum(inpatient_p03, na.rm=TRUE)
              ),by=.(ts)]

vdt <- melt.data.table(vdt, id.vars = "ts",
                       measure.vars = c("inpatients_t03", "inpatients_p03"),
                       variable.name = 'department',
                       value.name = 'inpatients')
tail(vdt[department=='inpatients_t03'])

ggplot(vdt, aes(x=ts, y=inpatients, colour=department)) + geom_step()
ggsave('media/aggregate/figs/cc_occupancy_2020-05-12.png')
# write_csv(dtocc, 'data/dtocc.csv')

