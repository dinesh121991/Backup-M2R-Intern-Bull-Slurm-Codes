
Account = 0
User = 1
Raw_Shares = 2
Norm_Shares = 3
Raw_Usage = 4
Norm_Usage = 5
Effectv_Usage = 6
FairShare = 7
Raw_E_Usage = 8
Norm_E_Usage = 9
Effectv_E_Usage = 10
FairShare_E = 11
GrpCPUMins = 12
CPURunMins = 13

if ARGV.length != 2
	puts "Usage: gather_fs_info.rb sec num"
	exit 0
end

dodo = ARGV[0].to_i
num = ARGV[1].to_i

for i in 1..num
	cmdLine = `sshare -lhp`
	time = `date +%s`.chomp
	# $shares = []
	cmdLine.split("\n").each do |line|
	# 	share = []
		line.split("|").each do |col|
	# 		share << col
			if col == ""
				print "NA"
			else
				print col
			end
			printf("\t")
		end
		print time
	# 	share << time
	# 	$shares << share
		printf("\n")
		$stdout.flush
	end

	# $shares.each do |share|
	# 	share.each do |e|
	# 	end
	# end
	sleep(dodo)
end
