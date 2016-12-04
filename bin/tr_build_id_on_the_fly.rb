require 'csv'
require 'travis'
require 'parallel'

begin
  line = CSV.parse(ARGV[0])
  job_id = line[0][2]
  line[0].push Travis::Job.find(job_id).build_id
  STDOUT.puts line[0].to_csv
rescue Exception => e
  STDERR.puts "Exception at #{line}"
  STDERR.puts e
rescue Error => e
  STDERR.puts "Error at #{line}"
  STDERR.puts e
end
