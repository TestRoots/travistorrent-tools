#!/bin/bash
cd ..
printf "If you have difficult to execute this script, please, read this link: http://ghtorrent.org/mysql.html\n\n"
dir=`pwd`

printf "Connecting to GHTorrent and executing a query to extract main Java projects from GitHub...\n"
mysql -u ght -h 127.0.0.1 ghtorrent < $dir/examples/java_projects.sql | sed 's/\t/;/g' > $dir/java_projects.txt

printf "Java projects collected! Running travis_poker to collect projects that has a Travis build history ...\n"
# ruby -Ibin bin/travis_poker.rb -s DSpace/DSpace -t 2013-07-25

