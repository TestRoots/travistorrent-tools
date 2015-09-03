#
# (c) 2015 - onwards Georgios Gousios <gousiosg@gmail.com>
# (c) 2015 - onwards Moritz Beller <moritzbeller@gmail.com>
#
# MIT Licensed, see LICENSE in top level dir
#
require(ggplot2)
require(rminer)
require(plyr)

#rm(list = ls(all = TRUE))

source('R/config.R')
source('R/utils.R')

data <- read.csv('whether-projects-use-travis.prepared.csv', check.names = T,  quote='"')

# Result:
summary(data$active_years)

# Result:
printf("Number of projects: %i", nrow(data))
printf("Number of different languages: %i", length(unique(data$language)))
printf("Number of projects using Travis: %i (%f)", nrow(data[data$num_travis_builds > 0,]), nrow(data[data$num_travis_builds > 0,])/nrow(data))

languages <- c(
  "JavaScript",
  "Java",
  "Python",
  "PHP",
  "Ruby",
  "C++",
  "C",
  "C#",
  "Objective-C",
  "R",
  "Go",
  "Perl",
  "Scala",
  "Haskell",
  "Clojure",
  "Groovy",
  "Rust"
)

data.supported.by.travis <- data[data$language %in% languages,]
printf("Number of projects which can use Travis: %i (%f)", nrow(data.supported.by.travis), nrow(data.supported.by.travis)/nrow(data))
printf("Number of projects using Travis which can use Travis: %i (%f)", nrow(data.supported.by.travis[data.supported.by.travis$num_travis_builds > 0,]), nrow(data[data$num_travis_builds > 0,])/nrow(data.supported.by.travis))

other.languages <- c(setdiff(levels(data$language), languages))
data$language <- delevels(data$language, other.languages, "Other")
lang.count <- count(data$language)
ordered.factors <- lang.count[order(-lang.count$freq),]$x
data$language <- factor(data$language, levels=ordered.factors)

qplot(factor(language), data=data, geom="bar", fill=factor(uses.travis)) +
       labs(x = "Main Repository Language", y = "#Projects", fill="") + coord_flip(ylim = c(0,16540)) + 
  ggplot.small.defaults + theme(legend.position="bottom")  +
  scale_y_continuous(labels=comma)
save.plot("rq1_travisci_adoption_per_language.pdf")

# Result
printf("Number of builds in total: %i", sum(data$num_travis_builds))

data.only.builds <- subset(data, uses.travis.bin == T)

# Number of builds per language
ggplot(data.only.builds, aes(x=language, y=num_travis_builds, fill=language)) + geom_boxplot()+ #outlier.colour=NA) + 
  guides(fill=FALSE) + stat_summary(fun.y=mean, geom="point", shape=10, size=4) + ggplot.small.defaults + coord_flip(ylim = c(0, 1550)) +
  labs(x = "Main Repository Language", y = "#Travis Builds/Project", fill="") +
  scale_y_continuous(labels=comma)

save.plot("rq1_travisci_builds_per_language.pdf")
