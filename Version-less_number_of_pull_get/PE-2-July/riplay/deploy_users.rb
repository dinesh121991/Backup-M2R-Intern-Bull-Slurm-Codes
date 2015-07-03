#!/usr/bin/ruby

require 'pp'
require 'getoptlong'
require "lib_swf.rb"


############
# Options
############

def usage_message
    <<EOS
Usage ./deploy_users [OPTIONS] -f FILE.swf

        OPTIONS:
                --swf_file | -f swf_file : specify the workload file
                --delete   | -d          : delete users instead of adding them
                --prefix   | -p prefix   : change user prefix to "prefix" (default: "user")
                --nodes    | -n file     : deploy users to the hosts contained in the file "file"
                --cluster  | -c name     : cluster name (default "cluster")
                --nolinux  | -L          : No deployement on linux (ie no "useradd")
                --help     | -h display  : this help message
EOS
end

opts = GetoptLong.new(
[ "--swf_file","-f",              GetoptLong::REQUIRED_ARGUMENT ],
[ "--delete","-d",              GetoptLong::NO_ARGUMENT ],
[ "--prefix","-p",            GetoptLong::REQUIRED_ARGUMENT ],
[ "--nodes","-n",              GetoptLong::REQUIRED_ARGUMENT ],
[ "--help","-h",                GetoptLong::NO_ARGUMENT ],
[ "--nolinux","-L",                GetoptLong::NO_ARGUMENT ],
[ "--cluster","-c",                GetoptLong::REQUIRED_ARGUMENT ]
)

$command = 'useradd -M -N'
$command_sacct = 'sacctmgr add'
$prefix = 'user'
$nodes = nil
$swf_file = nil
$cluster = "cluster"
$delete = false
$deployLinux = true

opts.each do |option, value| 
        if (option == "--swf_file")
                $swf_file = value
        elsif (option == "--delete")
                $command = 'userdel -r'
                $command_sacct = 'sacctmgr remove'
                $delete = true
        elsif (option == "--prefix")
                $prefix = value
        elsif (option == "--nodes")
                $nodes = value
        elsif (option == "--cluster")
                $cluster = value
        elsif (option == "--nolinux")
                $deployLinux = false
        elsif (option == "--help")
                puts usage_message
                exit 0
        end
end

if ($swf_file == nil)
  puts "Missing arguments."
  puts usage_message
  exit 0
end


############
# Main
############

#get users from swf file
jobs = load_swf_file($swf_file, nil, nil)

all_users_l = []
jobs.each_pair do |job_id, job_struct|
        all_users_l << job_struct["user_id"]
end

all_users_l.uniq!

all_users = all_users_l.join(" ")

#execute command
if $deployLinux
	#TODO: use taktuk
	if ($nodes == nil)
		p `for i in #{all_users}; do #{$command} #{$prefix}$i; done`
	else
		p `for node in \`cat #{$nodes}|sort -u\`; do ssh $node 'for i in #{all_users}; do #{$command} #{$prefix}$i; done'; done`
	end
end

p `#{$command_sacct} cluster #{$cluster} -i`
all_users_l.each do |u|
        if u != nil
                if $delete
                        p `#{$command_sacct} user #{$prefix}#{u} -i`
                        p `#{$command_sacct} account #{$prefix}#{u} -i`
                else
                        p `#{$command_sacct} account #{$prefix}#{u} -i`
                        p `#{$command_sacct} user #{$prefix}#{u} Accounts=#{$prefix}#{u} -i`
                end
        end
end

