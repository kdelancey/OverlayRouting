require './header'
require './fragment'

class Segment

	@aryOfFragments = Array.new #array of all fragments
	
	@completeMessage = nil
	@segmentID = rand
	
	@maxPayload  = nil #int representing the max number of bytes in a message
	@sourceNode = nil #source node
	@destNode = nil #destination node
	
	def initialize( source, destination, message, mxP )
	
		# Initialize instance variables
		@maxPayload = mxP
		@completeMessage = message
		@sourceNode = source
		@destNode = destination
		
		#call fragment method on current segment
		fragment
	end
	
	# Fragments the completeMessage string into fragment(s).
	def fragment
	
		#General segment info
		timeToLive = 255
		segmentID = rand
	
		#Fragment info
		additionalFragments = 1
		
		#Iterator info
		currentByte = 0 # current byte of fragment iterator
		
		if ( @completeMessage.length > maxPayload ) #fragment message
			
			while ( currentByte < completeMessage.length )
			
				#get part of completeMessage to send in fragment
				fragmentData = @completeMessage[currentByte,\
													currentByte + maxPayload]
				#increment the current byte by maxPayload + 1 
				currentByte = currentByte + maxPayload + 1
				#if the next fragment would be outside of originalMessage.length
				#additional bytes turns to 0, signalling no more fragments
				if ( currentByte >= @completeMessage.length )
					additionalFragments = 0
				end
				#create header for specific fragment
				fragmentHeader = \
				Header.new @sourceNode, @destNode,\
							@segmentID, fragmentData.length,\
							additionalFragments, aryOfFragments.length,\
								timeToLive
								
				f = Fragment.new fragmentHeader fragmentData
				@aryOfFragments.push( f )
			end
		else 
			#create header for specific fragment
			fragmentHeader = \
			Header.new @sourceNode, @destNode, \
						@segmentID, @completeMessage.length,\
						0, aryOfFragments.length,\
							timeToLive
			f = Fragment.new fragmentHeader @completeMessage
			@aryOfFragments.push( f )
		end

	end
	
	def get_fragments 
		@aryOfFragments
	end

	def Segment.defragment( ary_of_fragment_strings, id_to_fragment )
	
		ary_of_fragment_strings.each do |fragment_str|
		
			# Get the header and payload one of the fragment strings
			curr_fragment = Segment.parse_fragment( fragment_str )
			
			# Get the segment id from the header of the fragment
			curr_fragment_pkt_id = curr_fragment.get_hdr.pkt_id
			
			# Check if the received fragment is the last fragment, representing
			# the end of the payload.
			curr_fragment_more_fragments = curr_fragment.get_hdr.more_frgmnts
			if ( curr_fragment_more_fragments == 0 )
				#since last in the payload, compile all into one message
				
				#TODO currently does not account for missing fragments;
				# if last fragment comes before another fragment, it will
				# create a shorter message. It should be okay for now, with
				# smaller messages, but for Part 2, it will need to be addressed.
				
				ary_of_fragments_with_same_pkt_id = \
							id_to_fragment[curr_fragment_pkt_id]
				
				if ( ary_of_fragments_with_same_pkt_id == nil )
					ary_of_fragments_with_same_pkt_id = Array.new 
					ary_of_fragments_with_same_pkt_id << curr_fragment
				end
				
				# Sort fragments by order.
				id_to_fragment[curr_fragment_pkt_id] = \
						sort_fragments( ary_of_fragments_with_same_pkt_id )
				# Concatenate all fragments into a message
				ret_str = concat_fragments(id_to_fragment[curr_fragment_pkt_id])
				# Delete the array of fragments, as message will now be used.
				id_to_fragment.delete(curr_fragment_pkt_id)
				# Return message
				return ret_str
				
			else 
			
				# If, for this id, there is no array of fragments yet,
				# make one. Else, add to the existing array.
				if ( id_to_fragment[curr_fragment_pkt_id] == nil )
					id_to_fragment[curr_fragment_pkt_id] = Array.new 
					id_to_fragment[curr_fragment_pkt_id] << curr_fragment
				else 
					id_to_fragment[curr_fragment_pkt_id] << curr_fragment
				end
			
			end
		
		end
	
	end
	
	def Segment.sort_fragments( ary_of_fragments )
	
		if ( ary_of_fragments.length == 1 || ary_of_fragments.length == 0 )
			return ary_of_fragments
		end
	
		return ary_of_fragments.sort_by { |f1|
					ary_of_fragments.get_hdr.ordr_of_fragment
				}
	
	end
	
	def Segment.concat_fragments( ary_of_sorted_fragments )
	
		ret_string = String.new
	
		ary_of_sorted_fragments.each { |fragment|
			ret_string << fragment.get_payload
		}
		
		return ret_string
	
	end
	
	# Parse the given Fragment string, 
	# Return an array/collection of objects representing each of the sections
	# of the header and the message
	# Returns a Fragment object.
	# This is a "static" method.
	def Segment.parse_fragment( hdr_str )
		ary_of_hdr_vals = hdr_str.split("|")
		
		STDOUT.puts "parse_fragment, recieved string:\n> " + hdr_str + "\n"
		
		frgmt_prt = Array.new(8)
		frgmt_prt[0] = ary_of_hdr_vals[0].to_i
		frgmt_prt[1] = ary_of_hdr_vals[1]
		frgmt_prt[2] = ary_of_hdr_vals[2]
		frgmt_prt[3] = ary_of_hdr_vals[3].to_i
		frgmt_prt[4] = ary_of_hdr_vals[4].to_i
		frgmt_prt[5] = ary_of_hdr_vals[5].to_i
		frgmt_prt[6] = ary_of_hdr_vals[6].to_i
		frgmt_prt[7] = ary_of_hdr_vals[7].to_i
		frgmt_prt[8] = ary_of_hdr_vals[8]	 #message
		
		frgmt_hdr = Header.new frgmt_prt[0],frgmt_prt[1],frgmt_prt[2], \
					frgmt_prt[3],frgmt_prt[4],frgmt_prt[5], \
					frgmt_prt[6],frgmt_prt[7]
					
		ret_frgmt = Fragment.new frgmt_hdr frgmt_prt
		
		return ret_frgmt
		
	end
end