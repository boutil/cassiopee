require 'digest/md5'
require 'logger'
require 'zlib'
require 'rubygems'
require 'text'
require 'text/util'

module Cassiopee

	# Calculate the edit or hamming distance between String and pattern
    # Extend a String
    # Return -1 if max is reached
    
    def computeDistance(pattern,hamming,edit)
      if(edit==0)
      	return computeHamming(pattern,hamming)
      else
       return computeLevenshtein(pattern,edit)
      end
    end
	
	# Calculate the edit or hamming distance between String and pattern
    # Extend a String
    # Return -1 if max is reached
    
    def computeAmbiguousDistance(pattern,hamming,edit,ambiguous)
      if(edit==0)
      	return computeHammingAmbiguous(pattern,hamming,ambiguous)
      else
       return computeLevenshteinAmbiguous(pattern,edit,ambiguous)
      end
    end
    
    # Compute Hamming distance but using a mapping matrix of alphabet ambiguity
    
    def computeHammingAmbiguous(pattern,hamming,ambiguous)
    	nberr = 0
    	(0..(self.length-1)).each do |c|
    		if(!isAmbiguousEqual(pattern[c],self[c],ambiguous))
    			nberr = nberr+1
    			if(nberr>hamming.to_i)
    				return -1		
    			end
    		end
    	end
    	return nberr
    end

     # Calculate number of substitution between string and pattern
    # Extend a String
    # Return -1 if max is reached
    
    def computeHamming(pattern,hamming)
    	nberr = 0
    	(0..(self.length-1)).each do |c|
    		if(pattern[c] != self[c])
    			nberr = nberr+1
    			if(nberr>hamming.to_i)
    				return -1		
    			end
    		end
    	end
    	return nberr
    end
	
	   
		     
    # Calculate the edit distance between string and pattern
    # Extend a String
    # Return -1 if max is reached
    
    def computeLevenshtein(pattern,edit)
    	
    	distance = Text::Levenshtein.distance(self, pattern)
    	
   	
    	if(distance>edit)
    		return -1
    	end
    	return distance
    	
    end
	
	private
	
	# Compute Levenshtein distance but using a mapping matrix of alphabet ambiguity
	# Code comes from Text gem, Text::Levenshtein.distance, adapted for ambiguity comparison
	
    def computeLevenshteinAmbiguous(pattern, edit, ambiguous)
	
		encoding = defined?(Encoding) ? self.encoding.to_s : $KCODE

		if Text.encoding_of(self) =~ /^U/i
			unpack_rule = 'U*'
		else
			unpack_rule = 'C*'
		end

		s = self.unpack(unpack_rule)
		t = pattern.unpack(unpack_rule)
		n = s.length
		m = t.length
		return m if (0 == n)
		return n if (0 == m)

		d = (0..m).to_a
		x = nil

		(0...n).each do |i|
			e = i+1
			(0...m).each do |j|
				cost = (isAmbiguousEqual(s[i],t[j],ambiguous)) ? 0 : 1
				x = [
					d[j+1] + 1, # insertion
					e + 1,      # deletion
					d[j] + cost # substitution
				].min
				d[j] = e
				e = x
			end
			d[m] = x
		end
		if(x>edit)
			return -1
		end
	
		return x
  end
  
  
  # checks if 2 chars are equal with ambiguity rules
  # * ambigous is a Hash of char/Array of char mapping
  
  def isAmbiguousEqual(a,b,ambiguous)
	if(ambiguous==nil || (ambiguous[a.chr]==nil && ambiguous[b.chr]==nil ))
	  if(a==b)
	    return true
	  else
	    return false
	  end
	end
	if(ambiguous[a.chr].index(b.chr)!=nil || ambiguous[b.chr].index(a.chr)!=nil || a==b)
	   return true
    else
	   return false
	end
  end
 
 	# Base class to index and search through a string 
 
    class Crawler
 
 	# Use alphabet ambiguity (dna/rna) in search, automatically set with loadAmbiguityFile
    attr_accessor  :useAmbiguity
    # Suffix files name/path
    attr_accessor  :file_suffix
    # Max number fo threads to use (not yet used)
    attr_accessor  :maxthread
    # Use persistent suffix file ?
    attr_accessor  :use_store
	# Array of comment characters to skip lines in input sequence file
	attr_accessor  :comments
    
    @min_position = 0
    @max_position = 0
	
	# Previous position filter
	@prev_min_position = 0
	@prev_max_position = 0
	
	@ambiguous = nil
	
	@pattern = nil
	
    
    FILE_SUFFIX_EXT = ".sfx"
    FILE_SUFFIX_POS = ".sfp"
    
    SUFFIXLEN = 'suffix_length'

    $maxthread = 1
	
    
    $log = Logger.new(STDOUT)
    $log.level = Logger::INFO
    
        def initialize
            @useAmbiguity = false
            @file_suffix = "crawler"
			
			@prev_min_position = 0
			@prev_max_position = 0
            
            @suffix = nil
            @suffixmd5 = nil
            @position = 0
            
            @suffixes = Hash.new
            
            @matches = Array.new
            @curmatch = 0
            @use_store = false
            
            @sequence = nil
			
			@comments = Array["#"]
        end
		
		def filterLength
		  filterOptimal(0)
		end
		
		def filterCost
		  filterOptimal(1)
		end
        
        # Clear suffixes in memory
        # If using use_store, clear the store too
        
        def clear
        	@suffixes = Hash.new
			@matches.clear
			@pattern = nil
			@prev_max_position = 0
			@prev_min_position = 0
        	File.delete(@file_suffix+FILE_SUFFIX_POS) unless !File.exists?(@file_suffix+FILE_SUFFIX_POS)
        end
    
    	# Set Logger level
    
        def setLogLevel(level)
            $log.level = level
        end
        
        # Index an input file
        # Clear existing indexes
        
        def indexFile(f)
         # Parse file, map letters to reduced alphabet
         # Later on, use binary map instead of ascii map
         # Take all suffix, order by length, link to position map on other file
         # Store md5 for easier compare? + 20 bytes per suffix
            @sequence = readSequence(f)
            clear()
            @min_position = 0
    		@max_position = 0
        end
        
        # Index an input string
        # Clear existing indexes
        
        def indexString(s)
            @sequence = s
            File.open(@file_suffix+FILE_SUFFIX_EXT, 'w') do |data|
            	data.puts(@sequence)
            end
            clear()
            @min_position = 0
    		@max_position = 0
        end
		
		
		# Load ambiguity rules from a file
		# File format should be:
		# * A=B,C
		#   D=E,F
		#   ...
		
		def loadAmbiguityFile(f)
		  if(!File.exists?(f))
		     $log.error("File "<< f << "does not exists")
			 exit(1)
		  end
		  @ambiguous = Hash.new
		  file = File.new(f, "r")
		  while (line = file.gets)
		    definition = line.downcase.chomp
			ambdef = definition.split('=')
			ambequal = ambdef[1].split(',')
			@ambiguous[ambdef[0]] = ambequal
		  end
		  @useAmbiguity = true
		  $log.debug("loaded ambiguity rules: " << @ambiguous.inspect())
		  file.close
		
		end
		
		# Load sequence from a previous index command
		
		def loadIndex
			seq = ''
			begin
				file = File.new(@file_suffix+FILE_SUFFIX_EXT, "r")
				while (line = file.gets)
					input = line.downcase.chomp
					seq << input
				end
				file.close
			rescue => err
				$log.error("Exception: #{err}")
				exit()
			end
			@sequence = seq
			clear()
            @min_position = 0
    		@max_position = 0
		end
        
        # Filter matches to be between min and max start position
        # If not using use_store, search speed is improved but existing indexes are cleared
        # If max=0, then max is string length
        
        def filter_position(min,max)
            if(!use_store)
        		clear()
        	end
			@prev_min_position = @min_position
			@prev_max_position = @max_position
        	@min_position = min
        	@max_position = max
        end
        
        # Search exact match
        
        def searchExact(s)
		
		if(isSameSearch?(s))
			return filterMatches
		end
		
		if(@useAmbiguity)
		  return searchApproximate(s,0)
		end
        s = s.downcase
        parseSuffixes(@sequence,s.length,s.length)
        
         @matches.clear
         # Search required length, compare (compare md5?)
         # MD5 = 128 bits, easier to compare for large strings
            
			@pattern = Digest::MD5.hexdigest(s)
			matchsize = @pattern.length
			
            @suffixes.each do |md5val,posArray|
                if (md5val == @pattern)
                    match = Array[md5val, 0, posArray]
		    		$log.debug "Match: " << match.inspect
		    		@matches << match
                end
            end
        return @matches 
        
        end
        
        # Search an approximate string
        #
        # * support insertion, deletion, substitution
        # * If edit > 0, use Hamming
        # * Else use Levenshtein
        
        
        def searchApproximate(s,edit)
		
			if(isSameSearch?(s))
				return filterMatches
			end
		
        	if(edit==0 && !@useAmbiguity) 
        		return searchExact(s)
        	end
        
        	if(edit>=0)
        	  useHamming = true
        	  minmatchsize = s.length
        	  maxmatchsize = s.length
        	else
        	  useHamming = false
        	  edit = edit * (-1)
              minmatchsize = s.length - edit
              maxmatchsize = s.length + edit
            end
			
			s = s.downcase
            
            parseSuffixes(@sequence,minmatchsize,maxmatchsize)
            
            @pattern = Digest::MD5.hexdigest(s)
            
        	@matches.clear
        	
        	@suffixes.each do |md5val,posArray|
        		if(md5val == SUFFIXLEN)
        			next
        		end
        		if (md5val == @pattern)
        			filteredPosArray = filter(posArray)
                    match = Array[md5val, 0, filteredPosArray]
		    		$log.debug "Match: " << match.inspect
		    		@matches << match
		    	else
		    		if(posArray[0]>= minmatchsize && posArray[0] <= maxmatchsize)
		    			# Get string
		    			seq = extractSuffix(posArray[1],posArray[0])
		    			seq.extend(Cassiopee)
		    			if(useHamming)
						  if(@useAmbiguity && @ambiguous!=nil)
						    errors = seq.computeHammingAmbiguous(s,edit,@ambiguous)
						  else
		    			    errors = seq.computeHamming(s,edit)
						  end
		    			else
						  if(@useAmbiguity && @ambigous!=nil)
						    errors = seq.computeLevenshteinAmbiguous(s,edit,@ambigous)
						  else
		    			    errors = seq.computeLevenshtein(s,edit)
						  end						
		    			end
		    			if(errors>=0)
		    				filteredPosArray = filter(posArray)
		    			    match = Array[md5val, errors, filteredPosArray]
		    				$log.debug "Match: " << match.inspect
		    				@matches << match
		    			end
		    		end
                end
        	
        	end
        	
        	return @matches 
        end
        
        # Filter the array of positions with defined position filter
        
        def filter(posArray)
        	$log.debug("filter the position with " << @min_position.to_s << " and " << @max_position.to_s)
        	if(@min_position==0 && @max_position==0)
        		return posArray
        	end
        	filteredArray = Array.new
        	i = 0
        	posArray.each do |pos|
        		if(i==0)
        			# First elt of array is match length
        			filteredArray << pos
        		end
        		if(i>0 && pos>=@min_position && pos<=@max_position)
        			filteredArray << pos
        		end
        		i +=1
        	end
        	return filteredArray
        end
        
        
        # Extract un suffix from suffix file based on md5 match
        
        def extractSuffix(start,len)
        	sequence = ''
                begin
                	file = File.new(@file_suffix+FILE_SUFFIX_EXT, "r")
		    		file.pos = start
					sequence = file.read(len)
                	file.close
                rescue => err
                	puts "Exception: #{err}"
                	return nil
                end
        	return sequence
        end
        
        # Iterates over matches
        
        def next
        	if(@curmatch<@matches.length)
        		@curmatch = @curmatch + 1
        		return @matches[@curmatch-1]
        	else
        		@curmatch = 0
        		return nil
        	end
        end
        
        def to_pos
        	positions = Hash.new
        	@matches.each do |match|
        	  # match = Array[md5val, errors, posArray]
        	  i=0
			  len = 0
        	  match[2].each do |pos|
        	    if(i==0)
        	      len = pos
        	    else
        	      if(positions.has_key?(pos))
        	       posmatch = positions[pos]
        	       posmatch << Array[len,match[1]]

        	      
        	      else
        	        posmatch = Array.new
        	        posmatch << Array[len,match[1]]
        	        positions[pos] = posmatch
        	      end
        	    end
        	    i += 1
        	  end
        	 
        	end
            return positions.sort
        end
        
        def to_s
        	puts '{ matches: "' << @matches.length << '" }'
        end
        
        private
		
			# Check is current search is the same, or within a previous search
			def isSameSearch?(s)
				if(@pattern!=nil && @pattern == Digest::MD5.hexdigest(s))
					if(@min_position>=@prev_min_position && @max_position <= @prev_max_position)
						return true
					end
				end
				return false
			end
			
			# Filter matches to remove positions out of bounds from a previous search
			
			def filterMatches
				newmatches = Array.new
				@matches.each do |match|
							filteredPosArray = filter(posArray)
							if(filteredPosArray.length>1)
								match = Array[match[0], match[1], filteredPosArray]
								newmatches << match
							end
				
				end
				return newmatches
			end
		
        
        	# Parse input string
        	#
        	# * creates a suffix file
        	# * creates a suffix position file
        	
            def parseSuffixes(s,minlen,maxlen)
            
            # Controls
            if(minlen<=0) 
            	minlen = 1
            end
            if(maxlen>@sequence.length)
            	maxlen = @sequence.length
            end
            
            if(!use_store)
            	minpos = @min_position
            	if(@max_position==0)
            		maxpos = @sequence.length
            	else
            		maxpos = @max_position
            	end
            else
            	minpos = 0
            	maxpos = @sequence.length - minlen
            end
            
            	suffixlen = nil
            	$log.info('Start indexing')
            	loaded = false
            	# Hash in memory already contain suffixes for searched lengths
            	if(@suffixes != nil && !@suffixes.empty?)
            		suffixlen = @suffixes[SUFFIXLEN]
            		if(suffixlen!=nil && !suffixlen.empty?)
            			loaded = true
            			(maxlen).downto(minlen)  do |len|
            				if(suffixlen.index(len)==nil)
            					loaded = false
            					break
            				end
            			end
            		end
            	end
            	
            	if(@use_store && loaded)
            		$log.debug('already in memory, skip file loading')
            	end
            	
            	# If not already in memory
            	if(@use_store && !loaded)
            		@suffixes = loadSuffixes(@file_suffix+FILE_SUFFIX_POS)
            		suffixlen = @suffixes[SUFFIXLEN]
            	end
            	
            	nbSuffix = 0
                changed = false
                
                # Load suffix between maxlen and minlen
                (maxlen).downto(minlen)  do |i|
                	$log.debug('parse for length ' << i.to_s)
                	if(suffixlen!=nil && suffixlen.index(i)!=nil)
                		$log.debug('length '<<i <<'already parsed')
                		next
                	end
                	changed = true
               		 (minpos..(maxpos)).each do |j|
               		 	# if position+length longer than sequence length, skip it
               		 	if(j+i>=@sequence.length)
               		 		next
               		 	end
                    	@suffix = s[j,i]
                    	@suffixmd5 = Digest::MD5.hexdigest(@suffix)
                    	@position = j
						progress = (@position * 100).div(@sequence.length)
						if((progress % 10) == 0)
							$log.debug("progress: " << progress.to_s)
						end
                    	#$log.debug("add "+@suffix+" at pos "+@position.to_s)
                    	nbSuffix += addSuffix(@suffixmd5, @position,i)
                    end
                    $log.debug("Nb suffix found: " << nbSuffix.to_s << ' for length ' << i.to_s)
                end
            
                
                if(@use_store && changed)
                	$log.info("Store suffixes")
                	marshal_dump = Marshal.dump(@suffixes)
                	sfxpos = File.new(@file_suffix+FILE_SUFFIX_POS,'w')
                	sfxpos = Zlib::GzipWriter.new(sfxpos)
                	sfxpos.write marshal_dump
                	sfxpos.close
                end
                $log.info('End of indexing')
            end
          
          
          	# Add a suffix in Hashmap
          	
          	def addSuffix(md5val,position,len)
          		if(@suffixes.has_key?(md5val))
                    # Add position
                	@suffixes[md5val] << position
    	        else
                    # Add position, write new suffix
                    # First elt is size of elt
                	@suffixes[md5val] = Array[len, position]
                	if(@suffixes.has_key?(SUFFIXLEN))
                		@suffixes[SUFFIXLEN] << len
                	else
                		@suffixes[SUFFIXLEN] = Array[len]
                	end
                end
          		return 1
          	end
          
          	# read input string, and concat content
          	
            def readSequence(s)
            	$log.debug('read input sequence')
                 counter = 1
                 sequence = ''
                    begin
                        file = File.new(s, "r")
                        File.delete(@file_suffix+FILE_SUFFIX_EXT) unless !File.exists?(@file_suffix+FILE_SUFFIX_EXT)
						File.open(@file_suffix+FILE_SUFFIX_EXT, 'w') do |data|
                    	  while (line = file.gets)
                    			counter = counter + 1
                            	input = line.downcase.chomp
								skip = false
								comments.each do |c|
									if(input[0] == c[0])
										# Line start with a comment char, skip it
										$log.debug("skip line")
										skip = true
										break
									end
								end
								if(!skip)
									sequence << input
									data.puts input
								end
                    	  end
                    	
						end
                    	file.close
                    rescue => err
                    	puts "Exception: #{err}"
                    	err
                    end
                    $log.debug('data file created')
                    return sequence
             end
             
            # Load suffix position file in memory 
            
            def loadSuffixes(file_name)
            	return Hash.new unless File.exists?(@file_suffix+FILE_SUFFIX_POS)
                begin
                  file = Zlib::GzipReader.open(file_name)
                rescue Zlib::GzipFile::Error
                  file = File.open(file_name, 'r')
                ensure
                    obj = Marshal.load file.read
                    file.close
                    return obj
                end
            end
			
			# Filter @matches to keep only the longest or the error less matches for a same start position
			
			def filterOptimal(type)
	
        	positions = Hash.new
        	@matches.each do |match|
        	  # match = Array[md5val, errors, posArray]
        	  i=0
			  len = 0
        	  match[2].each do |pos|
        	    if(i==0)
        	      len = pos
        	    else
        	      if(positions.has_key?(pos))
        	       posmatch = positions[pos]
        	       posmatch << Array[len,match[1],match[0]]
        	       #positions[pos] << posmatch
        	      
        	      else
        	        posmatch = Array.new
        	        posmatch << Array[len,match[1],match[0]]
        	        positions[pos] = posmatch
        	      end
        	    end
        	    i += 1
        	  end
        	end
			
            matchtoremove = Array.new
			positions.each do |pos,posmatch|
			 
			    optimal = nil
				match = nil
			    count = 0
				newoptimal = nil
				newmatch = nil
				
			    (0..posmatch.length-1).each do |i|
				solution = posmatch[i]				  
				  if(i==0)
				    if(type==0)
			        # length
			          optimal = solution[0]
			        else
			        # cost
			          optimal = solution[1]	
			        end				
			        match = solution[2].to_s
					#count += 1
					next
				  end
				  
			      newmatch = solution[2].to_s
				  if(type==0)
			      # length
			        newoptimal = solution[0]
				    if(newoptimal.to_i>optimal.to_i)
				      optimal = newoptimal
					  matchtoremove << match
				  	  match = newmatch
					else
					  matchtoremove << newmatch
				    end
			      else
			      # cost
				    newoptimal = solution[1]
				    if(newoptimal<optimal)
				      optimal = newoptimal
					  matchtoremove << match
			  		  match = newmatch
					else
					  matchtoremove << newmatch
				    end		
			      end
				  count += 1
					
				end			
			  
			end
			
			newmatches = Array.new
			@matches.each do |match|
			  found = false
			  matchtoremove.each do |item|
			    if(match[0]==item)
				  found = true
				  break
				end
			  end
			  if(!found)
			   newmatches << match
			  end
			end
			@matches = newmatches
			
			end
             
    end


end
