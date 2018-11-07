#!/bin/bash
cd ..
printf "If you have difficult to execute this script, please, read this link: http://ghtorrent.org/mysql.html\n\n"
dir=`pwd`

printf "Connecting to GHTorrent and executing a query to extract main Java projects from GitHub...\n"
mysql -u ght -h 127.0.0.1 ghtorrent < $dir/examples/java_projects.sql | sed 's/\t/;/g' > $dir/gh-active-java-projects.csv

printf "Java projects collected!\n"