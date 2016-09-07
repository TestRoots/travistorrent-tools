# Date time suport for date types only comes with RMySQL 11.3, which is in unstable currently
devtools::install_github("rstats-db/RMySQL")
devtools::install_github("rstats-db/DBI")

library(data.table)
library(RMySQL)
library(DBI)

data <- fread("travistorrent_5_3_2016.csv")

data$gh_is_pr <- data$gh_is_pr == "true"
data$gh_by_core_team_member <- data$gh_by_core_team_member == "true"
data$tr_tests_ran <- data$tr_tests_ran == "true"
data$tr_tests_failed <- data$tr_tests_failed == "true"

data$gh_first_commit_created_at <- as.POSIXct(data$gh_first_commit_created_at)
data$tr_started_at <- as.POSIXct(data$tr_started_at)

con <- dbConnect(dbDriver("MySQL"), user = "root", password = "root", dbname = "travistorrent", unix.socket='/var/run/mysqld/mysqld.sock')
dbListTables(con)
dbWriteTable(con, "travistorrent_7_9_2016", data, row.names = F, overwrite = T)
dbDisconnect(con)

# Manually assert transformation of data types
dbDataType(con, data$gh_is_pr)
dbDataType(con, data$gh_first_commit_created_at)
dbDataType(con, data$tr_started_at)
