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
library(cliffsd)
library(effsize)
library(plyr)

system.time(data <- load.preprocessed.data(processed.data.file))


# TODO (GG): java -> Java; ruby -> Ruby 

# RQ 2.0: How projects execute at least tests once?, i.e. how many include a testing phase?
jobs.with.tests <- subset(data, tests_ran == 'true')
jobs.with.tests.java <- subset(jobs.with.tests, lang=="java")
jobs.with.tests.ruby <- subset(jobs.with.tests, lang=="ruby")

printf("Number of overall Java projects: %i", length(unique(subset(data, lang=="java")$project_name)))
printf("Number of overall Ruby projects: %i", length(unique(subset(data, lang=="ruby")$project_name)))
printf("Number of java projects with testing phase in at least one build: %i", length(unique(jobs.with.tests.java$project_name)))
printf("Number of ruby projects with testing phase in at least one build: %i", length(unique(jobs.with.tests.ruby$project_name)))

# RQ2.1
tests.per.build <- aggregate(run ~ build_id, data, function(x){ceiling(median(x))})
printf("Builds with tests: %f", nrow(subset(tests.per.build, run > 0)) / nrow(tests.per.build))

summary(tests.per.build)

# Filter the outliers to produce the following plots
max.normal.project <- quantile(tests.per.build$run, 0.9998)
tests.per.build <- tests.per.build[tests.per.build$run < max.normal.project,]

ggplot(data.frame(tests.per.build)) + aes(x = run) + 
  geom_histogram(binwidth = 1000) +
  scale_y_log10(labels = comma) +
  scale_x_continuous(labels = comma)+
  xlab("Tests run") + ylab("Number of builds") +
  ggplot.small.defaults
save.plot("rq2_tests_run_per_build.pdf")

# Per language 
tests.per.build <- aggregate(run ~ lang + build_id, data, median)

ggplot(tests.per.build) + 
  aes(x = lang, y = run, fill=lang) + 
  geom_boxplot() +
  scale_y_log10(labels = comma) +
  labs(x="Language", y="Tests run (log scale)",  fill="") +
  ggplot.defaults +
  scale_fill_manual(values = c("#93aa00","#b79f00")) +
  theme(legend.position = "none")
save.plot("rq2_tests_run_per_build_per_lang.pdf")

wilcox.test(subset(tests.per.build, lang == "ruby")$run, subset(tests.per.build, lang == "java")$run)

cliffs.d(subset(tests.per.build, lang == "ruby")$run, subset(tests.per.build, lang == "java")$run)
VD.A(subset(tests.per.build, lang == "ruby")$run, subset(tests.per.build, lang == "java")$run)

printf("Java projects: %d", nrow(subset(unique(data[, c('project_name', 'lang'), with = F]), lang == 'java')))
printf("Ruby projects: %d", nrow(subset(unique(data[, c('project_name', 'lang'), with = F]), lang == 'ruby')))

summary(subset(tests.per.build, lang == "ruby")$run)
summary(subset(tests.per.build, lang == "java")$run)

data$time_per_job <- data$duration / data$num_jobs
data <- subset(data, time_per_job <= 50 * 60)
data <- subset(data, testduration <= 50 * 60)
data <- subset(data, testduration > 0)
median.test.duration <- aggregate(testduration~build_id + lang, data, median)

median(median.test.duration$testduration)

ggplot(median.test.duration) +
  aes(x = lang, y = testduration, fill=lang) + 
  geom_boxplot() +
  scale_y_log10(labels = comma) +
  labs(x="Language", y="Test duration (seconds, log scale)",  fill="") +
  ggplot.defaults +
  stat_summary(fun.y=mean, geom="point", shape=10, size=4) +
  scale_fill_manual(values = c("#93aa00","#b79f00")) +
  theme(legend.position = "none")


# RQ2.2 How does testing influence the build time?
data$duration_per_job    <- data$duration / data$num_jobs

total.duration.per.build <- aggregate(duration_per_job ~ build_id, data, median)
setup.time.per.build     <- aggregate(setup_time ~ build_id, data, median)
test.duration.per.build  <- aggregate(testduration ~ build_id, data, median)
lang.per.build           <- unique(data[,.(build_id, lang), ])
  
timings.per.build <- merge(total.duration.per.build, test.duration.per.build)
timings.per.build <- merge(timings.per.build, setup.time.per.build)
timings.per.build <- merge(timings.per.build, lang.per.build)
timings.per.build$pre.test <- timings.per.build$duration_per_job - timings.per.build$setup_time - timings.per.build$testduration

summary(timings.per.build)
max.normal.case <- quantile(timings.per.build$duration_per_job, 0.99)
timings.per.build <- subset(timings.per.build, duration_per_job >= 1 & duration_per_job <= max.normal.case)
a <- timings.per.build
cor(timings.per.build)




timings.per.build <- a
timings.per.build <- subset(timings.per.build, testduration > 0)
timings.per.build <- subset(timings.per.build, duration_per_job > testduration)
timings.per.build <- subset(timings.per.build, pre.test > 0)

unq.time <- sort(unique(timings.per.build$duration))
timings.per.build$idx.duration <- apply(timings.per.build, 1, function(x){findInterval(x[2], unq.time)})
timings.per.build$build_id <- NULL
timings.per.build$setup_time <- NULL

timings.per.build <- rename(timings.per.build, 
                            c('duration_per_job' = 'Total build time', 
                              'testduration'='Testing phase', 
                              'setup_time'='Infrastructure provisioning',
                              'pre.test' = 'Pre-test phase'))

timings.per.build$lang <- revalue(timings.per.build$lang, c("java" = "Java", "ruby" = "Ruby"))
timings.per.build.melted <- melt(timings.per.build, id.vars = c('lang', 'idx.duration'))

ggplot(timings.per.build.melted) +
  aes(x = idx.duration, y = value, fill = variable) +
  geom_smooth(aes(color=variable)) +
  scale_y_continuous(labels=comma) +
  scale_x_continuous(breaks=c(1,23000), labels=c("fast", "slow")) +
  facet_grid(. ~ lang) +
  xlab("Build timing") +
  ylab("seconds") +
  #theme_few()+
  ggplot.small.defaults+
  theme(legend.position="bottom") 
  
save.plot("rq2_build_time_zoom_per_lang.pdf")

num.tests.per.build <- aggregate(tests_ran ~ build_id, data, median)

# RQ2.3: What is the provisioning time for running the CI?
setup.per.build <- aggregate(setup_time~build_id, data, max)
summary(setup.per.build$setup_time)

# Q: when where most builds with 0 setup time run? 
# A: In all years, so just report everything
builds.zero.start <- merge(setup.per.build[setup.per.build$setup_time <= 0, ], data)$started_at
table(strftime(builds.zero.start, format= "%Y"))

# exclude pathological cases
non.pathological <- quantile(setup.per.build$setup_time, 0.99)
setup.per.build <- setup.per.build[setup.per.build$setup_time <= non.pathological, ]

summary(setup.per.build$setup_time)
quantile(setup.per.build$setup_time, 0.80)
quantile(setup.per.build$setup_time, 0.90)

jobs.per.project <- aggregate(job_id~project_name, 
                              aggregate(job_id~project_name +  build_id, data, length), 
                              median)
quantile(jobs.per.project$job_id, 0.80)
quantile(jobs.per.project$job_id, 0.90)
# RQ2.4
# Calc diff build_started_at - commit_created_at -> latency 
# we care about this because comparison to IDE, test offloading, results immediacy 

earliest.job <- rename(aggregate(started_at~build_id, data, min), c("started_at" = "earliest_job"))
start.latency <- unique(subset(merge(data, earliest.job, by='build_id'), 
                                select=c('last_commit_before_build', 'earliest_job')))
start.latency$diff <- as.numeric(start.latency$earliest_job - start.latency$last_commit_before_build)/60
non.pathological <- quantile(start.latency$diff, 0.99)
start.latency <- start.latency[start.latency$diff <= non.pathological, ]

# Jobs can only last 50 mins max
data$duration_per_job <- data$duration / data$num_jobs
data <- subset(data, duration_per_job <= 50 * 60)

data$job_schedule_latency <- as.numeric(data$started_at - data$last_commit_before_build)
latency <- aggregate(job_schedule_latency~build_id, data, min)
setup.latency <- aggregate(setup_time ~ build_id, data, mean)

data$build.latency <- as.numeric(data$duration - data$setup_time)
build.latency <- aggregate(build.latency ~ build_id, data, mean)
lang.per.build  <- unique(data[,.(build_id, lang), ])

latency <- merge(latency, setup.latency)
latency <- merge(latency, build.latency)
latency <- merge(latency, lang.per.build)

latency <- subset(latency, job_schedule_latency > 0 & build.latency > 0)
latency <- subset(latency, job_schedule_latency < quantile(latency$job_schedule_latency, 0.99))
latency <- subset(latency, build.latency < quantile(latency$build.latency, 0.99))
latency <- subset(latency, setup_time < quantile(latency$setup_time, 0.99))
                    
latency$total <- latency$job_schedule_latency + latency$setup_time + latency$build.latency
  
unq.time <- sort(unique(latency$total))
latency$idx.duration <- apply(latency, 1, function(x){findInterval(x[6], unq.time)})

latency$lang <- revalue(latency$lang, c("java" = "Java", "ruby" = "Ruby"))
latency <- rename(latency, c('job_schedule_latency' = 'Job Scheduling latency',
                             'setup_time' = 'Provisioning latency', 
                             'build.latency' = 'Build latency',
                             'lang' = 'Language',
                             'total' = 'Total time'))

quantile(latency$`Job Scheduling latency`, 0.05) / 60
quantile(latency$`Job Scheduling latency`, 0.5)  / 60
quantile(latency$`Job Scheduling latency`, 0.95) / 60
mean(latency$`Job Scheduling latency`)           / 60

quantile(latency$`Provisioning latency`, 0.05)   / 60
quantile(latency$`Provisioning latency`, 0.5)    / 60
quantile(latency$`Provisioning latency`, 0.95)   / 60
mean(latency$`Provisioning latency`)             / 60

quantile(latency$`Build latency`, 0.05)          / 60
quantile(latency$`Build latency`, 0.5)           / 60
quantile(latency$`Build latency`, 0.95)          / 60
mean(latency$`Build latency`)


latency$build_id <- NULL
latency.melted <- melt(latency, id.vars = c('Language', 'idx.duration'))

ggplot(latency.melted) +
  aes(x = idx.duration, y = value, fill = variable) +
  geom_smooth(aes(color=variable)) +
  #scale_x_continuous() +
  xlab("nth fastest build") +
  ylab("Seconds") +
  facet_grid(. ~ Language) +
  theme_few()+
  theme(legend.position="top") 


