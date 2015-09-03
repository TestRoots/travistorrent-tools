# converts factor to their numeric value
as.numeric.factor <- function(x) {as.numeric(levels(x))[x]}

# Prepares CSV for further data analysis
data <- read.csv('whether-projects-use-travis.csv', check.names = T,  quote='"')
data$uses.travis <- 'Does Not Use Travis'
data[data$num_travis_builds > 0,]$uses.travis <- 'Uses Travis (<= 50 builds)'
data[data$num_travis_builds > 50,]$uses.travis <- 'Uses Travis (> 50 builds)'
data$uses.travis.bin <- data$num_travis_builds > 0

# Data cleaning: Corrects active project years. No software project can be older than 100 years!
data$active_years <- as.numeric.factor(data$active_years)
data[!is.na(data$active_years) & data$active_years > 100,]$active_years  <- NA

write.csv(data, 'whether-projects-use-travis.prepared.csv', row.names = F)