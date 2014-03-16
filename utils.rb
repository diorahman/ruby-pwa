#
# Used to force a command line to contain certain switches
#
def require_options(cmdline,options,req_opts)
  req_opts.each{|opt| 
    if(options[opt].nil?)
      puts "Error! Switch #{opt} is required.\n#{cmdline}"
      exit
    end
  }
end
#
# Breaks a file up from tag1=val1:tag2=val2... to a Hash
#
def file_hash(file_name)
  file = file_name.split('/').last.split('.amps').first
  fhash = Hash.new
  file.split(':').each{|x| eqpos = x.index('=') 
    fhash[x.slice(0...eqpos)] = x.slice(eqpos+1..x.length-1)
  }
  fhash
end
#
# Does str match any of regular expressions in Array reg_exprs?
#
def matches_exprs?(str,reg_exprs)
  reg_exprs.each{|r| return true if(str.match(r))}
  false
end
#
# Returns [match,mean value,low edge,high edge,bin title (eg. W)]
#
def bin_info(bin_name)
  return nil if !bin_name
  match, title, min, max, = *(bin_name.match(/(\w*)bin(\d+)-(\d+)/))
  return nil if !match
  return [match,(min.to_f + max.to_f)/2.0,min.to_f,max.to_f,title]
end
#
# Is _name_ in range <tt>[bin_min,bin_max]</tt>?
#
def in_bin_range?(name,bin_min,bin_max)
  match,mean,min,max,title = bin_info(name)  
  return match if(bin_max.nil? and bin_min.nil?)
  return min.to_i >= bin_min if(bin_max.nil?)
  return min.to_i <= bin_max if(bin_min.nil?)
  (min.to_i >= bin_min and max.to_i <= bin_max)
end
#
# Get list of bins to use.
#
def bin_list(dirlist,ranges) 
  return nil unless dirlist
  dirlist = [dirlist] unless dirlist.instance_of?(Array)
  bins = []
  dirlist.each{|dir_name|
    Dir.open(dir_name){|dir| dir.entries.each{|bin| 
        next if(bin_info(bin).nil?)
        use_bin = false
        use_bin = true if(ranges.empty? or ranges.nil?)
        ranges.each{|range|
          if(in_bin_range?(bin,range[0],range[1]))
            use_bin = true
            break
          end
        }
	bins.push bin if(use_bin and !bins.include?(bin))
      }
    }
  }
  bins.sort!
end
#
# Returns [min,max] of all bins in list _bins_.
#
def bin_limits(bins)
  bmin,bmax = 1e30,0
  bins.each{|bin|
    match,mean,min,max,title = bin_info(bin)
    bmin = min if min < bmin
    bmax = max if max > bmax
  }
  [bmin,bmax]  
end
#
# Returns a random number in range (min,max)
#
def random(min,max) (max - min) * rand + min end
#
# Prints a line of character _ch_ accross the screen
#
def print_line(ch); 80.times{print ch}; print "\n"; end
#
# Are we running in parallel mode? (using MPI)
#
def parallel?; Module.constants.include?('MPI'); end
#
# Are we running under fit.rb?
#
def fit_mode?;  Module.constants.include?('Minuit'); end
#
# Are we running under plot.rb?
#
def plot_mode?; Module.constants.include?('Plot'); end
#
# Obtain bin limits (needs upgraded for coupled-channel)
#
def get_bin_limits(*dirs)
  bin_limits = []
  dirs.each{|dir| 
    bin_list(dir,$bin_ranges).each{|bin|
      match,mean,min,max,title = *(bin_info(bin))
      bin_limits.push [min,max] unless(bin_limits.include? [min,max])
    }
  }
  $bin_limits = bin_limits 
end
#
# Obtain bin ranges as a String
#
def bin_ranges_to_s(bin_ranges)
  s = nil
  if(bin_ranges.nil?) then s = 'all-bins' 
  else s = $bin_ranges.collect{|r| "#{r[0]}-#{r[1]}"}.join(',')
  end
  s
end
