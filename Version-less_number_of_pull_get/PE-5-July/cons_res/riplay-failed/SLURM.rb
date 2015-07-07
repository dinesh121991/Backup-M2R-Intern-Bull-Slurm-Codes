#!/usr/bin/ruby
 
require 'pp'
require "./lib_swf.rb"
require "./JOB.rb"

def sbatch(job, type, output_dir, schedule_now, use_users, use_energy)
    job_id = job.job_id
    construct_script_slurm(job, type, output_dir, use_users, use_energy)
    command = "sbatch"
    if(!schedule_now)
       command = "#{command} --hold" 
    end
    command = "#{command} #{output_dir}/#{job_id}.slurm.job"
    puts "# bash -c '#{command}'"
    print `bash -c '#{command}'`
end

def slurmresume(jobs)
    running_jobs = `squeue -a | awk -F " "  '{print $1}' | grep -v 'JOBID'`
    dodo = 0
    running_jobs.each do |job_id|
        command = "scontrol release #{job_id}"   # TODO: here we release all the jobs, need to do it properly
        puts "# bash -c '#{command}'"
	print `bash -c '#{command}'`
        dodo = dodo + 1
        if(dodo == 20)
            dodo = 0
            sleep(0.01)
        end
    end
end


def construct_script_slurm(job, type, output_dir, use_users, use_energy)
    if(job.run_time_req == -1) 
       job.run_time_req = 3600 
    end    
    walltime = sec_to_hms(job.run_time_req)
    #nb_procs = job.procs_req # use procs_alloc instead of proc_req as this field is sometimes empty in models (lublin) or in slurm
    nb_procs = job.procs_alloc
    duration = job.run_time
    job_id = job.job_id

    puts "# create sbatch file #{job_id} walltime: #{walltime} nbprocs: #{nb_procs}"
    
    File.open("#{output_dir}/#{job_id}.slurm.job", 'w') do |f|
        f.puts "#\!/bin/sh"
        f.puts "#SBATCH -J riplay_#{job_id}_#{type}"
	f.puts "#SBATCH -n #{nb_procs}"
        f.puts "#SBATCH -t #{walltime}"
        f.puts "#SBATCH -o #{output_dir}/riplay_slurm_#{type}_#{job_id}.out"

	if use_users
		user_id = job.user_id
		if(user_id == 3)
			f.puts "#SBATCH --uid=50108"
			freq = 2394000
		elsif(user_id == 1)
			f.puts "#SBATCH --uid=50241"
			freq = 2527000
		elsif(user_id == 2)
			f.puts "#SBATCH --uid=50243"
			freq = 1729000
		end
	end
	if use_energy
		energy = job.energy
		f.puts "#SBATCH --comment=\"energy:#{energy}\"" 
	end

        f.puts ""
        #f.puts "srun --acctg-freq=energy=1 --exclusive --cpu-freq=#{freq} #{get_job_code(job, type, output_dir, 'SLURM', use_users)}"
	f.puts "srun #{get_job_code(job, type, output_dir, 'SLURM', use_users)}"
        f.puts "sleep 1"
        f.puts "exit 0"
        f.puts ""  

    end
    `chmod 777 #{output_dir}/#{job_id}.slurm.job`
end


def slurmmake_energy_resv(time, duration, watts)
	d = (duration.to_i/60).to_i
	command = "scontrol create res FLAG=LICENSE_ONLY starttime=now+#{time} duration=#{d} Watts=#{watts} Users=root"
	puts "# bash -c '#{command}'"
	print `bash -c '#{command}'`
end
