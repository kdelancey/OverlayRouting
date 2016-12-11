require 'socket'

# ====================================================================
# Pops off commands from commandQueue to run them on this node
# ====================================================================
def commandHandler

	while (true)	
		threadMsg = nil

		if ( !$commandQueue.empty? )
			threadMsg = $commandQueue.pop
			
			if ( (!threadMsg.include? "REQUEST:" ) && (threadMsg.include? "EDGEB" ) )	
				Edge.edgeb(threadMsg)			
			elsif (threadMsg.include? "EDGED" )	
				Edge.edged(threadMsg)
			elsif (threadMsg.include? "EDGEU" )	
				Edge.edgeu(threadMsg)
			elsif (threadMsg.include? "EDGEREMOVE")
				Edge.edge_remove(threadMsg)
			elsif (threadMsg.include? "LSU" )
				LinkStateUpdate.lsu(threadMsg)
			elsif (threadMsg.include? "SENDMSG" )
				Sendmsg.command(threadMsg)
			elsif ( (match = /REQUEST:/.match(threadMsg) ) 	!= nil )				
				$commandQueue.push(match.post_match)
			elsif ( (match = /^PT:/.match(threadMsg))		!= nil )				
				Sendmsg.passthrough_command(match.post_match) # Push PT (passthrough) command to be run by node
			elsif ( (match = /^RECMSG:/.match(threadMsg) ) 	!= nil )				
				Sendmsg.recmsg_command(match.post_match) # Push RECMSG: (receive message fragment) command to be run by node
			elsif ( (match = /^FTP/.match(threadMsg))		!= nil )
				Ftp.file_transfer(match.post_match)
			elsif ( (match = /^FPT:/.match(threadMsg))		!= nil )				
				Ftp.fpassthrough_command(match.post_match) # Push FPT (FTP passthrough) command to be run by node
			elsif ( (match = /^FRECMSG:/.match(threadMsg) ) != nil )				
				Ftp.frecmsg_command(match.post_match) # Push FRECMSG: (receive FTP fragment) command to be run by node
			elsif (threadMsg.include? "SENDPING" )
				Ping.send(threadMsg)
			elsif (threadMsg.include? "PINGERROR" )
				Ping.error(threadMsg)
			elsif (threadMsg.include? "PINGSUCCESS" )
				Ping.success(threadMsg)
			elsif (threadMsg.include? "PING" )
				Ping.ping(threadMsg)
			elsif (threadMsg.include? "TRACEROUTE" )
				Traceroute.traceroute(threadMsg)
			elsif (threadMsg.include? "SENDTR" )
				Traceroute.send(threadMsg)
			elsif (threadMsg.include? "TRERROR" )
				Traceroute.error(threadMsg)
			elsif (threadMsg.include? "TRSUCCESS" )
				Traceroute.success(threadMsg)
			elsif ((match = /^CERR:/.match(threadMsg) ) 	!= nil)
				Circuit.error_message(match.post_match)
			elsif ((match = /^CSUC:/.match(threadMsg) ) 	!= nil)
				Circuit.success_message(match.post_match)
			elsif ((match = /^CB:/.match(threadMsg) ) 	!= nil)
				Circuit.build_message(match.post_match)
			elsif ((match = /^CIRCUITB/.match(threadMsg) ) 	!= nil)
				Circuit.build(match.post_match)	
			elsif ((match = /^CIRCUITM/.match(threadMsg) ) 	!= nil)
				STDOUT.puts "Unimplemented"
			elsif ((match = /^CIRCUITD/.match(threadMsg) ) 	!= nil)
				Circuit.deconstruct(match.post_match)
			elsif ((match = /^CPT:/.match(threadMsg) ) 	!= nil)
				STDOUT.puts "Unimplemented"
			elsif ((match = /^CRECMSG:/.match(threadMsg) ) 	!= nil)
				STDOUT.puts "Unimplemented"
			else
				STDOUT.puts "Invalid command or not implemented yet"
			end			
		end
	end
	
end
