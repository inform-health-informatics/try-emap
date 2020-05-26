# Steve Harris
# 2020-05-08

# Load libraries
library(tidyverse)
library(lubridate) # not part of tidyverse
library(RPostgres)
# YMMV but I use data.table much more than tidyverse; Apologies if this confuses
library(data.table)
# Interactive plotting
library(plotly)
# the following allows the plots to be generated manually
library(dash)
library(dashCoreComponents)
library(dashHtmlComponents)
library(dashTable)

gg2dash <- function(p, port=8050, height=500) {
  # take a ggplot and try to use the dash library to plot
  # for interactive inspection
  fig <- ggplotly(p)
  
  app <- Dash$new()
  app$layout(
    htmlDiv(
      list(
        # note that you are still using the same plot created and saved as fig
        dccGraph(figure=fig,
                 responsive=TRUE,
                 style=list("height" = height)) 
      )
    )
  )
  # defaults to running at 127.0.0.1:8050
  app$run_server(debug=TRUE, block=TRUE, use_viewer = TRUE, port=port, dev_tools_hot_reload=FALSE)
}

# Load data
# =================
rdt <- readr::read_csv("data/secure/critical_care_bed_moves.csv")
setDT(rdt)
wdt <- data.table::copy(rdt)

wdt <- unique(wdt[critcare==TRUE,.(mrn,
                            critcare_i,
                            critcare_admission,
                            critcare_discharge,
                            los=(critcare_discharge-critcare_admission)/ddays(1)
                            )][order(critcare_admission)])
head(wdt)
# View(wdt[is.na(critcare_admission) | is.na(critcare_discharge)])
summary(wdt$los)

# simple inspection
ggplot(wdt, aes(x=los)) + geom_density()
gg <- ggplot(wdt, aes(x=critcare_admission, y=los)) + geom_point() + geom_smooth() + scale_y_log10()
gg2dash(gg)

# now ladder plot of all LoS
wdt

tdt <- wdt[critcare_admission > ymd("2020-03-01")]
tdt[, discharged := !is.na(critcare_discharge) ]

tdt[, censored := NULL]
tdt[, censored := critcare_discharge]
tdt[is.na(censored), censored := now()]
tdt[, los_censored := (censored - critcare_admission) / ddays(1)]
tdt

mmargin <- 1

gg <- ggplot(tdt, aes(x=critcare_admission,
                      ymin=critcare_admission,
                      ymax=censored,
                      colour = discharged)) +
  geom_linerange(alpha=0.5, size=0.5) +
  geom_text(data=tdt[los_censored>21 | !discharged], aes(x=critcare_admission,
                                  y=censored,
                                  label=mrn),
            angle=45,
            check_overlap = TRUE,
            hjust=-0.1,
            size=3) +
  scale_x_datetime(date_breaks = "1 week",
                   date_labels = "%b %d") +
  scale_y_datetime(date_breaks = "1 week",
                   date_labels = "%b %d") +
  xlab("Date of admission") +
  ylab("From admission to discharge (dates)") +
  coord_fixed(ratio=3/2) +
  theme_minimal()
  # theme_minimal(margin(t=2*mmargin,r=1*mmargin,b=1*mmargin,l=1*mmargin, unit="cm"))
gg
ggsave('media/critical_care_los_over_time.png')

gg2dash(gg, height=1000)


