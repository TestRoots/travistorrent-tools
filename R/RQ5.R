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

system.time(data <- load.preprocessed.data(processed.data.file))

jobs.with.tests.t <- subset(data, tests_ran == 'true')
jobs.with.tests.t$tests_ran_b <- as.logical(jobs.with.tests.t$tests_ran)
jobs.with.tests.t$tests_failed_b <- as.logical(jobs.with.tests.t$tests_failed)
jobs.with.tests <- jobs.with.tests.t#[1:50000,]

#RQ5.1 How often do tests fail at all?

# Aggregate all jobs into one build
builds.with.tests <- aggregate(tests_failed_b ~ build_id + project_name + lang + tests_ran + status, jobs.with.tests, sum)
if(!length(unique(jobs.with.tests$build_id)) == length(builds.with.tests$build_id)) {
  print("Aggregation problem: Did not properly aggregate jobs per build!")
}
builds.with.tests$tests_failed_bin <- builds.with.tests$tests_failed_b > 0

# So we've aggregated over all jobs for one build, aggregate the thing per language 
percentage.of.failing.tests.per.proj.per.build <- aggregate(tests_failed_bin ~ project_name + lang, builds.with.tests, mean)

ggplot(percentage.of.failing.tests.per.proj.per.build) + 
  aes(x = lang, y = tests_failed_bin, fill=lang) + 
  geom_boxplot() +
  labs(x="Language", y="Percentage of builds in which tests failed",  fill="") +
  ggplot.defaults +
  scale_fill_manual(values = c("#93aa00","#b79f00")) +
  theme(legend.position = "none") + stat_summary(fun.y=mean, geom="point", shape=10, size=4)
save.plot("rq5_test_failures_per_build_per_lang.pdf")

#RESULT: summary for boxplots
summary(subset(percentage.of.failing.tests.per.proj.per.build, lang=='java'))
summary(subset(percentage.of.failing.tests.per.proj.per.build, lang=='ruby'))

java.tests.failed <- subset(percentage.of.failing.tests.per.proj.per.build, lang=='java')$tests_failed_bin
ruby.tests.failed <- subset(percentage.of.failing.tests.per.proj.per.build, lang=='ruby')$tests_failed_bin
wilcox.test(ruby.tests.failed, java.tests.failed)
cliffs.d(ruby.tests.failed, java.tests.failed)
VD.A(ruby.tests.failed, java.tests.failed)

# RQ5.2 How often do tests break the build?
#jobs.with.tests <- data[.(project), c('project_name', 'branch', 'build_id'), with = FALSE] data$tests_ran

# Of all builds with tests, 
builds.broken <- subset(builds.with.tests, status %in% c('failed','errored'))

builds.with.tests$overall.status <- 'errored'
builds.with.tests[builds.with.tests$status == 'passed',]$overall.status <- 'passed'
builds.with.tests[builds.with.tests$status == 'canceled',]$overall.status <- 'canceled'
builds.with.tests[builds.with.tests$status == 'failed' & builds.with.tests$tests_failed_bin==T,]$overall.status <- 'failed, tests'
builds.with.tests[builds.with.tests$status == 'failed' & builds.with.tests$tests_failed_bin==F,]$overall.status <- 'failed, general'

builds.with.tests.java <- builds.with.tests[builds.with.tests$lang == 'java',]
builds.with.tests.ruby <- builds.with.tests[builds.with.tests$lang == 'ruby',]

p <- ggplot(builds.with.tests, aes(x = lang, fill = overall.status)) + 
  geom_bar(width = 0.5, position = 'fill') + ggplot.small.defaults +  
  scale_fill_manual(values = c("passed" = "lightgreen", "failed, tests" = "darkred", "failed, general" = "red", errored = "black", "canceled" = "lightgrey")) +
  labs(x = "Language", y = "Percentage of builds", fill="")  + guides(fill = guide_legend(reverse=TRUE)) +
  theme(legend.position = "bottom") + scale_y_continuous(labels = percent_format()) 

freq = ggplot_build(p)$data[[1]]
freq$y_pos = (freq$ymin + freq$ymax) / 2
freq[1,]$y_pos = freq[1,]$y_pos-0.02
freq[6,]$y_pos = freq[6,]$y_pos-0.02
freq$y_pos <- freq$y_pos + 0.02

freq_temp <- freq[freq$group < 6,]
sum_temp <- sum(freq_temp$count)
freq[freq$group < 6,]$count <- round(freq_temp$count/sum_temp, 3) * 100

freq_temp <- freq[freq$group >= 6,]
sum_temp <- sum(freq_temp$count)
freq[freq$group >= 6,]$count <- round(freq_temp$count/sum_temp, 3) * 100

p + annotate(x=freq$x-0.35, y=freq$y_pos, label=paste(freq$count,"%",sep=""), geom="text", size=5.5)

save.plot("rq5_build_status_per_lang.pdf")

# RQ 5.3: Do test failures enforce build failures?
failed.tests <- builds.with.tests[builds.with.tests$tests_failed_bin==T,]
failed.tests.java <- subset(failed.tests, lang=="java")
failed.tests.ruby <- subset(failed.tests, lang=="ruby")

sprintf("Number of builds failed tests: %i", nrow(failed.tests))
sprintf("Number of builds failed tests java: %i", nrow(failed.tests.java))
sprintf("Number of builds failed tests ruby: %i", nrow(failed.tests.ruby))

sprintf("thereof number of builds failed: %i", nrow(subset(failed.tests, status=="failed")))
sprintf("Number of builds failed tests, java: %i", nrow(subset(failed.tests.java, status=="failed")))
sprintf("Number of builds failed tests, ruby: %i", nrow(subset(failed.tests.ruby, status=="failed")))

sprintf("Projects java: %i", length(unique(failed.tests.java$project_name)))
sprintf("Projects ruby: %i", length(unique(failed.tests.ruby$project_name)))
sprintf("Tests force-failed Java projects: %i", length(unique(subset(failed.tests.java, status=="failed")$project_name)))
sprintf("Tests force-failed Ruby projects: %i", length(unique(subset(failed.tests.ruby, status=="failed")$project_name)))


