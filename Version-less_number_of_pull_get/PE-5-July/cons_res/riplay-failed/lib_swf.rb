#
# Structs declaration
#
Job =  Struct.new(
:job_id, :submit_time, :wait_time, :run_time, :procs_alloc, :cpu_time_used, :used_memory, :procs_req, :run_time_req, :mem_req, 
    :status, :user_id, :group_id, :exe_num, :queue_id, :partition_id, :preceding_job_id, :preceding_job_think_time, :energy
)

# class Job_List < Array
# 	attr_accessor :stat, :bad_stat, :tracename, :start_time, :stop_time
# 	def initialize
#             @start_time = -1 
#             @stop_time = -1
# 	end
# 
# end

BadStat = Struct.new(:bad_jobs, :zero_time_jobs, :zero_procs_jobs, :non_1_status_jobs, :bad_data_jobs, :walltime_exceeded)
SwfStat = Struct.new(:nb_jobs,:start_time,:nb_procs,:nb_nodes,:timezone,:powercap_value,:powercap_resvs)


# rubyfication from parse_swf
# http://www.cs.huji.ac.il/labs/parallel/workload/swf.html
# the data format is one line per job, with 18 fields:
#  0 - Job Number
#  1 - Submit Time
#  2 - Wait Time
#  3 - Run Time
#  4 - Number of Processors
#  5 - Average CPU Time Used
#  6 - Used Memory
#  7 - Requested Number of Processors
#  8 - Requested Time
#  9 - Requested Memory
# 10 - status (1=completed, 0=killed)
# 11 - User ID
# 12 - Group ID
# 13 - Executable (Application) Number
# 14 - Queue Number
# 15 - Partition Number
# 16 - Preceding Job Number
# 17 - Think Time from Preceding Job
#

#To summarize, the status field codes are (or should be) as follows:
#0	Job Failed
#1	Job completed successfully
#2	This partial execution will be continued
#3	This is the last partial execution, job completed
#4	This is the last partial execution, job failed
#5	Job was cancelled (either before starting or during run)



#
# Functions
#
def load_swf_file(file_name, job_start, job_end)

	bad_stat = BadStat.new(0,0,0,0,0,0)
	stat = SwfStat.new
	#job_list = Job_List.new
        job_list = {}
        job_list["info"] = {}
	job_list["info"]["tracename"] = file_name	
        
        if !(File.exist?(file_name))
            return {}
        end
        
	file = File.new("#{file_name}", "r")
        
        $first_job_submission_time
        
	file.each do |line|
		if line =~ /^\s*$|^;/   
                        # HEADER
			# maintain data about log start time
			if  line =~ /^;\s*UnixStartTime:\s*(\d+)$/
                            stat.start_time = $1
			elsif line =~ /^;\s*TimeZoneString:\s*([\w\/]+)$/
                            stat.timezone = $1
			elsif line =~ /^;\s*MaxProcs:\s*(\d+)$/
				# and about system size
                            stat.nb_procs = $1
			elsif line =~ /^;\s*MaxNodes:\s*(\d+).*$/
                            stat.nb_nodes = $1
			elsif line =~ /^;\s*PowerCapResvs:\s*(.*)\s*$/
				tmp = $1.scan(/\((\d+),\s*(\d+),\s*(\d+)\s*\)/)
				stat.powercap_resvs = tmp
			elsif line =~ /^;\s*PowerCapValue:\s*(.*)\s*$/
				stat.powercap_value = $1
			end
		else                    
                        # JOBS INFO
			line =~ /^\s*(.*)\s*$/
			info_job = $1.split(/\s+/)
			job = Job.new
			info_job.each_with_index {|val,i| job[i]=val.to_i}
                        
                        # Update job_list properties
                        if !(job_list["info"].has_key?("start_time")) || (job_list["info"]["start_time"] > job.submit_time)
                                job_list["info"]["start_time"] = job.submit_time
                        end
                        if !(job_list["info"].has_key?("stop_time")) || job_list["info"]["stop_time"] < (job.submit_time.+job.wait_time+job.run_time)
                                job_list["info"]["stop_time"] = (job.submit_time+job.wait_time+job.run_time)
                        end
                        
                        bad = false
                        # Look for bad info	
     
                        if (job.submit_time == -1)||(job.run_time == -1)||(job.procs_alloc == -1) 
                                bad_stat.bad_data_jobs += 1
                                #job to exclude !!! 
                                bad = true
                        end

			if job.run_time == 0
				bad_stat.zero_time_jobs += 1
                                #bad = true
			end
			
			if (job.procs_alloc == 0) #|| (job.procs_req == 0)
				bad_stat.zero_procs_jobs += 1	
                                #bad = true
			end

                        if (job.procs_alloc != job.procs_req)    # set proc_req and proc_alloc to the same value if they differ. otherwise may cause troubles later in analyze
                                
                                job.procs_req = job.procs_alloc   # because in models proc_req is equal to -1
                                #job.procs_alloc = job.procs_req    
                                
                                #max = [job.procs_req, job.procs_alloc].max
                                #job.procs_req = job.procs_alloc = max
                                #bad = true
                        end

			if job.status != 1
				bad_stat.non_1_status_jobs += 1
                        end
			if (job.status.to_i == 0)  && (job.run_time > job.run_time_req)
				bad_stat.walltime_exceeded +=1	
                                #bad = true
			end
	
			bad_stat.bad_jobs +=1	if bad	

			if (!bad) 
                            if (job_start==nil && job_end==nil)
                               job_list[job.job_id] = job
                            elsif (job_start==nil && job_end!=nil && job.job_id <= job_end.to_i)
                                job_list[job.job_id] = job 
                            elsif(job_start!=nil && job_end==nil && job.job_id >= job_start.to_i) || (job_start!=nil && job_end!=nil && job.job_id <= job_end.to_i && job.job_id >= job_start.to_i)
                                if $first_job_submission_time==nil
                                    $first_job_submission_time = job.submit_time                                    
                                end    
                                job.submit_time = job.submit_time - $first_job_submission_time
                                job_list[job.job_id] = job 
                            end    
                        end    
		end
	end
	stat.nb_jobs= job_list.length
	job_list["info"]["stat"] = stat
	job_list["info"]["bad_stat"] = bad_stat

	return job_list
end


# convert date tool
def sec_to_hms(sec)
        return  "#{(sec / 3600)}:#{(sec % 3600) / 60}:#{sec % 60}"
end
