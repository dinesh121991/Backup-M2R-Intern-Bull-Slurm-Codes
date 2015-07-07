
require 'rubygems'
require 'bindata'

class AssocUsage < BinData::Record
        endian :big
#       safe_unpack16(&ver, buffer);
        uint16 :ver
#       safe_unpack_time(&buf_time, buffer);
        uint64 :time
        array :assocs, :read_until => :eof do
#               safe_unpack32(&assoc_id, buffer);
                uint32 :assoc_id
#               safe_unpack64(&usage_raw, buffer);
                uint64 :usage_raw
#               safe_unpack64(&usage_energy_raw, buffer);
#                 uint64 :usage_energy_raw
#               safe_unpack32(&grp_used_wall, buffer);
                uint32 :grp_used_wall
        end
end


if ARGV.length != 1
	puts "no file"
	exit 0
end

$input_file = ARGV[0]

io = File.open($input_file)
r  = AssocUsage.read(io)
# print "\n"
# print r.inspect
# print "\n"

print "# Version: "+r.ver.to_s+"\n"
print "# Time: "+r.time.to_s+"\n"
print "# Assocs:\n"
r.assocs.each do |a|
	print a.assoc_id.to_s + "\t"
	print a.usage_raw.to_s+ "\t"
# 	print a.usage_energy_raw.to_s+ "\t"
	print a.grp_used_wall.to_s+ "\n"
end
