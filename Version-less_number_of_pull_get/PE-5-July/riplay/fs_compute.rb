
#fairsharing compute !
# compute fs values from a swf file
#QOS must be disabled
# assumption: the compute time is less than a minute


require "lib_swf.rb"

########################################################

#slurm.conf options:
# dont touch this one:
$slurm_get_priority_calc_period = 5*60

$slurm_get_priority_decay_hl  = 7*24*3600

#not implemented:
$slurm_get_priority_reset_period  = 'useless'


#input file
$SWF_FILE = 'curie_CLEANED.swf'
# print debug infos
$print_debug = false
# print steps infos (which step is executed)
$print_steps = true
#print in sshare format or a parsable format
$print_sshare = false

#super jump allow to jump over useless __decay_thread loops and BOOST A LOT the code
#in introduce SMALL changes in some results
$do_super_jump = true

#start to read the swf starting from $start_at
$start_at = 52510885-1209600

#this tool print sshare at 0 and at the end of the swf.
#if you want more prints, add the time in the following array
#these times can be higher than the end of the swf (the computation continue)
$list_of_print_time = [0, 52510885-1209600, 52510885, 52510885+60]


########################################################

#sanitize $list_of_print_time
$list_of_print_time.sort!
$list_of_print_time.map! do |t|
	if t - $start_at < 0
		$start_at
# 	t = t - $start_at
# 	if t < 0
# 		0
	else
		t
	end
end
$list_of_print_time.uniq!


#dafuq ?
SLURMDB_FS_USE_PARENT = 42


$SLURM_SUCCESS = 0
$SLURM_ERROR = 1


def IS_JOB_PENDING(a)
	return false
end


def debug(format, *arg)
        if $print_debug
                printf(format,*arg)
        end
end
def print_steps(a)
        if $print_steps
               puts a
        end
end


#emulation of slurmdb_association_rec_t
#
# root = Slurmdb_association_rec_t.new('root', nil)
# root.children << Slurmdb_association_rec_t.new('assoc1', root)
# root.children << Slurmdb_association_rec_t.new('assoc2', root)
# puts root.to_s_children()
# root.each {|x| print x }
class Slurmdb_association_rec_t
    
    attr_accessor :name, :children
    attr_accessor :parent_assoc_ptr #parent in the tree
    attr_accessor :usage_usage_raw, :usage_usage_norm, :usage_usage_efctv
    attr_accessor :usage_usage_energy_raw, :usage_usage_energy_norm, :usage_usage_energy_efctv
    attr_accessor :user, :acct, :grp_used_wall, :level_shares, :shares_raw
    
    def initialize(name, parent, children=[])
    	@name = name
    	@children = children
	@parent_assoc_ptr = parent
	
	
	@usage_usage_efctv = 0.0;
	@usage_usage_norm = 0.0#nil #NO_VAL;
	@usage_usage_raw = 0.0;
	
	@usage_usage_energy_efctv = 0.0;
	@usage_usage_energy_norm = 0.0#nil #NO_VAL;
	@usage_usage_energy_raw = 0.0;
	
# 	@usage_level_shares = nil #NO_VAL;
# 	@usage_shares_norm = nil #NO_VAL;
	
	@user = 'fooUser' #/* user associated to association */
	@acct = 'fooAssoc' #/* account/project associated to association */
# 	@grp_used_wall = 0 # dafuq ? useless
	@level_shares = SLURMDB_FS_USE_PARENT # dafuq ?
	@shares_raw = 1.0 # /* number of shares allocated to association */
	
    end
    
    def to_s_me()
	    if(@parent_assoc_ptr == nil)
		value_s = @name.to_s + "(p:nil"
                else
		value_s = @name.to_s + "(p:"+@parent_assoc_ptr.to_s
	    end
            value_s += ", sr:"+ @shares_raw.to_s
            value_s += ", ue:"+ @usage_usage_efctv.to_s
            value_s += ", un:"+@usage_usage_norm.to_s 
            value_s += ", ur:"+ "%u"%@usage_usage_raw
            value_s += ")"
            return value_s
    end
    
    def to_s()
	    return @name.to_s
    end
    
    def to_s_myline(indent=0)
            print ' ' * indent
            print @name.to_s
            print ' ' * (20 +12 - indent - @name.to_s.length)
            print ' ' * (10 - @shares_raw.to_s.length)
            print @shares_raw.to_s
            print ' '
            print ' ' * (11 - 2) #Norm Shares
            print 42
            print ' '
            s = '%u'%@usage_usage_raw
            print ' ' * (11 - s.length)
            print s
            print ' '
            print ' ' * (13 - @usage_usage_efctv.to_s.length)
            print @usage_usage_efctv.to_s
            print ' '
            print ' ' * (10 - 2) #FairShare
            print 42
            print ' '
            print ' ' * (14 - @usage_usage_energy_raw.to_s.length)
            print @usage_usage_energy_raw.to_s
            print ' '
            print ' ' * (16 - @usage_usage_energy_efctv.to_s.length)
            print @usage_usage_energy_efctv.to_s
            print ' '
            print ' ' * (13 - 2) #FairShare
            print 42
            puts ""
            return ''
    end
    
    def print_sshare(indent=0)
            if indent == 0
                    puts "             Account       User Raw Shares Norm Shares   Raw Usage Effectv Usage  FairShare   Raw E. Usage Effectv E. Usage  FairShare E." 
                    puts "-------------------- ---------- ---------- ----------- ----------- ------------- ---------- -------------- ---------------- -------------"
            end
            to_s_myline(indent)
        @children.map { |child| child.print_sshare(indent + 1) }
    end
    
    def print_parsable()
            print @name.to_s
            print ','
            print @usage_usage_raw.to_s
            print ','
            print @usage_usage_energy_raw.to_s
            print "\n"
	    @children.map { |child| child.print_parsable() }
    end
    
    def print_parsable_or_sshare()
	    if $print_sshare
		    print_sshare()
	    else
		    print_parsable()
	    end
    end
    
    def to_s_children(indent=0)
        value_s = self.to_s_me()
        sub_indent = indent + value_s.length
        return value_s +"\n"+ (' ' * sub_indent)+ @children.map { |child| " - " + child.to_s_children(sub_indent + 3) }.join("\n" + ' ' * sub_indent)
    end
    
    def create_list_from_me(put_me_in_list=true)
	    a = []
	    if(put_me_in_list)
		    a << self
	    end
	    a.concat(Array.new(@children))
	    @children.map { |child| a.concat(child.create_list_from_me(false))}
	    return a
    end
end


def list_iterator_create_assoc_mgr_association_list()
	return $assoc_mgr_root_assoc.create_list_from_me()
end








print_steps("++++++++++++++++++++++++++++++ INIT assocs and JOB")

#contain the jobs actually running
#(in slurm it's not exactly the case : 
#it's he jobs that are running + some old job that have not been already flushed)
$job_list = []

JobShort =  Struct.new(:job_id, :start_time, :end_time, :run_time, :total_cpus, :consumed_energy, :assoc_ptr)
print_steps("++++++++++++++++++++++++++++++ load SWF")
jobs = load_swf_file($SWF_FILE, nil, nil)
jobs.delete("info")
$jobs_to_be_ran = []
assocs = Hash.new
$assoc_mgr_root_assoc = Slurmdb_association_rec_t.new('root', nil)
$assoc_mgr_root_assoc.usage_usage_efctv = 1.0
$assoc_mgr_root_assoc.usage_usage_energy_efctv = 1.0

$assoc_mgr_root_assoc.children << Slurmdb_association_rec_t.new("root/root", $assoc_mgr_root_assoc)
print_steps("++++++++++++++++++++++++++++++ job filter "+jobs.length.to_s)
jobs.each_pair do |jid, j|
# 	:job_id, :submit_time, :wait_time, :run_time, :procs_alloc, :cpu_time_used, :used_memory, :procs_req, :run_time_req, :mem_req, 
#     :status, :user_id, :group_id, :exe_num, :queue_id, :partition_id, :preceding_job_id, :preceding_job_think_time
	
	if $start_at <= j.submit_time+j.wait_time
		
		if assocs[j["user_id"]] == nil
			assocs[j["user_id"]] = Slurmdb_association_rec_t.new('user'+j["user_id"].to_s, $assoc_mgr_root_assoc)
			$assoc_mgr_root_assoc.children << assocs[j["user_id"]]
		end
		
		job = JobShort.new(
			j.job_id,
			j.submit_time+j.wait_time,
			j.submit_time+j.wait_time + j.run_time,
			j.run_time, j.procs_alloc, 0, assocs[j["user_id"]])
		$jobs_to_be_ran << job
	
	end
end
print_steps("++++++++++++++++++++++++++++++ sort job "+$jobs_to_be_ran.length.to_s)
$jobs_to_be_ran.sort! {| a, b | a[:start_time] <=> b[:start_time] }
jobs = nil #delete !

dd = $jobs_to_be_ran.first
debug("first job:"+dd.start_time.to_s + "//" + dd.total_cpus.to_s + "//" + dd.end_time.to_s+"\n")
dd = $jobs_to_be_ran.last
debug("last job:"+dd.start_time.to_s + "//" + dd.total_cpus.to_s + "//" + dd.end_time.to_s+"\n")
print_steps("++++++++++++++++++++++++++++++ STOP assocs and JOB")

#in sec
$actual_time = 0


# update actual_time to actual_time+time_add
# update $job_list according to the time
def update_job_list(time_add, dontSuperJump=false)
# 	p "update_job_list   " +$job_list.length.to_s + " && " + $jobs_to_be_ran.length.to_s+ "   at:"+$actual_time.to_s+" tryto:"+time_add.to_s
# 	p "next_event  print_time:"+
# 			$list_of_print_time.first.to_s+"//"+
# 		(($list_of_print_time.first/$slurm_get_priority_calc_period).floor*$slurm_get_priority_calc_period).to_s+
# 		"  job:"+$jobs_to_be_ran.first.start_time.to_s+"//"+
# 		(( $jobs_to_be_ran.first.start_time/$slurm_get_priority_calc_period).floor*$slurm_get_priority_calc_period).to_s
	#super jump !
	if $do_super_jump && !dontSuperJump && $job_list.length == 0 && $jobs_to_be_ran.length != 0
		#is the next event a job starting ?
		next_event =$jobs_to_be_ran.first.start_time

		if $list_of_print_time.length != 0 && $list_of_print_time.first < next_event
			next_event = $list_of_print_time.first
		end
		
		next_event =(( next_event/$slurm_get_priority_calc_period).floor*$slurm_get_priority_calc_period)

		if next_event- $actual_time > time_add
			debug("SUPER JUMP of "+(next_event - $actual_time).to_s+ " (instead of the normal jump of "+time_add.to_s+")\n")
			time_add = next_event - $actual_time
		end
	end
	
	#print sshare if necessary
	while ($list_of_print_time.length != 0) &&
			($actual_time <= $list_of_print_time.first) &&
			($list_of_print_time.first < $actual_time+ time_add) do
		puts "---------------------------------------------- At "+$list_of_print_time.first.to_s+ ", last exec at "+(($actual_time/$slurm_get_priority_calc_period).floor*$slurm_get_priority_calc_period).to_s
		$assoc_mgr_root_assoc.print_parsable_or_sshare()
		$list_of_print_time = $list_of_print_time.drop(1)
	end
	
	
	$actual_time = $actual_time + time_add
	

        $job_list.delete_if do |j|
                j.end_time < $actual_time
        end
        
	$jobs_to_be_ran.delete_if do |j|
		if j.start_time <= $actual_time
			$job_list<< j
			true
		end
	end

end

print_steps("++++++++++++++++++++++++++++++ INIT first updates")
update_job_list(0, true)
update_job_list($actual_time, true)

print_steps("++++++++++++++++++++++++++++++ END first updates")








# /*
#  * apply decay factor to all associations usage_raw
#  * IN: decay_factor - decay to be applied to each associations' used
#  * shares.  This should already be modified with the amount of delta
#  * time from last application..
#  * RET: SLURM_SUCCESS on SUCCESS, SLURM_ERROR else.
#  */
# static int _apply_decay(double decay_factor)
def _apply_decay( decay_factor)

# 	/* continue if decay_factor is 0 or 1 since that doesn't help
# 	   us at all. 1 means no decay and 0 will just zero
# 	   everything out so don't waste time doing it */
	if (decay_factor == 0)
		return $SLURM_ERROR;
	elsif (decay_factor == 1)
		return $SLURM_SUCCESS;
	end

# 	/* We want to do this to all associations including
# 	   root.  All usage_raws are calculated from the bottom up.
# 	*/
	
	itr = list_iterator_create_assoc_mgr_association_list();
	itr.each { |assoc|
#         puts "decay"+ assoc.usage_usage_raw.to_s + " XX "+ decay_factor.to_s;
		assoc.usage_usage_raw *= decay_factor;
		assoc.usage_usage_energy_raw *= decay_factor;
# 		assoc.usage_grp_used_wall *= decay_factor;
	}

# 	slurmdb_qos_rec_t *qos = NULL;
# 	itr = list_iterator_create(assoc_mgr_qos_list);
# 	while ((qos = list_next(itr))) {
# 		qos.usage_usage_raw *= decay_factor;
# 		qos.usage.grp_used_wall *= decay_factor;
# 	end
# 	list_iterator_destroy(itr);

	return $SLURM_SUCCESS;
end



# extern void priority_p_set_assoc_usage(slurmdb_association_rec_t *assoc)
def priority_p_set_assoc_usage(assoc)
# 	char *child;
# 	char *child_str;

	if (assoc.user)
		child = "user";
		child_str = assoc.user;
	else
		child = "account";
		child_str = assoc.acct;
	end

	if ($assoc_mgr_root_assoc.usage_usage_raw != 0)
		assoc.usage_usage_norm = assoc.usage_usage_raw / $assoc_mgr_root_assoc.usage_usage_raw;
	else
# 		/* This should only happen when no usage has occured
# 		 * at all so no big deal, the other usage should be 0
# 		 * as well here. */
		assoc.usage_usage_norm = 0;
	end

	debug("Normalized usage for %s %s off %s %Lf / %Lf = %Lf",
		     child, child_str, assoc.parent_assoc_ptr.acct,
		     assoc.usage_usage_raw,
		     $assoc_mgr_root_assoc.usage_usage_raw,
		     assoc.usage_usage_norm);

# 	/* This is needed in case someone changes the half-life on the
# 	 * fly and now we have used more time than is available under
# 	 * the new config */
	if (assoc.usage_usage_norm > 1.0)
		assoc.usage_usage_norm = 1.0;
	end

	if (assoc.parent_assoc_ptr == $assoc_mgr_root_assoc)
		assoc.usage_usage_efctv = assoc.usage_usage_norm;
		debug("Effective usage for %s %s off %s %Lf %Lf",
			     child, child_str,
			     assoc.parent_assoc_ptr.acct,
			     assoc.usage_usage_efctv,
			     assoc.usage_usage_norm);
	else
		if assoc.shares_raw == SLURMDB_FS_USE_PARENT
			temp = 0
		else
# 			temp = (assoc.shares_raw / (long double)assoc.usage_level_shares)
			temp = (assoc.shares_raw / assoc.usage_level_shares)
		end
		assoc.usage_usage_efctv = assoc.usage_usage_norm +
			((assoc.parent_assoc_ptr.usage_usage_efctv -
			  assoc.usage_usage_norm) *
			 (temp));
                
		debug("Effective usage for %s %s off %s %Lf + ((%Lf - %Lf) * %d / %d) = %Lf",
			     child, child_str,
			     assoc.parent_assoc_ptr.acct,
			     assoc.usage_usage_norm,
			     assoc.parent_assoc_ptr.usage_usage_efctv,
			     assoc.usage_usage_norm,
			     (assoc.shares_raw == SLURMDB_FS_USE_PARENT ?
			      0 : assoc.shares_raw),
			     assoc.usage_level_shares,
			     assoc.usage_usage_efctv);
	end
end


# extern void priority_p_set_assoc_energy_usage(slurmdb_association_rec_t *assoc)
def priority_p_set_assoc_energy_usage(assoc)
# 	char *child;
# 	char *child_str;

	if (assoc != $assoc_mgr_root_assoc)
		child = "user";
		child_str = assoc.name;
	else
		child = "account";
		child_str = assoc.name;
	end

	if ($assoc_mgr_root_assoc.usage_usage_energy_raw != 0)
		assoc.usage_usage_energy_norm = assoc.usage_usage_energy_raw / $assoc_mgr_root_assoc.usage_usage_energy_raw;
	else
# 		/* This should only happen when no usage has occured
# 		 * at all so no big deal, the other usage should be 0
# 		 * as well here. */
		assoc.usage_usage_energy_norm = 0;
	end

	debug("Normalized Energy usage for %s %s off %s %Lf / %Lf = %Lf\n",
		     child, child_str, assoc.parent_assoc_ptr.acct,
		     assoc.usage_usage_energy_raw,
		     $assoc_mgr_root_assoc.usage_usage_energy_raw,
		     assoc.usage_usage_energy_norm);
        
# 	/* This is needed in case someone changes the half-life on the
# 	 * fly and now we have used more time than is available under
# 	 * the new config */
	if (assoc.usage_usage_energy_norm > 1.0)
		assoc.usage_usage_energy_norm = 1.0;
	end
	
	if (assoc.parent_assoc_ptr == $assoc_mgr_root_assoc)
		assoc.usage_usage_energy_efctv = assoc.usage_usage_energy_norm;
		debug("Effective energy usage for %s %s off %s %Lf %Lf\n",
			     child, child_str,
			     assoc.parent_assoc_ptr.acct,
			     assoc.usage_usage_energy_efctv,
			     assoc.usage_usage_energy_norm);
	else
		if assoc.shares_raw == SLURMDB_FS_USE_PARENT
			temp = 0
		else
# 			temp = (assoc.shares_raw / (long double)assoc.usage_level_shares)
			temp = (assoc.shares_raw / assoc.usage_level_shares)
		end
		assoc.usage_usage_energy_efctv = assoc.usage_usage_energy_norm +
			((assoc.parent_assoc_ptr.usage_usage_energy_efctv -
			  assoc.usage_usage_energy_norm) *
			 (temp));
		debug("Effective energy usage for %s %s off %s %Lf + ((%Lf - %Lf) * %d / %d) = %Lf\n",
			     child, child_str,
			     assoc.parent_assoc_ptr.acct,
			     assoc.usage_usage_energy_norm,
			     assoc.parent_assoc_ptr.usage_usage_energy_efctv,
			     assoc.usage_usage_energy_norm,
			     ( (assoc.shares_raw == SLURMDB_FS_USE_PARENT) ? 0 : assoc.shares_raw),
			     assoc.usage_level_shares,
			     assoc.usage_usage_energy_efctv);
	end
end


# /* This should initially get the childern list from
#  * assoc_mgr_root_assoc.  Since our algorythm goes from top down we
#  * calculate all the non-user associations now.  When a user submits a
#  * job, that norm_fairshare is calculated.  Here we will set the
#  * usage_efctv to NO_VAL for users to not have to calculate a bunch
#  * of things that will never be used.
#  *
#  * NOTE: acct_mgr_association_lock must be locked before this is called.
#  */
# static int _set_children_usage_efctv(List childern_list)
def _set_children_usage_efctv(childern_list)

	if ((childern_list == nil) || (childern_list.length == 0))
		return $SLURM_SUCCESS;
	end
	
	childern_list.each {|assoc|
# 		if (assoc.user)
		if (assoc != $assoc_mgr_root_assoc)
# 			assoc.usage_usage_efctv = (long double)NO_VAL;
# 			assoc.usage_usage_energy_efctv = (long double)NO_VAL;
			assoc.usage_usage_efctv = 0#nil #NO_VAL;
			assoc.usage_usage_energy_efctv = 0#nil #NO_VAL;
		else
			priority_p_set_assoc_usage(assoc);
			priority_p_set_assoc_energy_usage(assoc);
			_set_children_usage_efctv(assoc.children);
		end
	 }
	
	return $SLURM_SUCCESS;
end




# /* If the job is running then apply decay to the job.
#  *
#  * Return 0 if we don't need to process the job any further, 1 if
#  * futher processing is needed.
#  */
# static int _apply_new_usage(struct job_record *job_ptr, double decay_factor,
# 			    time_t start_period, time_t end_period
#    			)
def _apply_new_usage(job_ptr, decay_factor, start_period, end_period)
# # 	slurmdb_qos_rec_t *qos;
# 	slurmdb_association_rec_t *assoc;
# 	double run_delta = 0.0, run_decay = 0.0, real_decay = 0.0;
# 	uint64_t cpu_run_delta = 0;
# 	uint64_t job_time_limit_ends = 0;
	run_delta = 0.0
	run_decay = 0.0
	real_decay = 0.0
	cpu_run_delta = 0
	job_time_limit_ends = 0

# 	/* If usage_factor is 0 just skip this
# 	   since we don't add the usage.
# 	*/
# 	qos = (slurmdb_qos_rec_t *)job_ptr.qos_ptr;
# 	qos = job_ptr.qos_ptr;
# 	if (qos && !qos.usage_factor)
# 		return 0;
# 	end
	
	if (job_ptr.start_time > start_period)
		start_period = job_ptr.start_time;
	end
	if (job_ptr.end_time && (end_period > job_ptr.end_time))
		end_period = job_ptr.end_time;
	end

	run_delta = end_period - start_period;

# 	/* job already has been accounted for
# 	   go to next */
	if (run_delta < 1)
		return 0;
	end

# 	/* cpu_run_delta will is used to
# 	 * decrease qos and assocs
# 	 * grp_used_cpu_run_secs values. When
# 	 * a job is started only seconds until
# 	 * start_time+time_limit is added, so
# 	 * for jobs running over their
# 	 * timelimit we should only subtract
# 	 * the used time until the time limit. */
# 	job_time_limit_ends = (uint64_t)job_ptr.start_time + (uint64_t)job_ptr.time_limit * 60;
	job_time_limit_ends = job_ptr.start_time + job_ptr.run_time * 60;

# 	if ((uint64_t)start_period  >= job_time_limit_ends)
	if (start_period  >= job_time_limit_ends)
		cpu_run_delta = 0;
	elsif (end_period > job_time_limit_ends)
		cpu_run_delta = job_ptr.total_cpus *
			(job_time_limit_ends - start_period);
# 			(job_time_limit_ends - (uint64_t)start_period);
	else
		cpu_run_delta = job_ptr.total_cpus * run_delta;
	end
        
	debug("job %u ran for %g seconds on %u cpus\n",
		     job_ptr.job_id, run_delta, job_ptr.total_cpus);

# 	/* get the time in decayed fashion */
	run_decay = run_delta * (decay_factor**run_delta);

# 	real_decay = run_decay * (double)job_ptr.total_cpus;
	real_decay = run_decay * job_ptr.total_cpus;

# 	//energy is only avalaible at the end of the job
# 	double real_decay_energy = 0;
	real_decay_energy = 0;
	if (job_ptr.end_time && (end_period >= job_ptr.end_time))
		real_decay_energy = job_ptr.consumed_energy;
	end
	debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX==II consumed_energy : %G, real_decay_energy: %G\n", job_ptr.consumed_energy, real_decay_energy);
	
	
# 	/* Just to make sure we don't make a
# 	   window where the qos_ptr could of
# 	   changed make sure we get it again
# 	   here.
# 	*/
# 	assoc = (slurmdb_association_rec_t *)job_ptr.assoc_ptr;
	assoc = job_ptr.assoc_ptr;
	
# 	/* We want to do this all the way up
# 	 * to and including root.  This way we
# 	 * can keep track of how much usage
# 	 * has occured on the entire system
# 	 * and use that to normalize against. */
	while (assoc != nil)
# 		if (assoc.usage_grp_used_cpu_run_secs >= cpu_run_delta)
# 			debug("grp_used_cpu_run_secs is %llu, will subtract %llu\n",
# 				     assoc.usage_grp_used_cpu_run_secs,
# 				     cpu_run_delta);
# 			assoc.usage_grp_used_cpu_run_secs -= cpu_run_delta;
# 		else
# 			debug("jobid %u, assoc %u: setting grp_used_cpu_run_secs to 0 because %llu < %llu\n",
# 				     job_ptr.job_id, assoc.id,
# 				     assoc.usage_grp_used_cpu_run_secs,
# 				     cpu_run_delta);
# 			assoc.usage_grp_used_cpu_run_secs = 0;
# 		end

# 		assoc.usage_grp_used_wall += run_decay;
# 		assoc.usage_usage_raw += (long double)real_decay;
# 		assoc.usage_usage_energy_raw += (long double)real_decay_energy;
		assoc.usage_usage_raw += real_decay;
		assoc.usage_usage_energy_raw += real_decay_energy;
	 
		debug("adding %f new usage to assoc %s (user='%s' acct='%s') raw usage is now %u.  Group wall added %f making it f. GrpCPURunMins is llu\n",
			     real_decay, assoc.name,
# 			     real_decay, assoc.id,
			     assoc.user, assoc.acct,
			     assoc.usage_usage_raw,
			     run_decay);
# 			     assoc.usage_grp_used_wall,
# 			     assoc.usage_grp_used_cpu_run_secs/60);
		assoc = assoc.parent_assoc_ptr;
# 		assoc = assoc.usage_parent_assoc_ptr;
	end
	                                            
	return 1;
end




# static void *_decay_thread(void *no_data)
def _decay_thread()
# 	struct job_record *job_ptr = NULL;
# 	ListIterator itr;
# 	time_t start_time = time(NULL);
# 	time_t last_ran = 0;
# 	time_t last_reset = 0, next_reset = 0;
# 	uint32_t calc_period = $slurm_get_priority_calc_period;
# 	double decay_hl = $slurm_get_priority_decay_hl;
# 	double decay_factor = 1;
# 	uint16_t reset_period = $slurm_get_priority_reset_period;
	job_ptr = nil;
	start_time = $actual_time;
	last_ran = nil;
	last_reset = 0
	next_reset = 0;
	calc_period = $slurm_get_priority_calc_period;
	decay_hl = $slurm_get_priority_decay_hl;
	decay_factor = 1;
	reset_period = $slurm_get_priority_reset_period;


# 	/*
# 	 * DECAY_FACTOR DESCRIPTION:
# 	 *
# 	 * The decay thread applies an exponential decay over the past
# 	 * consumptions using a rolling approach.
# 	 * Every calc period p in seconds, the already computed usage is
# 	 * computed again applying the decay factor of that slice :
# 	 * decay_factor_slice.
# 	 *
# 	 * To ease the computation, the notion of decay_factor
# 	 * is introduced and corresponds to the decay factor
# 	 * required for a slice of 1 second. Thus, for any given
# 	 * slice ot time of n seconds, decay_factor_slice will be
# 	 * defined as : df_slice = pow(df,n)
# 	 *
# 	 * For a slice corresponding to the defined half life 'decay_hl' and
# 	 * a usage x, we will therefore have :
# 	 *    >>  x * pow(decay_factor,decay_hl) = 1/2 x  <<
# 	 *
# 	 * This expression helps to define the value of decay_factor that
# 	 * is necessary to apply the previously described logic.
# 	 *
# 	 * The expression is equivalent to :
# 	 *    >> decay_hl * ln(decay_factor) = ln(1/2)
# 	 *    >> ln(decay_factor) = ln(1/2) / decay_hl
# 	 *    >> decay_factor = e( ln(1/2) / decay_hl )
# 	 *
# 	 * Applying THe power series e(x) = sum(x^n/n!) for n from 0 to infinity
# 	 *    >> decay_factor = 1 + ln(1/2)/decay_hl
# 	 *    >> decay_factor = 1 - ( 0.693 / decay_hl)
# 	 *
# 	 * This explain the following declaration.
# 	 */
	if (decay_hl > 0)
		decay_factor = 1 - (0.693 / decay_hl);
	end
# // 	_read_last_decay_ran(&last_ran, &last_reset); DON'T CARE
	if (last_reset == 0)
		last_reset = start_time;
	end

	while (1)
# 		time_t now = start_time;
# 		double run_delta = 0.0, real_decay = 0.0;
		now = start_time;
		run_delta = 0.0
		real_decay = 0.0;

		running_decay = 1;

# 		/* this needs to be done right away so as to
# 		 * incorporate it into the decay loop.
# 		 */
# 		/*switch(reset_period) {
# 		case PRIORITY_RESET_NONE:
# 			break;
# 		case PRIORITY_RESET_NOW:	//do once
# 			_reset_usage();
# 			reset_period = PRIORITY_RESET_NONE;
# 			last_reset = now;
# 			break;
# 		case PRIORITY_RESET_DAILY:
# 		case PRIORITY_RESET_WEEKLY:
# 		case PRIORITY_RESET_MONTHLY:
# 		case PRIORITY_RESET_QUARTERLY:
# 		case PRIORITY_RESET_YEARLY:
# 			if (next_reset == 0) {
# 				next_reset = _next_reset(reset_period,
# 							 last_reset);
# 			end
# 			if (now >= next_reset) {
# 				_reset_usage();
# 				last_reset = next_reset;
# 				next_reset = _next_reset(reset_period,
# 							 last_reset);
# 			end
# 		}*/

# 		/* now calculate all the normalized usage here */
# 		_set_children_usage_efctv(assoc_mgr_root_assoc.usage.childern_list);
		_set_children_usage_efctv($assoc_mgr_root_assoc.children);

		goto_get_usage = false
		
		if (last_ran == nil)
			goto_get_usage = true;
		else
			run_delta = start_time - last_ran
		end
	
		if (run_delta <= 0)
			goto_get_usage = true;
		end
		
		
		if !goto_get_usage
			
	# 		real_decay = pow(decay_factor, (double)run_delta);
			real_decay = (decay_factor ** run_delta);
	# #ifdef DBL_MIN
	# 		if (real_decay < DBL_MIN)
	# 			real_decay = DBL_MIN;
	# #endif
			debug("Decay factor over %g seconds goes from %.15f . %.15f\n",
				run_delta, decay_factor, real_decay);

	# 		/* first apply decay to used time */
			if (_apply_decay(real_decay) != $SLURM_SUCCESS)
				debug("priority/multifactor: problem applying decay\n");
				running_decay = 0;
				break;
			end

			
			if( $job_list.length > 0)
				debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX DECAY thread get_job_energy_usagen\n");
			else
				debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX DECAY thread USELESS\n");
			end
			
			$job_list.each do |job_ptr|
				debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX DECAY thread for %i\n", job_ptr.job_id);
		
# 				debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX steps %i %i\n", job_ptr.step_list, list_count(job_ptr.step_list));
				
				debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX ce %u\n", job_ptr.consumed_energy);
				
# 				/* apply new usage */
				if (!IS_JOB_PENDING(job_ptr) &&job_ptr.start_time && job_ptr.assoc_ptr)
					if (!_apply_new_usage(
						    job_ptr, decay_factor,
						    last_ran, start_time))
						continue;
					end
				end

# 				/*
# 				 * Priority 0 is reserved for held
# 				 * jobs. Also skip priority
# 				 * calculation for non-pending jobs.
# 				 */
# 				if ((job_ptr.priority == 0) || !IS_JOB_PENDING(job_ptr))
# 					continue;
# 				end
# // 				job_ptr.priority = _get_priority_internal(   DON'T CARE
# // 					start_time, job_ptr);
				last_job_update = Time.now();
# 				debug("priority for job %u is now %u\n", job_ptr.job_id, job_ptr.priority);
			end

		end

		last_ran = start_time;

# // 		_write_last_decay_ran(last_ran, last_reset);

		running_decay = 0;
		
# 		/* Sleep until the next time. */
		now = $actual_time;
		elapsed = now - start_time;
		if (elapsed < calc_period)
			debug("sleep for %u\n", (calc_period - elapsed));
#                         puts "to be ran: "+$jobs_to_be_ran.length.to_s + "  jobb_list: "+ $job_list.length.to_s
# 			sleep(calc_period - elapsed);
			update_job_list(calc_period - elapsed)
			
			start_time = $actual_time;
		else
			start_time = now;
		end
# 		/* repeat ;) */
		#or not ;)
		if $jobs_to_be_ran.length == 0 && $job_list.length == 0 && $list_of_print_time.length == 0
			debug("THE END !\n")
			return
		end
	end
end


print_steps("++++++++++++++++++++++++++++++ INIT let's go !")
_decay_thread()
print_steps("++++++++++++++++++++++++++++++ STOP let's go !")

puts "---------------------------------------------- *At "+$actual_time.to_s+ ", last exec at "+(($actual_time/$slurm_get_priority_calc_period).floor*$slurm_get_priority_calc_period).to_s
$assoc_mgr_root_assoc.print_parsable_or_sshare()
puts "----------------------------------------------"














