# Date time suport for date types only comes with RMySQL 11.3, which is in unstable currently
# However, RMySQL 0.11.3 contains a bug that does not allow us to insert long entries in tr_log_num_tests_run
# We hence use RMySQL 0.10.9 and manually modify the created SQL columns to DATETIME

# Update to create new version of the data set
table.name <- "travistorrent_6_12_2016"

library(data.table)
library(RMySQL)
library(DBI)
library(anytime)

data <- read.csv("final_merged_build_jobs.csv")

data$git_diff_committers <- NULL

data$gh_is_pr <- data$gh_is_pr == "true"
data$gh_by_core_team_member <- data$gh_by_core_team_member == "true"
data$tr_log_bool_tests_ran <- data$tr_log_bool_tests_ran == "true"
data$tr_log_bool_tests_failed <- data$tr_log_bool_tests_failed == "true"

data$gh_first_commit_created_at <- anytime(data$gh_first_commit_created_at)
data$gh_build_started_at <- anytime(data$gh_build_started_at)

# convert to data table for easier access and modification of internal variables
data <- data.table(data)

# Sanitize data runs with NAs instead of 0s
data[tr_log_bool_tests_failed == T & tr_log_num_tests_failed == 0,]$tr_log_num_tests_failed <- NA
data[tr_log_bool_tests_failed == T & tr_log_num_tests_run == 0,]$tr_log_num_tests_run <- NA
data[tr_log_num_tests_ok < 0,]$tr_log_num_tests_ok <- NA
data[tr_log_num_tests_failed > tr_log_num_tests_run,]$tr_log_num_tests_run <- NA

data <- data.frame(data)

# Empty data in case no tests where run instead of NA, which indicates that we could not get some data
data[data$tr_log_bool_tests_ran == F,]$tr_log_bool_tests_failed <- ''
data[data$tr_log_bool_tests_ran == F,]$tr_log_num_tests_ok <- ''
data[data$tr_log_bool_tests_ran == F,]$tr_log_num_tests_failed <- ''
data[data$tr_log_bool_tests_ran == F,]$tr_log_num_tests_run <- ''
data[data$tr_log_bool_tests_ran == F,]$tr_log_num_tests_skipped <- ''

data <- data.table(data)

data[tr_log_bool_tests_ran == T & tr_log_num_tests_run == 0 & tr_log_num_tests_skipped == 0,]$tr_log_num_tests_run <- NA

data[tr_duration < 0,]$tr_duration <- NA

data$tr_prev_build <- as.integer(data$tr_prev_build)

write.csv(data, paste(table.name, "csv", sep="."), row.names = F)

# Manually convert logical to nuermical to fix bug in RMySQL of having no data after conversion
data$gh_is_pr <- as.numeric(data$gh_is_pr)
data$gh_by_core_team_member <- as.numeric(data$gh_by_core_team_member)
data$tr_log_bool_tests_ran <- as.numeric(data$tr_log_bool_tests_ran)
data$tr_log_bool_tests_failed <- as.numeric(data$tr_log_bool_tests_failed)

con <- dbConnect(dbDriver("MySQL"), user = "root", password = "root", dbname = "travistorrent", unix.socket='/var/run/mysqld/mysqld.sock')
dbListTables(con)
dbWriteTable(con, table.name, data, row.names = F, overwrite = T)
dbSendQuery(con, sprintf("ALTER TABLE %s MODIFY gh_build_started_at DATETIME;",table.name))
dbSendQuery(con, sprintf("ALTER TABLE %s MODIFY gh_first_commit_created_at DATETIME;",table.name))
dbSendQuery(con, sprintf("CREATE INDEX part_gh_project_name ON %s (gh_project_name(128));",table.name))
dbSendQuery(con, sprintf("CREATE INDEX tr_build_id ON %s (tr_build_id);",table.name))
dbSendQuery(con, sprintf("CREATE INDEX tr_build_id ON %s (tr_prev_build);",table.name))
dbDisconnect(con)
