#!/bin/bash
cd ..

dir=`pwd`

ls $dir/build_logs | parallel -j 20 ruby bin/buildlog_analysis.rb -d "$dir/build_logs/{}" -v