require 'csv'
require 'travis'
require 'parallel'

load 'lib/csv_helper.rb'

jobs = CSV.read(ARGV[0])

i = 1
length = jobs.length
header = jobs.shift
header.push 'tr_build_id'

jobs = Parallel.map(jobs, in_threads: 2) do |job|
  begin
    job_id = job[2]
    job.push Travis::Job.find(job_id).build_id

    puts "#{i}/#{length}"
    job
  rescue Exception => e
    STDERR.puts "Exception at #{i}"
    STDERR.puts e
  rescue Error => e
    STDERR.puts "Error at #{i}"
    STDERR.puts e
  ensure
    i += 1
  end
end

jobs = jobs.select { |a| !a.nil? }

CSV.open("n_#{ARGV[0]}", 'w',
         :write_headers => true,
         :headers => header
) do |hdr|
  jobs.each do |job|
    hdr << job
  end
end
