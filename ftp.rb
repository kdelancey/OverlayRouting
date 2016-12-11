 # encoding: utf-8
 class Ftp
 
	def Ftp.file_transfer(threadMsg)
	
		# FORMAT: [DST] [FILE] [FPATH]
		msgParsed = threadMsg.split(" ", 3)
		# Destination and message to send
		
		dst = msgParsed[0]
		file = msgParsed[1]
		file_path = msgParsed[2]
		
		file_exists = File.exist?( file )
		
		# If does not have key in routing table, or file name is bad
		if ( !file_exists || !$rt_table.has_key?(dst))
			STDOUT.puts( "FTP ERROR: #{file} −− > #{dst} INTERRUPTED AFTER 0")
			return
		end
		
		# Naive use of this read. Could instead fragment by read from start to end_byte
		
		# Socket to nextHop neighbor
		nextHop_socket = nil
		# If the destination node in FTP command
		# is NOT connected to this node, or this node itself,
		# print failure message, and return
		nextHop_neighbor = $rt_table[dst][0] #change doesn't exist...
		if ( $neighbors[nextHop_neighbor] == nil ) #...doesn't exist
			if ( dst == $hostname ) #.. but if current node (sending to itself)...
				STDOUT.puts msg
			end
			STDOUT.puts( "FTP ERROR: #{file} −− > #{dst} INTERRUPTED AFTER 0") #...unconnected...
			return
		end
		
		start_byte = 0
		byte_space = ($max_pyld * 4)
		# If socket is open.
		if ( ( nextHop_socket = $neighbors[nextHop_neighbor][1] ) != nil )
		
			while ( (file_data = IO.binread(file, start_byte, byte_space) ) != nil)
			
				# Create a packet to fragment,
				segment_of_message = Segment.new( $hostname, dst, file_data, $max_pyld )
				
				# Get array of fragments to send from packet
				ary_of_fragments = segment_of_message.get_fragments
				
				# If nextHop is dst, send RECMSG
				# else, sent PT:  (passthrough)
				type_to_send = nil
				if ( nextHop_neighbor == dst )
					type_to_send = "FRECMSG:"
				else 
					type_to_send = "FPT:"
				end
				
				ary_of_fragments.each do | fragment_to_send |
					passthrough_msg = type_to_send + " #{file} #{file_path} " + fragment_to_send.to_s
					nextHop_socket.puts(passthrough_msg)
					sleep( 0.1 * $max_pyld)
				end
				
				start_byte = start_byte + ($max_pyld * 4)
			end
			
		end
	
	end
	
	# "Helper" sub message of FTP command.
	# Called on nodes on the way to the destination.
	# Any sequential nodes should either
	# use FPT: or FRECMSG:
	def Ftp.fpassthrough_command(threadMsg)
	
		# FORMAT: [FILE] [FPATH] [FRGMNT]
		msgParsed = threadMsg.split(" ", 3)
		# Destination and message to send
		file = msgParsed[0]
		fpath = msgParsed[1]
		
		frgmt_str = msgParsed[2]
		
		# Convert the string representing a fragment,
		# parse its header, and return a Fragment object
		# to use to determing routing
		rec_frgmt = Segment.parse_fragment( frgmt_str )
		rec_frgmt_hdr = rec_frgmt.get_hdr
		
		dst = rec_frgmt_hdr.dst_nd
		
		# Determine if the dst is within one hop reach,
		# or will need to pass through another node.
		nextHop_neighbor = $rt_table[dst][0]
		message_to_send = nil
		
		if ( nextHop_neighbor == dst)
			message_to_send = "FRECMSG: #{file} #{fpath} " + frgmt_str
		else
			message_to_send = "FPT: #{file} #{fpath} " + frgmt_str
		end
		
		# Send message over socket
		if ( ( nextHop_socket = $neighbors[nextHop_neighbor][1] ) != nil )
			nextHop_socket.puts( message_to_send )
		end
		
	end
	
	# "Helper" sub message of FTP command.
	# Called on nodes that recieves the message.
	# Will intake fragment, and add it to a hash
	# of started messages
	def Ftp.frecmsg_command(threadMsg)
	
		#{file} {fpath} {frgmt}
		msgParsed = threadMsg.split(" ", 3)
		# Destination and message to send
		file = msgParsed[0]
		fpath = msgParsed[1]
		
		frgmt_str = msgParsed[2]
		
		
		# Parse raw string, turn into fragment, get header
		frgmt = Segment.parse_fragment(frgmt_str)
		
		# Get the id of the packet from the header info.
		frgmt_id = frgmt.get_hdr.pkt_id
		
		# If pkt_id already exists in id_to_fragment hash,
		# concat to existing array. Else, make new array.
		if ( $id_to_fragment[frgmt_id] == nil )
			$id_to_fragment[frgmt_id] = [frgmt]
		else 
			$id_to_fragment[frgmt_id] << frgmt
		end
		
		# Defragment array of fragments.
		# If file path exists, write file to path.
		# Put success.
		if ( ( segmentMsg = Segment.defragment( $id_to_fragment[frgmt_id], $id_to_fragment ) ) != nil )
			if ( file_exists = File.exist?( fpath ))
				IO.write(file, segmentMsg)
				STDOUT.puts( "FTP: #{frgmt.get_hdr.src_nd} --> " + segmentMsg )
			end
		end
	end
 
 end