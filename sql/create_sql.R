# Date time suport only with RMySQL 11.3, which is unstable currently
devtools::install_github("rstats-db/DBI")
devtools::install_github("rstats-db/RMySQL")

library(data.table)
library(RMySQL)
library(DBI)

data <- fread("travistorrent-5-3-2016.csv")

data$gh_is_pr <- data$gh_is_pr == "true"
data$gh_by_core_team_member <- data$gh_by_core_team_member == "true"
data$tr_tests_ran <- data$tr_tests_ran == "true"
data$tr_tests_failed <- data$tr_tests_ran == "true"

data$gh_first_commit_created_at <- as.POSIXct(data$gh_first_commit_created_at)
data$tr_started_at <- as.POSIXct(data$tr_started_at)

con <- dbConnect(dbDriver("MySQL"), user = "root", password = "root", dbname = "travistorrent", unix.socket='/var/run/mysqld/mysqld.sock')
dbListTables(con)
dbWriteTable(con, "`travistorrent6-9-2016`", data)
dbDisconnect(con)

# Manually assert transformation of data types
dbDataType(con, data$gh_is_pr)
dbDataType(con, data$gh_first_commit_created_at)
dbDataType(con, data$tr_started_at)
