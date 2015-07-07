#!/usr/bin/ruby
 
require 'pp'
require "./lib_swf.rb"
require "./JOB.rb"

def oarsub(job, type, output_dir, schedule_now)
    job_id = job.job_id
    construct_script_oar(job, type, output_dir)
    command = "oarsub -S #{output_dir}/#{job_id}.oar.job"
    if(!schedule_now)
       command = "#{command} --hold" 
    end    
    print `bash -c '#{command}'`
end

def oarresume(jobs)
    running_jobs = `oarstat -u \`whoami\` | awk -F " "  '{print $1}' | grep -v Job | grep -v '-'`.gsub("\n", " ")   
# TODO: here we release all the jobs, need to do it properly
    command = "oarresume #{running_jobs}" 
    #command = "oarresume --sql 'true'"
    print `bash -c '#{command}'`  
end

def construct_script_oar(job, type, output_dir)
    if(job.run_time_req == -1) 
       job.run_time_req = 3600 
    end  
    walltime = sec_to_hms(job.run_time_req)
    #nb_procs = job.procs_req # use procs_alloc instead of proc_req as this field is sometimes empty in models (lublin) or in slurm
    nb_procs = job.procs_alloc
    duration = job.run_time
    job_id = job.job_id

    File.open("#{output_dir}/#{job_id}.oar.job", 'w') do |f|
	f.puts "#\!/bin/sh"
	f.puts "#OAR -n riplay_#{job_id}_#{type}"
        #f.puts "#OAR -p \"type = 'default'\""
	f.puts "#OAR -l core=#{nb_procs},walltime=#{walltime}"
        f.puts "#OAR -q ocaml"
	f.puts "#OAR --stdout #{output_dir}/riplay_oar_#{type}_#{job_id}.out"
	f.puts "#OAR --stderr #{output_dir}/riplay_oar_#{type}_#{job_id}.err"
	f.puts ""
	f.puts "#{get_job_code(job, type, output_dir, 'OAR', false)}"
	f.puts ""
	f.puts "exit 0"
	f.puts ""  

    end
    `chmod 777 #{output_dir}/#{job_id}.oar.job`
end

def oarmake_energy_resv(time, duration, watts)
	puts "WARNING: PowerCap not implemented yet!"
end
