require 'socket'

# ====================================================================
# Pops off commands from commandQueue to run them on this node
# ====================================================================
def commandHandler

	def self.edgeb_command(threadMsg)
		# Format of msgParsed: [EDGEB] [SRCIP] [DSTIP] [DST]
		msgParsed = threadMsg.split(" ")
		dst = msgParsed[3]

		if ($neighbors[dst] == nil)
			# Adds edge of COST 1 to DST
			$rt_table[dst] = [dst, 1, 0]

			# Add edge to graph
			$graph.add_edge($hostname, dst, 1)
			
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

	def self.edged_command(threadMsg)
		# Format of msgParsed: [EDGED] [DST]
		msgParsed = threadMsg.split(" ")
		dst = msgParsed[1]

		# Removes the edge between current node and DST
		# Closes socket connection between the two nodes
		$neighbors[dst][1].close
		$neighbors.delete(dst)
		
		# Remove edge from graph
		$graph.remove_edge($hostname, dst)		
	end

	def self.edgeu_command(threadMsg)
		# Format of msgParsed: [EDGEU] [DST] [COST]
		msgParsed = threadMsg.split(" ")

		dst = msgParsed[1]
		cost = msgParsed[2].to_i

		#ALWAYS Update neighbors' cost
		$neighbors[dst][0] = cost

		# If new cost to neighbor is better than previous route to neighbor,
		# update routing table with DST as nextHop
		if ( $rt_table[dst][1] > cost )
			$rt_table[dst][0] = dst
		end

		# Update DST's COST
		$rt_table[dst][1] = cost

		# Update edge to dst with cost
		$graph.add_edge($hostname, dst, cost)
	end

	def self.lsu_command(threadMsg)
		# FORMAT RECIEVED: 
		# [LSU] [SRC] [DST] [COST] [SEQ #] [NODE SENT FROM]
		msgParsed = threadMsg.split(" ")
		
		src = msgParsed[1]
		dst = msgParsed[2]
		cost = msgParsed[3].to_i
		seq_num = msgParsed[4].to_i
		node_sent_from = msgParsed[5]
		
		# Don't send out link state packet if it's the same node
		if ( $hostname.eql?(src) )
			return
		end

		# Don't send out link state packet if it's an older sequence number
		if ( seq_num < $sequence_num )
			return
		end

		lsu_packet = "LSU #{src} #{dst} #{cost} #{seq_num} #{node_sent_from}"

		$lst_received[src] << node_sent_from

		$graph.add_edge(src, dst, cost)

		$neighbors.each do | edgeName, info |	
			# Send message for LinkStateUpdate
			if ( !$lst_received[src].include?(edgeName) )
				info[1].puts( lsu_packet )
			end
		end
	end

	while (true)
		threadMsg = nil
		
		# Check whether Queue has a message/command to process
		if ( !$commandQueue.empty? )			
			threadMsg = $commandQueue.pop
			
			if ( (!threadMsg.include?"REQUEST:") && (threadMsg.include?"EDGEB") )	
				edgeb_command(threadMsg)			
			elsif (threadMsg.include?"EDGED")	
				edged_command(threadMsg)
			elsif (threadMsg.include?"EDGEU")	
				edgeu_command(threadMsg)
			elsif (threadMsg.include?"LSU")
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
