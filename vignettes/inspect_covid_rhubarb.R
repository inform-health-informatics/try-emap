# Steve Harris
# Created 2020-05-12
# Updated 2020-05-18
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
# mrn_cc

# Need to 'zero' everything with respect to an initial time
# covid_t0 is the datetime of the first covid test
tdt <- wdt[result_datetime > covid_t0]
tdt[, days := (result_datetime - covid_t0)/ddays(1), by= mrn]
# View(tdt)


rhubarb_sm <- function(lab, time_windows=c(3,7,14), vtrans=vtrans) {
    # expects a datatable with just a single lab value
    # returns a cowplot of a series of time horizon plots
    plts <- list()
    
    for (i in time_windows) {
      # print(i)
      plt_i <- paste0('plt_', i)
      mrn_i <- unique(lab[days>i,.(mrn)])
      dt_i <- mrn_i[lab, on='mrn',nomatch=0][days<i]
      print(nrow(dt_i))
      # lab over time by covid status following the first test
      plt <- ggplot(dt_i,
                     aes(x=days, y=value)) +
        geom_line(aes(group=mrn, colour=dead), alpha=0.15, size=0.5) +
        geom_point(aes(colour=dead), alpha=0.1) +
        geom_smooth(aes(group=dead, colour=dead)) +
        scale_y_continuous(trans=vtrans) +
        coord_trans(y=vtrans) +
        guides(colour=FALSE) +
        ggtitle(paste("...", i, "days")) +
        theme_cowplot() +
        theme(
          axis.text.y = element_text(size = 8),
          text = element_text(size = 8),
          plot.title = element_text(size=8)
          
        )
      if (i==min(time_windows)) {
        print('first plot')
        plts[[plt_i]] <- plt
      } else {
        print('other plots')
        plts[[plt_i]] <- plt +
          theme(axis.title.y = element_blank(),
                axis.text.y = element_blank())
      }
      
    }

    p_cow <- cowplot::plot_grid(plotlist=plts, nrow=1)
    return(p_cow)
}
#rhubarb_sm(lab, vtrans='identity')

rhubarb_cowplot <- function(x, tdt, save_pdf=TRUE, file_path=NULL, sampleN=NULL, time_windows=c(3,7,14)) {
  
  # extract args from list
  lab_label <- x$label
  llocal_code <- x$local_code
  lab_lim <- x$limits
  vtrans <- x$vtrans
  
  if (is.null(file_path)) {
    file_path_name <- paste0("media/plots/rhubarb/", "cow", lab_label, ".pdf")
  } else {
    file_path_name <- paste0(file_path, "cow", lab_label, ".pdf")
  }
  
  # prepare data
  lab <- tdt[local_code == llocal_code]
  lab <- mrn_cc[lab, on='mrn']
  lab[, dead := !is.na(death_date)]
  lab <- lab[,.(mrn,days,age,sex,dead,death_date,covid,result_text,value=as.numeric(result_text))]
  print(lab)
  # drop out of range values
  lab <- lab[value > lab_lim[1] & value < lab_lim[2]]
  
  # label
  lab[, dead:=factor(dead, levels=c(TRUE,FALSE), labels=c("Non-survivor", "Survivor"))]
  lab[, covid:=factor(covid, levels=c(TRUE,FALSE), labels=c("COVID-Pos", "COVID-Neg"))]
  
  # keep just patients with data in the first 3 weeks following the test
  lab <- lab[days < 21 ]
  lab[, N := .N, by=mrn]
  lab[, mrn := paste0("ID-",.GRP), by=mrn]
  
  # describe variable as you go along
  print(describe(lab$value))
  
  # Simple inspection of distribution
  p_dens <- ggplot(lab[covid=="COVID-Pos"], aes(x=value,colour=dead)) +
    geom_density() +
    scale_x_continuous(trans=vtrans) +
    ggtitle(paste(lab_label, "distribution by survivor status")) +
    theme_cowplot() +
    theme(
      plot.title = element_text(size=8)
    )
  
  # box plot
  p_box <- ggplot(lab, aes(x=dead,y=value, colour=dead)) +
    geom_boxplot() +
    facet_wrap(~covid) +
    scale_y_continuous(trans=vtrans) +
    guides(colour=FALSE) +
    ggtitle(lab_label) +
    ggtitle(paste(lab_label, "distribution by COVID and Survivor status")) +
    theme_cowplot() +
    theme(
      plot.title = element_text(size=8)
    )
  
  # next just inspect a few trajectories
  set.seed(20200517)
  if (is.null(sampleN)) {
    sampleN <- 8
  }
  # mrn_p <- sample(unique(lab[covid=="COVID-Pos"]$mrn), 8)
  # mrn_n <- sample(unique(lab[covid=="COVID-Neg"]$mrn), 8)
  mrn_p <- sample(unique(lab[covid == "COVID-Pos" & N > 3 & dead=="Non-survivor"]$mrn), sampleN)
  mrn_n <- sample(unique(lab[covid == "COVID-Pos" & N > 3 & dead=="Survivor"]$mrn), sampleN)
  mrn_pn <- c(mrn_p, mrn_n)
  
  # lab over time by covid status following the first test
  p_i <- ggplot(lab[mrn %in% mrn_pn],
         aes(x=days, y=value, colour=dead)) +
    geom_point(size=1) +
    geom_smooth(size=0.5, se=FALSE) +
    scale_y_continuous(trans=vtrans) +
    facet_wrap(~mrn) +
    guides(colour=FALSE) +
    ggtitle("Random selection of 12 COVID-Pos trajectories following first test") +
    theme_cowplot() +
    theme(
      axis.text = element_text(size=4),
      strip.text.x = element_text(size=8),
      strip.background = element_blank(),
      plot.title = element_text(size=8)
    )
 
  p_sm <- rhubarb_sm(lab, time_windows=time_windows, vtrans=vtrans)
  
  
  p_cow <- cowplot::plot_grid(p_dens, p_box, p_sm, p_i)
  if (save_pdf) {
    print(paste("-- saving as PDF to", file_path_name))
    save_plot(file_path_name, p_cow, nrow=2, ncol=2)
  }
  return(p_cow)
  
}

labs <- list()
labs$crp <- list(label = "CRP", local_code = "crp", limits = c(0,600), vtrans="identity")
rhubarb_cowplot(labs[['crp']], tdt)

labs$ddimer <- list(label = "D-dimer", local_code = "tddi", limits = c(10,40000), vtrans="log10")
rhubarb_cowplot(labs[['ddimer']], tdt)

labs$lymph <- list(label = "Lymphocytes", local_code = "ly", limits = c(0,3), vtrans="identity")
rhubarb_cowplot(labs[['lymph']], tdt)

describe(as.numeric( tdt[local_code == "ldh"][['result_text']]))
labs$ldh <- list(label = "LDH", local_code = "ldh", limits = c(0,10000), vtrans="log10")
rhubarb_cowplot(labs[['ldh']], tdt)

tdt[local_code == "esr"]
describe(as.numeric( tdt[local_code == "esr"][['result_text']]))
labs$esr <- list(label = "ESR", local_code = "esr", limits = c(0,140), vtrans="identity")
rhubarb_cowplot(labs[['esr']], tdt, sampleN=3)

tdt[local_code == "bnpn"]
describe(as.numeric( tdt[local_code == "bnpn"][['result_text']]))
labs$bnp <- list(label = "nt-proBNP", local_code = "bnpn", limits = c(0,100000), vtrans="log10")
rhubarb_cowplot(labs[['bnp']], tdt, sampleN=3)

tdt[local_code == "ferr"]
describe(as.numeric( tdt[local_code == "ferr"][['result_text']]))
labs$ferr <- list(label = "Ferritin", local_code = "ferr", limits = c(30,30000), vtrans="log10")
rhubarb_cowplot(labs[['ferr']], tdt)

tdt[local_code == "htrt"]
describe(as.numeric( tdt[local_code == "htrt"][['result_text']]))
labs$trop <- list(label = "Troponin", local_code = "htrt", limits = c(0,5000), vtrans="log10")
rhubarb_cowplot(labs[['trop']], tdt)

# View(unique(tdt[,.(local_code, reference_range)][order(reference_range)]))
# tdt[local_code == "trp"]

