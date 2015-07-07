#!/usr/bin/ruby -w
#
# slurmdb2swf.rb
# from slurmdb to swf format
# swf format :
#   http://www.cs.huji.ac.il/labs/parallel/workload/swf.html
#
# KNOWN BUG:
# - PENDING jobs can be sorted in a wrong order
# - PENDING jobs exec names can be -1

require 'rubygems'
require "mysql2"
require 'date'

	begin
		# ---- OPTIONS BEGIN
		
		#if true, keep original slurm db ids
		showSlurmId=true
		
		#if true, add an extra row with the consumed energy
		saveEnergy=true
		
		#if true, get energy from the --comment="energy:VAL" instead of consumed_energy feild
		getEnergyFromComment=true
		
		#if true, the partition feild is set to the nodes used by this job
		saveNodesInPartition=false
		
		#if true, a header comment "nodesPowers" is added
		# each node or group of nodes have their max,idle,power,down values
		#Exemple:
		# ; nodesPowers: node1(100,70,,) node[2-100](110, 90,32,43)
		getNodesPowers=false
		
		#if true, get powercaps values
		#Exemple:
		#; PowerCapValue: 12000"
		#; PowerCapResvs: (5,0,7) (10,11,51)"
		#                 (start, duration, watt) ..."
		getPowerCap=false
		
		#if true, keep job names instead of anonymize them
		keepJobNames=true
		
		#Get the DVFS ("--cpu-freq") requested value for each job
		# WARNING: use the thinkTime row!
		getDVFS=false
		
		#Start getting the trace from this timestamp.
		# Exemple for the November 26th 13:00:42 2012:
		# startTraceFrom=DateTime.new(2012, 11, 26, 12, 00, 42).strftime('%s')
		startTraceFrom=0
		startTraceFrom=ARGV[0]
		
		#End getting the trace at this timestamp
		# if=0, now
		endTraceTo=0
		
		# This variable should give the maximum that a job can wait in the system
		# this option allow the script to make optimizations (useful on very big databases!)
		maxWaitTime = 3600*24*30
		
		# this option make the script don't wait for the end of the mysql request
		# to work on data
		# WARNING: can't be activated when getPowerCap is true
		activateStream=false
		
		# mysql styff
		slurmDbPrefix = "hdf"
# 		slurmDbPrefix = "cluster"
		#                           host       user    pass    database
		dbh = Mysql2::Client.new(:host=>"localhost", :username =>"root", :password =>"", :database=>"slurmDB")
# 		dbh = Mysql2::Client.new(:host=>"localhost", :username =>"root", :password =>"root", :database=>"slurmAc")
		
		
		# ---- OPTIONS END
		
		
		if( activateStream && getPowerCap )
			puts "you CAN'T have activateStream and getPowerCap both set to true!"
			exit 1
		end
		
		dbh.query_options.merge!(:cast=> false, :cache_rows => false, :stream => activateStream)
		
		
		pendingJobs = Hash.new
		if(endTraceTo==0)
			#get pending jobs
			cmdLine = `scontrol -d -o show job | grep PENDING`
	# 		cmdLine = `cat slurmPENDING | grep PENDING`
			cmdLine.split("\n").each {
				|val|
				job = val.split(' ')
				tempArray = Hash.new
				job.each {
					|jjj|
					t = jjj.split('=')
					tempArray[t[0]] = t[1]
				}
				pendingJobs[tempArray["JobId"]] = tempArray
			}
		else
			pendingJobs = {}
		end
		
		entracetxt = ""
		if(endTraceTo != 0)
			entracetxt = "WHERE time_submit <= "+endTraceTo.to_s
		end
		res = dbh.query("SELECT time_end FROM `"+slurmDbPrefix+"_job_table` "+entracetxt+" ORDER BY time_end DESC LIMIT 1")
		unixEndTime = 0
		res.each do |row|
			unixEndTime = row["time_end"].to_i
		end
		if(unixEndTime == 0)
			puts "ERROR: This code can't work if no job have ended yet."
			exit()
		end
		if( endTraceTo == 0)
			endTraceTo = unixEndTime
		end
		
		if saveEnergy
			puts "; Version: 2.2 with an EXTRA ROW \"consumed_energy\""
		else
			puts "; Version: 2.2"
		end
		puts "; Computer: "+`uname -a`
# 		puts "; Installation: somewhere"
		puts "; Acknowledge: david.glesser@imag.fr"
# 		puts "; Information: nop"
# 		puts "; Note: dumb infos"
		puts "; Conversion: slurmdb2swf.rb"
		puts "; Preemption: No"
		if getDVFS
			puts "; Information: WARNING! Think Time row is the requested DVFS !"
		end
		
		if getNodesPowers
			#read powercap values from the config file
			conf_dir = ENV['SLURM_CONF']
			if conf_dir == nil
				conf_dir = "/etc/slurm.conf"
				if not File.exist?(conf_dir)
					conf_dir = "/etc/slurm/slurm.conf"
				end
			end
			text = ""
			if not File.exist?(conf_dir)
				text = "ERROR: Configuration file (#{conf_dir}) not found."
			else
				cmd = `cat #{conf_dir} | grep NodeName=`
				cmd.split("\n").each do |line|
					if !line.match(/.*(#).*/)
						opts = {}
						opts_r = line.scan(/\s*(\w+)=([\w\[\]\-_\.,]+)\s*/)
						opts_r.each do |opt|
							opts[opt[0]] = opt[1]
						end
						text += opts["NodeName"].to_s+"("+
								opts["PowerCapMaxWatts"].to_s+","+
								opts["PowerCapIdleWatts"].to_s+","+
								opts["PowerCapPowerSaveWatts"].to_s+","+
								opts["PowerCapDownWatts"].to_s+") "
					end
				end

			end
			puts "; nodesPowers: "+text
		end
		
		
		if not keepJobNames
			#get all the different executable names
			#we only need an id of these exectuables, not the full name
			res = dbh.query("SELECT job_name FROM `"+slurmDbPrefix+"_job_table` WHERE time_submit <= "+endTraceTo.to_s+" AND time_submit >= "+startTraceFrom.to_s+" GROUP BY job_name")
			i = 0
			executables = Hash.new
			res.each do |row|
				executables[row["job_name"]] = i
				i += 1
			end
		end
		
		#get all the different partition names
		#we only need an id of these partiotions, not the full name
		res = dbh.query("SELECT partition FROM "+slurmDbPrefix+"_job_table WHERE time_submit <= "+endTraceTo.to_s+" AND time_submit >= "+startTraceFrom.to_s+" GROUP BY partition")
		i = 0
		partitions = Hash.new
		res.each do |row|
			partitions[row["partition"]] = i
			i += 1
		end
		
		
		# TODO: it's possible to have several step for one job, take this correctly into account
		res = dbh.query("
			SELECT *
			FROM "+slurmDbPrefix+"_job_table AS job
			LEFT OUTER JOIN (
				SELECT job_db_inx, max(id_step) as id_step, ave_vsize, consumed_energy, sys_sec, user_sec, max(req_cpufreq) as req_cpufreq
				FROM "+slurmDbPrefix+"_step_table
				WHERE time_start >= "+ (startTraceFrom).to_s+
				" AND time_start <= "+(endTraceTo.to_i+maxWaitTime.to_i).to_s+"
				GROUP BY job_db_inx
			) AS step ON job.job_db_inx = step.job_db_inx
			WHERE time_submit <= "+endTraceTo.to_s+" AND time_submit >= "+startTraceFrom.to_s+" 
			ORDER BY job.time_submit ASC");
		
		unixStartTime = 0
		jobNumber=1
		
		res.each do |row|
			if jobNumber == 1
# 				puts "; TimeZoneString: US/Eastern"
				puts "; ScriptStartTime: "+startTraceFrom.to_s+" ("+Time.at(startTraceFrom.to_i).to_s+")"
				puts "; UnixStartTime: "+row["time_submit"].to_s
				unixStartTime=row["time_submit"].to_i
				puts "; StartTime: "+Time.at(unixStartTime.to_i).to_s
				puts "; EndTime: "+Time.at(unixEndTime).to_s
				#puts "; MaxJobs: "+(res.num_rows + pendingJobs.length).to_s
				#puts "; MaxRecords: "+(res.num_rows + pendingJobs.length).to_s
				#puts "; MaxNodes: -1" TODO
				#puts "; MaxProcs: -1" TODO
				#puts "; MaxQueues: -1" TODO
				#puts "; Queue:  -1"  TODO
				puts "; Partitions: "+partitions.to_s
				
				if getPowerCap
					powerCapValue = ""
					cmd = `scontrol show powercap`.scan(/PowerCap=([0-9]+|INFINITE) /)
					if cmd.length <= 0 || cmd[0].length <= 0
						powerCapValue = cmd
					else
						powerCapValue = cmd[0][0]
					end
					puts "; PowerCapValue: "+powerCapValue.to_s
					
					powerCapResvs = ""
					res2 = dbh.query("SELECT time_start, time_end, resv_name FROM `"+slurmDbPrefix+"_resv_table`")
# 					                 WHERE (time_end <= "+endTraceTo.to_s+"
# 					                 AND time_end >= "+startTraceFrom.to_s+" )
# 					                OR (
# 					                 time_start <= "+endTraceTo.to_s+"
# 					                 AND time_start >= "+startTraceFrom.to_s+" )"
					res2.each do |row2|
						powerCapResvs += "("+ ( row2["time_start"].to_i - unixStartTime).to_s
						powerCapResvs += "," + ( row2["time_end"].to_i - row2["time_start"].to_i).to_s
						powerCapResvs += ","+row2["resv_name"]+") "
					end
					puts "; PowerCapResvs: "+ powerCapResvs
				end
				
				puts ";"
			end
# 			puts row
			
			#some pending jobs are in the db, others not.
			if( not pendingJobs[row["id_job"]].nil?)
				pendingJobs.delete(row["id_job"])
			end
				
			#2. Submit Time -- in seconds. The earliest time the log refers to is zero, and is the submittal time the of the first job. The lines in the log are sorted by ascending submittal times. It makes sense for jobs to also be numbered in this order.
			submitTime = (row["time_submit"].to_i-unixStartTime)
			
			# Status 1 if the job was completed, 0 if it failed, and 5 if cancelled. If information about chekcpointing or swapping is included, other values are also possible. See usage note below. This field is meaningless for models, so would be -1.
			status = 1
			if row["exit_code"].to_i != 0
				status = 0
			end
			if (row["deleted"].to_i != 0) or (row["kill_requid"].to_i != -1)
				status = 5
			end
			#state doc: http://comments.gmane.org/gmane.comp.distributed.slurm.devel/2804
			if (row["state"].to_i == 4)
				status = 5
			end
			if (row["state"].to_i == 5 or row["state"].to_i == 7)
				status = 0
			end
			
			
			if (row["ave_vsize"]== nil) or (row["ave_vsize"] == '')
				row["ave_vsize"] = -1
			end
			
			
			#1. Job Number -- a counter field, starting from 1.
			if(showSlurmId)
				jobId=row["id_job"]
			else
				jobId=jobNumber
			end
			
			#3. Wait Time -- in seconds. The difference between the job's submit time and the time at which it actually began to run. Naturally, this is only relevant to real logs, not to models.
			if(row["time_start"].to_i == 0 or row["state"].to_i == 0)
				waitTime = -1
			else
				waitTime = (row["time_start"].to_i-row["time_submit"].to_i)
			end
			
			#4. Run Time -- in seconds. The wall clock time the job was running (end time minus start time).
			runTime=(row["time_end"].to_i-row["time_start"].to_i)
			if( runTime < 0)
			  runTime=-1
			end
			if(row["state"].to_i == 1 or row["state"].to_i == 0) # if still running or in queue
				runTime = -1 #(unixEndTime-unixStartTime-submitTime-waitTime)
			end
			
			if saveEnergy
				if getEnergyFromComment
					# comments are stored in derived_es
					if row["derived_es"] == nil
						energy_str = 0
					else
						temp = row["derived_es"].split(":")
						if temp[0] == "energy"
							energy_str = temp[1]
						else
							energy_str = 0
						end
					end
				else
					energy_str = row["consumed_energy"]
				end
			else
				energy_str = ""
			end
			
			partition = ""
			if saveNodesInPartition
				partition = row["nodelist"]
			else
				partition = partitions[row["partition"]].to_s
			end
			
			#9. Requested Time. This can be either runtime (measured in wallclock seconds), or average CPU time per processor (also in seconds) -- the exact meaning is determined by a header comment. In many logs this field is used for the user runtime estimate (or upper bound) used in backfilling. If a log contains a request for total CPU time, it is divided by the number of requested processors.
			timelimit = row["timelimit"].to_i * 60 #slurm timelimit is in minutes
			
			
			#14. Executable (Application) Number -- a natural number, between one and the number of different applications appearing in the workload. in some logs, this might represent a script file used to run jobs rather than the executable directly; this should be noted in a header comment.
			if keepJobNames
				execName=row["job_name"].gsub(/\s+/, "")
			else
				execName=executables[row["job_name"]]
			end
			
			
			#18. TODO? Think Time from Preceding Job -- this is the number of seconds that should elapse between the termination of the preceding job and the submittal of this one. 
			thinkTime = -1
			if getDVFS
				thinkTime=row["req_cpufreq"]
				if thinkTime == nil
					thinkTime = 0
				end
			end
			
			
			printf "%1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s\n",
					jobId.to_s,#1.
					submitTime.to_s,#2.
					waitTime.to_s,#3.
					runTime.to_s,#4.
					row["cpus_alloc"].to_s,#5. Number of Allocated Processors -- an integer. In most cases this is also the number of processors the job uses; if the job does not use all of them, we typically don't know about it.
					(row["user_sec"].to_i+row["sys_sec"].to_i).to_s,# VERIFIY! 6. Average CPU Time Used -- both user and system, in seconds. This is the average over all processors of the CPU time used, and may therefore be smaller than the wall clock runtime. If a log contains the total CPU time used by all the processors, it is divided by the number of allocated processors to derive the average.
					row["ave_vsize"].to_s,#7. Used Memory -- in kilobytes. This is again the average per processor.
					row["cpus_req"].to_s,#8. Requested Number of Processors.
					timelimit.to_s,#9.
					-1.to_s,#10. Requested Memory (again kilobytes per processor).
					status.to_s,#11.
					row["id_user"].to_s,# TODO:ANONYMIZE !! 12. User ID -- a natural number, between one and the number of different users.
					row["id_group"].to_s,# TODO:ANONYMIZE !! 13. Group ID -- a natural number, between one and the number of different groups. Some systems control resource usage by groups rather than by individual users.
					execName.to_s,#14.
					-1.to_s,# TODO? 15. Queue Number -- a natural number, between one and the number of different queues in the system. The nature of the system's queues should be explained in a header comment. This field is where batch and interactive jobs should be differentiated: we suggest the convention of denoting interactive jobs by 0.
					partition,#16. Partition Number -- a natural number, between one and the number of different partitions in the systems. The nature of the system's partitions should be explained in a header comment. For example, it is possible to use partition numbers to identify which machine in a cluster was used.
					-1.to_s,#17. TODO? Preceding Job Number -- this is the number of a previous job in the workload, such that the current job can only start after the termination of this preceding job. Together with the next field, this allows the workload to include feedback as described below.
					thinkTime.to_s,#18.
					energy_str
			jobNumber += 1
			
			
		end
		
		
		
		
		
		
		pendingJobs.each {
			|jobf|
			job = jobf[1]
		
			if (job.nil?)
				next
			end
		
			if(showSlurmId)
				jobId=job["JobId"]
			else
				jobId=jobNumber
			end
		
			subTime=DateTime.strptime(job["SubmitTime"], '%Y-%m-%dT%H:%M:%S').strftime("%s").to_i
		
			if keepJobNames
				execName=job["Name"].gsub(/\s+/, "")
			else
				execName=executables[job["Name"]]
			end
			
			if(execName == nil)
				execName = -1
			end
			partit=partitions[job["Partition"]]
			if(partit == nil)
				partit = -1
			end
		
		timelimit=job["TimeLimit"]
		if(timelimit == "UNLIMITED")
			timelimit=4294967295
		else
		# 		Acceptable time formats include "minutes", "minutes:sec‐
		# 		onds", "hours:minutes:seconds", "days-hours", "days-hours:minutes"
		# 		and "days-hours:minutes:seconds".
		end
		
		if job["MinMemoryNode"] == nil
			minMemoryNode = -1
		end
		
		printf "%1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s %1s\n",
				jobId,
				(subTime.to_i-unixStartTime).to_s,
				-1,
				-1,
				-1,
				-1,
				-1,#7.
				job["NumCPUs"], # TODO: *job["NumNodes=1"] ?
				-1, # TODO: timelimit,
				minMemoryNode,
				-1,#11.
				job["UserId"].split('(')[1].split(')')[0],
				job["GroupId"].split('(')[1].split(')')[0],
				execName,
				-1,
				partit,
				-1,
				-1
		
		
			jobNumber += 1
		}
		
		
		
		# disconnect from server
		dbh.close if dbh
	end
