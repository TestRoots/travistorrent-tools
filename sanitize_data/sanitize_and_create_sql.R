# Date time suport for date types only comes with RMySQL 11.3, which is in unstable currently
# However, RMySQL 0.11.3 contains a bug that does not allow us to insert long entries in tr_log_num_tests_run
# We hence use RMySQL 0.10.9 and manually modify the created SQL columns to DATETIME

# Update to create new version of the data set
table.name <- "travistorrent_30_1_2017"

library(data.table)
library(foreach)
library(doMC)
library(RMySQL)
library(DBI)
library(parsedate)

registerDoMC(cores = 4)

data <- read.csv("complete_merger_pre_sanitized_30_1_2017.csv")

# data$git_diff_committers <- NULL

data$gh_is_pr <- data$gh_is_pr == "true"
data$gh_by_core_team_member <- data$gh_by_core_team_member == "true"
data$tr_log_bool_tests_ran <- data$tr_log_bool_tests_ran == "true"
data$tr_log_bool_tests_failed <- data$tr_log_bool_tests_failed == "true"

# Our dates are in ISO 8601
data$gh_first_commit_created_at <- parse_date(as.character(data$gh_first_commit_created_at))
data$gh_build_started_at <- parse_date(as.character(data$gh_build_started_at))
data$gh_pushed_at <- parse_date(as.character(data$gh_pushed_at))
data$gh_pr_created_at <- parse_date(as.character(data$gh_pr_created_at))

# Convert to data table for easier access and modification of internal variables
data <- data.table(data)
setkey(data, tr_build_id)

# Sanitize data runs with NAs instead of 0s
data[tr_log_bool_tests_failed == T & tr_log_num_tests_failed == 0,]$tr_log_num_tests_failed <- NA
data[tr_log_bool_tests_failed == T & tr_log_num_tests_run == 0,]$tr_log_num_tests_run <- NA
data[tr_log_num_tests_ok < 0,]$tr_log_num_tests_ok <- NA
data[tr_log_num_tests_failed > tr_log_num_tests_run,]$tr_log_num_tests_run <- NA

# Build a boolean vector saying whether the build was completely successful or not (abstracting over all different failure reasons)
data$build_successful <- data$tr_status == "passed"

# Append the previous build status
get_prev_build_status <- function(previous_build, project.data) {
  subset(project.data, tr_build_id == previous_build)$tr_status[1]
}

gen.data <- foreach(project=unique(data$gh_project_name), .combine=rbind) %dopar% {
  project.data <- subset(data, gh_project_name == project)
  setkey(project.data, tr_build_id)
  
  #project.data[, tr_prev_build_status := get_prev_build_status(tr_prev_build[1]), by=tr_build_id]
  tmp.res <- list()
  for(build in unique(project.data$tr_build_id)) {
    tr_prev_build <- subset(project.data, tr_build_id == build)$tr_prev_build
    tmp.res <- rbind(tmp.res, list("tr_build_id"=build, "tr_prev_build_status"=get_prev_build_status(tr_prev_build[1], project.data)))
  }
  tmp.res
}

gen.data <- as.data.frame(gen.data)
gen.data$tr_build_id <- as.integer(gen.data$tr_build_id)
gen.data$tr_prev_build_status <- unlist(gen.data$tr_prev_build_status)
data <- merge(data, gen.data, by="tr_build_id")

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
dbSendQuery(con, sprintf("ALTER TABLE %s MODIFY gh_pushed_at DATETIME;",table.name))
dbSendQuery(con, sprintf("ALTER TABLE %s MODIFY gh_pr_created_at DATETIME;",table.name))
dbSendQuery(con, sprintf("CREATE INDEX part_gh_project_name ON %s (gh_project_name(128));",table.name))
dbSendQuery(con, sprintf("CREATE INDEX tr_build_id ON %s (tr_build_id);",table.name))
dbSendQuery(con, sprintf("CREATE INDEX tr_prev_build ON %s (tr_prev_build);",table.name))
dbDisconnect(con)
