# Date time suport for date types only comes with RMySQL 11.3, which is in unstable currently
# However, RMySQL 0.11.3 contains a bug that does not allow us to insert long entries in tr_tests_run
# We hence use RMySQL 0.10.9 and manually modify the created SQL columns to DATETIME

# Update to create new version of the data set
table.name <- "travistorrent_30_9_2016"

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

# Sanitize data runs with NAs instead of 0s
data[tr_tests_failed == T & tr_tests_fail == 0,]$tr_tests_fail <- NA
data[tr_tests_failed == T & tr_tests_run == 0,]$tr_tests_run <- NA
data[tr_tests_ok < 0,]$tr_tests_ok <- NA
data[tr_tests_fail > tr_tests_run,]$tr_tests_run <- NA

# Sanitize previous builds as NA instead of -1
data[tr_prev_build == -1,]$tr_prev_build <- NA

write.csv(data, paste(table.name, "csv", sep="."), row.names = F)

con <- dbConnect(dbDriver("MySQL"), user = "root", password = "root", dbname = "travistorrent", unix.socket='/var/run/mysqld/mysqld.sock')
dbListTables(con)
dbWriteTable(con, table.name, data, row.names = F, overwrite = T)
dbSendQuery(con, sprintf("ALTER TABLE %s MODIFY tr_started_at DATETIME;",table.name))
dbSendQuery(con, sprintf("ALTER TABLE %s MODIFY gh_first_commit_created_at DATETIME;",table.name))
dbDisconnect(con)
