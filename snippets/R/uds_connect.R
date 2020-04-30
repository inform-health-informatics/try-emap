library(RPostgres)

ctn <- DBI::dbConnect(RPostgres::Postgres(),
                      host = Sys.getenv("UDS_HOST"),
                      port = 5432,
                      user = Sys.getenv("UDS_USER"),
                      password = Sys.getenv("UDS_PWD"),
                      dbname = "uds")

all_schemas <- DBI::dbGetQuery(ctn, "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA")
