# encoding: utf-8

class Circuit
	
	def Circuit.build(threadMsg)
		# CIRCUITB [CIRCUITID] [DST] [LIST OF NODES]
		# FORMAT of msgParsed: [CIRCUITID] [DST] [LIST OF NODES]
		msgParsed = threadMsg.split(" ")

		circuitid = msgParsed[0]
		dst = msgParsed[1]
		list_of_nodes = msgParsed[2].split(",")

		if ($circuits.has_key?(circuitid))
			return
		end

		# should be the next node in circuit. 
		# must be a nexthop, of will throw
		# error message back.
		potential_next_hop = list_of_nodes[0]

		if ( $neighbors.has_key?(potential_next_hop) )
			$circuits[circuitid] = ["BEGINNING", potential_next_hop, list_of_nodes.length]
		else
			STDOUT.puts( "CIRCUIT ERROR: #{$hostname} −|− > #{dst} FAILED AT #{$hostname}" )
			return
		end

		#shift list, removing first element
		list_of_nodes.shift
		
		# prepare string to send
		ret_list = list_of_nodes.to_s.delete("\s")
		ret_list[0] = ''
		ret_list[ret_list.length - 1] = '' 

		# send CB: message over nexthop neighbor
		$neighbors[potential_next_hop][1].puts("CB: #{circuitid} #{dst} #{$hostname} #{ret_list}")

	end
	
	def Circuit.message(threadMsg)
		# CIRCUITM [CIRCUITID] [MSG]
		# FORMAT of msgParsed: [CIRCUITID] [MSG]
		
		msgParsed = threadMsg.split(" ")
		
		circuitid = msgparsed[0]
		msg = msgparsed[1].split(",")
		
		# Does not have circuit
		if (!$circuits.has_key?(circuitid))
			STDOUT.puts "CIRCUITD Failed: ID does not exist."
			return
		end
		
		if ( ( nextNode = $circuits[circuitid][1] ) != nil )
			# Find the nextNode, send destroy message along that edge
			$neighbors[nextNode][1].puts( "CIRCUITM #{circuitid} #{msg}" )
		end
		
	end
	
	def Circuit.deconstruct(threadMsg)
		# CIRCUITD [CIRCUITID]
		# FORMAT of msgParsed: [CIRCUITID]
		
		circuitid = threadMsg
		
		# Does not have circuit
		if (!$circuits.has_key?(circuit_name))
			STDOUT.puts "CIRCUITD Failed: ID does not exist."
			return
		end
		
		if ( ( nextNode = $circuits[circuitid][1] ) != nil )
			# Find the nextNode, send destroy message along that edge
			$neighbors[nextNode][1].puts( "CIRCUITD #{circuitid}" )
		end
		
		$circuits.delete(circuitid)
		
	end
	
	def Circuit.build_message(threadMsg)
		# CB: [CIRCUITID] [DST] [PREV] [LIST OF NODES]
		# FORMAT of msgParsed: [CIRCUITID] [DST] [LIST OF NODES]
	
		msgParsed = threadMsg.split(" ")
		
		circuitid = msgParsed[0]
		dst = msgParsed[1]
		prev = msgParsed[2]
		list_of_nodes = nil
		
		if ( msgParsed == 4)
			list_of_nodes = msgParsed[3].split(",")
		else
			if ( dst != $hostname and $neighbors.has_key?(dst) )
				$circuits[circuitid] = [prev, dst]
				$neighbors[potential_next_hop][1].puts("CB: #{circuitid} #{dst} #{$hostname}")
			elsif ( dst == $hostname )
				$circuits[circuitid] = [prev, "END"]
				send_build_success_message(circuitid, dst)
				return
			else
				send_build_error_message(circuitid, dst, prev)
				return
			end
		end
		# Should be the next node in circuit. 
		# Must be a nextHop, of will throw
		# error message back.
		potential_next_hop = list_of_nodes[0]
		
		if ( $neighbors.has_key?(potential_next_hop) )
			$circuits[circuitid] = [prev, potential_next_hop]
		else
			send_build_error_message(circuitid, dst, prev)
			return
		end
		
		#Shift list, removing first element
		list_of_nodes.shift
		
		# Prepare string to send
		ret_list = list_of_nodes.to_s.delete("\s")
		ret_list[0] = ''
		ret_list[ret_list.length - 1] = '' 
		
		#Send request to build.
		$neighbors[potential_next_hop][1].puts("CB: #{circuitid} #{dst} #{$hostname} #{ret_list}")

		if ($circuits.has_key?(circuitid))
			send_build_error_message(circuitid, dst, prev)
			return
		end

		#$neighbors[potential_next_hop][1].puts("CB: #{CIRCUITID} #{DST} #{$hostname} #{LIST OF NODES} 0")
	
	end
	
	def Circuit.success_message(threadMsg)
		# CSUC: [CIRCUITID] [DST]
		# FORMAT of msgParsed: [CIRCUITID] [DST]
		
		msgParsed = threadMsg.split(" ")
		
		circuitid = msgParsed[0]
		dst = msgParsed[1]
		
		if( ( prevNode = $circuits[circuitid][0] ) != nil )
			if ( prevNode != "BEGINNING" )
				$neighbors[prevNode][1].puts( "CSUC: #{circuitid} #{dst} #{hops}" )
			elsif ( prevNode == "BEGINNING" )
				# CIRCUITB [CIRCUITID] −− > [DST] over [HOPS]
				STDOUT.puts( "CIRCUITB #{circuitid} −− > #{dst} over #{$circuits[circuitid][2]}")
			end
		else 
			STDOUT.puts "missing connection to #{dst}"
		end
		
	end
	
	def Circuit.error_message(threadMsg)
		# CERR: [CIRCUITID] [DST] [F_NODE]
		# FORMAT of msgParsed: [CIRCUITID] [DST] [F_NODE]
		
		msgParsed = threadMsg.split(" ")
		
		circuitid = msgParsed[0]
		dst = msgParsed[1]
		f_node = msgParsed[2]
		
		if( ( prevNode = $circuits[circuitid][0] ) != nil )
			if ( prevNode != "BEGINNING" )
				send_build_error_message(circuitid, dst, prevNode)
			elsif ( prevNode == "BEGINNING" )
				# CIRCUITB [CIRCUITID] −− > [DST] over [HOPS]
				STDOUT.puts("CIRCUIT ERROR: #{$hostname} −|− > #{dst} FAILED AT #{f_node}")
			end
		else 
			STDOUT.puts "missing connection to #{dst}"
		end
		
	end
	
	def Circuit.send_build_error_message(circuitid, dst, prev)
		if ( $neighbors.has_key?(prev) )
			$neighbors[prev][1].puts( "CERR: #{circuitid} #{dst} #{$hostname}" )
		end
	end
	
	def Circuit.send_build_success_message(circuitid, dst)

		if (!$circuits.has_key?(circuitid))
			return
		end
		
		if ( $neighbors.has_key?(prev) )
			$neighbors[prev][1].puts( "CSUC: #{circuitid} #{dst}" )
		end
	end

end