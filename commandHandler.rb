require 'socket'

# ====================================================================
# Pops off commands from commandQueue to run them on this node
# ====================================================================
def commandHandler

	def self.edgeb_command(threadMsg)
		# Format of msgParsed: [EDGEB] [SRCIP] [DSTIP] [DST]
		msgParsed = threadMsg.split(" ")
		dst = msgParsed[3]

		if (msgParsed.length == 4) # May not need this as commands will always be valid
		
		if ($neighbors[dst] == nil)
			# Adds edge of COST 1 to DST
			$rt_table[dst] = [dst, 1, 0]
			
			# DST's port number
			dstPort = $nodes_map[dst]
			
			# Send request to DST to add edge to its routing
			# table. Flip recieved command to do so.
			# Format: [DSTIP] [SRCIP] [CURRENTNODENAME]
			str_request = "REQUEST:EDGEB #{msgParsed[2]} #{msgParsed[1]} #{$hostname}"
			
			# Open a TCPSocket with the [DSTIP] on the given
			# port associated with DST in nodes_map
			$neighbors[dst] = [1, TCPSocket.open(msgParsed[2], dstPort)]
			$neighbors[dst][1].puts(str_request)
		end
		
		end
	end

	def self.edged_command(threadMsg)
		# Format of msgParsed: [EDGED] [DST]
		msgParsed = threadMsg.split(" ")
		dst = msgParsed[1]

		if (msgParsed.length == 2) # Commands will always be valid so omit?

		# Removes the edge between current node and DST
		# Closes socket connection between the two nodes
		$neighbors[dst][1].close
		$neighbors.delete(dst)
		
		# Will change nextHop from this node to DST to nil since no path 
		# is possible and updates the cost to INFINITY
		$rt_table[dst][0] = nil
		$rt_table[dst][1] = $INFINITY
		
		end
	end

	def self.edgeu_command(threadMsg)
		# Format of msgParsed: [EDGEU] [DST] [COST]
		msgParsed = threadMsg.split(" ")
		dst = msgParsed[1]
		cost_to_dst = msgParsed[2].to_i
		
		if (msgParsed.length == 3) # Commands will always be valid so omit?
		
		#ALWAYS Update neighbors' cost
		$neighbors[dst][0] = cost_to_dst
			
		# If new cost to neighbor is better than previous route to neighbor,
		# update routing table with DST as nextHop
		if ( $rt_table[dst][1] > cost_to_dst )
			$rt_table[dst][0] = dst
		end

		# Update COST to DST
		$rt_table[dst][1] = cost_to_dst	

		end
	end
	
	def self.lsu_command(threadMsg)
		# FORMAT RECIEVED: 
		# [LSU] [NODE OF ORIGIN] [NODE REACHABLE] [COST OF REACH] [SEQ # WHEN REQUEST WAS SENT]
		msgParsed = threadMsg.split(" ")
		
		node_of_origin = msgParsed[1]
		node_reachable = msgParsed[2]
		cost_of_reach = msgParsed[3].to_int
		seq_num = msgParsed[4].to_int
		
		puts "Link State Update"
		puts $hostname
		puts msgParsed
		
		if (msgParsed.length == 5) # Commands will always be valid so omit?
			
			# IF ROUTE IS NEW:
			# If there is no route made for this node yet from [NODE REACHABLE],
			# make one using [NODE OF ORIGIN] as the nextHop, and [COST OF REACH] as cost.
			#
			# IF ROUTE IS OLD:
			# Check if, for [NODE REACHABLE] in routing table, the sequence # is younger
			# than [SEQ # WHEN REQUEST WAS SENT]. If the sequence # already on the routing table
			# is old, update with the new cost. Else, do nothing, because it may contain old
			# COST information, thus bad.
			# ALSO, if the route is old, and seq number is newer, check cost to that node.
			# If the nextHop doesn't provide a better hop, forget it!
			
			if ( (route_entry = $rt_table[node_reachable]) == nil )
			
				$rt_table[node_reachable] = [node_of_origin, cost_of_reach, seq_num]
				
			elsif (route_entry[2] < seq_num) #is a newer update
			
				if ( route_entry[1] > cost_of_reach ) #has a better cost than current route
					$rt_table[node_reachable] = [node_of_origin, cost_of_reach, seq_num]
				end
				
			end
			
		end
		
		
	end

	while (true)
		threadMsg = nil
		
		# Check whether Queue has a message/command to process
		if ( !$commandQueue.empty? )			
			threadMsg = $commandQueue.pop
			
			if ( (!threadMsg.include? "REQUEST:") && (threadMsg.include? "EDGEB") )	
				edgeb_command(threadMsg)			
			elsif (threadMsg.include? "EDGED")	
				edged_command(threadMsg)
			elsif (threadMsg.include? "EDGEU")	
				edgeu_command(threadMsg)
			elsif (threadMsg.include? "LSU")
				lsu_command(threadMsg)
			elsif ( (requestMatch = /REQUEST:/.match(threadMsg) ) != nil )				
				# Push REQUEST command to be run by node
				$commandQueue.push(requestMatch.post_match)
			else
				STDOUT.puts "Invalid command or not implemented yet"
			end			
		end
	end
	
end
