require 'csv'
require 'travis'
require 'parallel'
require 'json'
require 'net/http'
require 'open-uri'

load 'lib/csv_helper.rb'

jobs = CSV.read(ARGV[0])

i = 1
length = jobs.length
header = jobs.shift
header.push 'tr_build_id'

def get_build_id job_id
   # used to be a simple Travis::Job.find(job_id).build_id job_id

  url = "https://api.travis-ci.org/jobs/#{job_id}"
  resp = open(url,
              'Content-Type' => 'application/json',
              'Accept' => 'application/vnd.travis-ci.2+json')
  json_resp = JSON.parse(resp.read)
  json_resp['job']['build_id']
end

jobs = Parallel.map(jobs, in_threads: 10) do |job|
  begin
    job_id = job[2]
    build_id = get_build_id job_id
    puts "#{i}/#{length}"
    job.push build_id
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
