#!/bin/bash
cd ..

dir=`pwd`

ls $dir/buildlogs | parallel -j 20 ruby bin/buildlog_analysis.rb -d "$dir/buildlogs/{}" -v