#
# (c) 2015 - onwards Georgios Gousios <gousiosg@gmail.com>
# (c) 2015 - onwards Moritz Beller <moritzbeller@gmail.com>
#
# MIT Licensed, see LICENSE in top level dir
#

rm(list = ls(all = TRUE))

source('R/config.R')
source('R/utils.R')

library(data.table)
library(plyr)
library(foreach)
library(doMC)
registerDoMC(num.processes)

# Load data
system.time(data <- load.raw.data(raw.data.file))

# Filter out projects with too many builds 
# builds.per.project <- aggregate(build_id~project_name, data, function(x){length(unique(x))})
# hist(builds.per.project$build_id, breaks = 100)
# 
# builds.per.project.filtered <- subset(builds.per.project,
#                                       build_id <= fancy.threshold(builds.per.project$build_id))
# hist(builds.per.project.filtered$build_id, breaks = 100)
# 
# data.filtered <- subset(data, project_name %in% builds.per.project.filtered$project_name)

# Filter out projects with too little builds

prev.builds <- function(data) {

  foreach(project=unique(data$project_name), .combine=rbind) %dopar% {
    # Slice data frame per project to reduce expensive lookups
    builds.per.project <- data[.(project), c('project_name', 'branch', 'build_id'), with = FALSE]
    res <- data.table(build_id = unique(builds.per.project$build_id), prev_build = -1) 
    
    # For each unique build
    for (bld in sort(unique(builds.per.project$build_id))) {
      
      # Find branch for which this build was triggered
      br <- as.character(unique(builds.per.project[build_id == bld]$branch)[1])
      
      # Find the first build with build_id less that the current build in the same branch
      prevs <- sort(builds.per.project[branch == br, ]$build_id)
      prev.idx <- which.min(prevs < bld)
      prev <- prevs[prev.idx - 1]
       if (!length(prev) == 0) {
         printf("project: %s, branch: %s, build: %d, prev: %d", project, br, bld, prev)
         #data[.(project, br, bld), 'prev_build' := prev, with = FALSE]
         res['build_id' == bld, 'prev_build' := prev]
       }
    }
    res
  }
}

prev   <- prev.builds(data)
# The following is to avoid changing the order of rows
interm <- merge(data, prev, by=('build_id'))
data   <- interm$prev_build

# TODO: GG
nrow(subset(data, duration > 50 * 60 * num_jobs))
nrow(subset(data, testduration > 50 * 60)) # set this to NA

# calculate the timestamp of the latest commit that triggered the build
build.commits <- data.table(unique(subset(data, select=c('build_id', 'commits'))))
setkey(build.commits, build_id)

builds.commits <- foreach(bld=unique(build.commits$build_id), 
        .combine=function(x,y)rbindlist(list(x,y))) %dopar% {
          
  commits <- build.commits[.(bld), c('commits'), with = F]
  c <- strsplit(as.character(commits), "#")[[1]]
  data.table(build_id = bld, commits = c)
}

write.csv(builds.commits, file='data/builds.commits.csv', row.names = F)
builds.commits <- read.csv('data/builds.commits.csv', 
                           colClasses = c('integer', 'character', 'integer'))
builds.commits$timestamp <- as.POSIXct(builds.commits$timestamp, origin = "1970-01-01")
last.commit.per.build <- aggregate(timestamp~build_id, builds.commits, max)
last.commit.per.build <- rename(last.commit.per.build, c("timestamp" = "last_commit_before_build"))

data <- merge(data, last.commit.per.build, by="build_id")

write.csv(data, file=processed.data.file, row.names=F)
