#
# (c) 2015 - onwards Georgios Gousios <gousiosg@gmail.com>
# (c) 2015 - onwards Moritz Beller <moritzbeller@gmail.com>
#
# MIT Licensed, see LICENSE in top level dir
#


# Script to anonymize the prepared.csv


rm(list = ls(all = TRUE))

source('R/config.R')
source('R/utils.R')

data.to.save <- data
data.to.save$team_size <- NA
data.to.save$committers <- ""
data.to.save$src_churn <- NA
data.to.save$test_churn <- NA
data.to.save$files_added <- NA
data.to.save$files_deleted <- NA
data.to.save$files_modified <- NA
data.to.save$tests_added <- NA
data.to.save$tests_deleted <- NA
data.to.save$src_files <- NA
data.to.save$doc_files <- NA
data.to.save$other_files <- NA
data.to.save$main_team_member <- ""
data.to.save$commits_on_files_touched <- NA
data.to.save$num_commiters <- NA
data.to.save$sloc <- NA
data.to.save$test_lines_per_kloc <- NA
data.to.save$test_cases_per_kloc <- NA
data.to.save$asserts_per_kloc <- NA

write.csv(data.to.save, file="upload.filtered.data.csv", row.names=F)
