#
# (c) 2015 - onwards Georgios Gousios <gousiosg@gmail.com>
# (c) 2015 - onwards Moritz Beller <moritzbeller@gmail.com>
#
# MIT Licensed, see LICENSE in top level dir
#

rm(list = ls(all = TRUE))

source('R/config.R')
source('R/utils.R')

library(ggplot2)
library(scales)
library(reshape2)
library(data.table)


system.time(data <- load.preprocessed.data(processed.data.file))

jobs.with.tests <- subset(data, tests_ran == 'true')
setkey(jobs.with.tests, build_id, lang, project_name)
gc()

#RQ4 How often do tests fail at all?

# Aggregate all jobs into one build
jobs.status <- aggregate(tests_failed ~ build_id + lang + project_name, jobs.with.tests, equal.build.status)

printf("Java # of Jobs in which build environment results differentiated %i", nrow(subset(jobs.status, tests_failed == F & lang == 'java')))
printf("Java # of Jobs in which build environments was same %i", nrow(subset(jobs.status, tests_failed == T & lang == 'java')))
printf("Ruby # of Jobs in which build environment results differentiated %i", nrow(subset(jobs.status, tests_failed == F & lang == 'ruby')))
printf("Ruby # of Jobs in which build environments was same %i", nrow(subset(jobs.status, tests_failed == T & lang == 'ruby')))

printf("# of Jobs in which build environment results differentiated %i", nrow(subset(jobs.status, tests_failed == F)))
printf("# of Jobs in which build environments was same %i", nrow(subset(jobs.status, tests_failed == T)))

jobs.status.java <- subset(jobs.status, lang == 'java')
jobs.status.ruby <- subset(jobs.status, lang == 'ruby')
sprintf("Projects java: %i", length(unique(jobs.status.java$project_name)))
sprintf("Projects ruby: %i", length(unique(jobs.status.ruby$project_name)))
sprintf("Java # of Project in which build environment results differentiated %i", length(unique(subset(jobs.status.java, tests_failed == F)$project_name)))
sprintf("Ruby # of Project in which build environment results differentiated s: %i", length(unique(subset(jobs.status.ruby, tests_failed == F)$project_name)))
