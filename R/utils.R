#
# (c) 2015 - onwards Georgios Gousios <gousiosg@gmail.com>
# (c) 2015 - onwards Moritz Beller <moritzbeller@gmail.com>
#
# MIT Licensed, see LICENSE in top level dir
#

library(data.table)
library(ggplot2)
library(ggthemes)
library(scales)

# printf for R
printf <- function(...) invisible(print(sprintf(...)))


### ggplot configuration
ggplot.defaults <- 
  #theme(axis.text.x = element_text(size = 15)) +
  #theme(axis.text.y = element_text(size = 15)) +
  theme_few() +
  #theme(legend.key = element_blank()) +
  #theme(axis.title.x = element_blank(), axis.title.y = element_blank())  +
  theme(axis.text.x = element_text(size = 20)) + 
  theme(axis.text.y = element_text(size = 20)) +
  theme(axis.title.x = element_text(size = 18, vjust = 1)) +
  theme(axis.title.y = element_text(size = 18, vjust = 1)) +
  theme(legend.text = element_text(size = 16))  +
  theme(legend.title = element_text(size = 18)) 
# Hint: Add for 1,000  scale_y_continuous(labels=comma) + scale_x_continuous(labels=comma)


ggplot.small.defaults <-
  ggplot.defaults + theme(axis.title.x = element_text(size = 18, vjust = -0.5)) +
  theme(axis.title.y = element_text(size = 18, hjust = 0.5, vjust = 1.5))


plot.location <- function(filename) {
  file.path("paper", "figs", filename)
}

save.plot <- function(filename) {
  ggsave(plot.location(filename))
}

save.pdf <- function(plot, filename, width = 7, height = 7) {
  pdf(plot.location(filename), height = height, width = width)
  print(p)
  dev.off()
}


load.raw.data <- function(path) {
  colClasses = c("character", rep("factor",6), rep("integer", 2), "character",
                 rep("integer", 4), "factor", rep("integer", 12), rep("double", 3), "factor",
                 rep("integer", 3), "factor", "integer",  rep("factor",2),
                 rep("integer", 2), "factor", "integer",  rep("factor", 2),
                 rep("integer", 4), "character", rep("double", 2), rep("factor", 2))
  a <- load.data(path, colClasses)
  a$num_committers <- unlist(Map(length, strsplit(as.character(a$committers), '#')))
  a$num_jobs       <- unlist(Map(length, strsplit(as.character(a$jobs), ',')))
  a
}

load.preprocessed.data <- function(path) {

  colClasses = c("character", rep("factor",7), "integer", "character",
                 rep("integer", 4), "factor", rep("integer", 12), rep("double", 3), "factor",
                 rep("integer", 3), "factor", "integer",  rep("factor",2),
                 rep("integer", 2), "factor", "integer",  rep("factor", 2),
                 rep("integer", 4), "character", rep("double", 2), rep("factor", 2), rep('integer',3))
  load.data(path, colClasses)
}

# Load main data file, do necessary conversions
load.data <- function(path, colclasses = c()) {
  setAs("character", "POSIXct",
        function(from){as.POSIXct(from, origin = "1970-01-01")})
  
  a <- read.csv(path, check.names = T, colClasses = colclasses, quote='"')
  a$first_commit_created_at <- as.POSIXct(a$first_commit_created_at, origin = "1970-01-01")
  a$started_at              <- as.POSIXct(gsub("(.*) (.*) (.*)", "\\1 \\2", a$started_at), 
                                          format = "%Y-%m-%d %H:%M:%S", origin = "1970-01-01")
 
  a$X <- NULL
  a <- data.table(a)
  setkey(a, project_name,branch,build_id)
  gc()
  a
}

## Function to aggregate the build status of several jobs
aggregate.build.status <- function(statuslist) {
  if("errored" %in% statuslist) {
    return("errored")
  }
  if("failed" %in% statuslist) {
    return("failed")
  }
  return("passed")
}

## Function to compare the build status of several jobs
equal.build.status <- function(statuslist) {
  if(length(unique(statuslist)) == 1) {
    return(TRUE)
  }
  return(FALSE)
}
