#
# (c) 2012 -- 2015 Georgios Gousios <gousiosg@gmail.com>
#
# MIT licensed -- see top level dir

parallel=1
dir='.'

usage()
{
  echo ""
	echo "Usage: $0 [-p num_processes] [-d output_dir] file"
  echo "Runs build_data_extraction for an input file using multiple processes"
  echo "Options:"
  echo "  -p Number of processes to run in parallel (default: $parallel)"
  echo "  -d Output directory (default: $dir)"
  exit 1
}

while getopts "p:d:a:" o
do
	case $o in
	p)
    parallel=$OPTARG ;
    echo "Using $parallel processes";
    ;;
  d)
    dir=$OPTARG ;
    echo "Using $dir for output";
    ;;
  a)
    ip=$OPTARG ;
    echo "Using $ip for requests";
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2 ;
    usage
    ;;
  :)
    echo "Option -$OPTARG requires an argument." >&2
    exit 1
    ;;
	esac
done

# Process remaining arguments after getopts as per:
# http://stackoverflow.com/questions/11742996/shell-script-is-mixing-getopts-with-positional-parameters-possible
if [ -z ${@:$OPTIND:1} ]; then
  usage
else
  input=${@:$OPTIND:1}
fi

mkdir -p $dir

cat $input |
grep -v "^#"|
while read pr; do
  name=`echo $pr|cut -f1,2 -d' '|tr ' ' '@'`
  echo "ruby -Ibin bin/build_data_extraction.rb -c config.yaml $pr |grep -v '^[DUG]' |grep -v Overrid | grep -v 'unknown\ header'|grep -v '^$' 1>$dir/$name.csv 2>$dir/$name.err"
done | xargs -P $parallel -Istr sh -c str

