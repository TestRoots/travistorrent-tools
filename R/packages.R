#
# (c) 2015 - onwards Georgios Gousios <gousiosg@gmail.com>
# (c) 2015 - onwards Moritz Beller <moritzbeller@gmail.com>
#
# MIT Licensed, see LICENSE in top level dir
#

if (!"data.table" %in% installed.packages()) install.packages("data.table")
if (!"ggplot2" %in% installed.packages()) install.packages("ggplot2")
if (!"foreach" %in% installed.packages()) install.packages("foreach")
if (!"doMC" %in% installed.packages()) install.packages("doMC")
if (!"rminer" %in% installed.packages()) install.packages("rminer")
if (!"gdata" %in% installed.packages()) install.packages("gdata")
if (!"ggthemes" %in% installed.packages()) install.packages("ggthemes")
if (! "effsize" %in% installed.packages()) install.packages("effsize")

if (! "devtools" %in% installed.packages()) install.packages("devtools")
library(devtools)
if (!"cliffsd" %in% installed.packages()) install_github("cliffs.d", "gousiosg")
