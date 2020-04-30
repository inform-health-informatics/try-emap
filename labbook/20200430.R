library(RPostgres)
library(data.table)
library(readr)
library(ggplot2)

ctn <- DBI::dbConnect(RPostgres::Postgres(),
                      host = Sys.getenv("UDS_HOST"),
                      port = 5432,
                      user = Sys.getenv("UDS_USER"),
                      password = Sys.getenv("UDS_PWD"),
                      dbname = "uds")


# query <- "SELECT * FROM uds.star_validation.bed_moves WHERE department = 'UCH T03 INTENSIVE CARE'"
query <- read_file("snippets/SQL/labs.sql")

dt <- DBI::dbGetQuery(ctn, query)
setDT(dt)
dt[,.N,by=local_code][order(-N)]
dt[,.N,by=mapped_name][order(-N)]



dt_covid <- dt[mapped_name == "Covid-19 Swab"]
dt_covid[, covid := ifelse(result_text == "POSITIVE", TRUE, FALSE)]
dt_covid <- unique(dt_covid[, .(mrn, covid)])
                   
dt_cr <- dt[local_code == "CREA"]
dt_cr[, creatinine := as.numeric(result_text)]
dt_cr <- dt_covid[dt_cr, on="mrn"]

mrn_list <- dt_cr[,.N,by=mrn][order(-N)][1:5]$mrn
dt_plot <- dt_cr[mrn %in% mrn_list]
gg <- ggplot(dt_plot, aes(x=result_datetime,
                  y=creatinine,
                  colour=covid,
                  group = mrn
                  ))
gg + geom_step()
