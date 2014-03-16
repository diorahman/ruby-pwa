require 'rexml/document'
require 'matrix'
module Plot
  #  
  # The Plot::Iteration class fit iteration results.
  #
  class Iteration
    # all Iterations
    @@all = []
    # index in @@all to iteration w/ best fcn_min
    @@best_index = nil
    # XML file from which @@all's Iteration's were obtained
    @@xml_file = nil
    # parameter names matching this will be considered angles
    @@angle_expr = nil
    #
    # Maps MINUIT parameter names to ids
    #
    attr_reader :names2ids
    #
    # Array of parameter values
    #
    attr_reader :pars
    #
    # Matrix of covariance values
    #
    attr_reader :cov_matrix
    #
    # Fcn's minimum value
    #
    attr_reader :fcn_min
    #
    # Number of calls made to fcn
    #
    attr_reader :num_calls
    #
    # Ranges of bins to use
    #
    attr_reader :bin_ranges
    #
    def initialize(names2ids,pars,cov_matrix,fcn_min,num_calls,bin_ranges)
      @names2ids = names2ids
      @pars,@cov_matrix,@fcn_min,@num_calls = pars,cov_matrix,fcn_min,num_calls
      @bin_ranges = bin_ranges
    end
    #
    # Array of means of <tt>@bin_ranges</tt>
    #
    def range_means; @bin_ranges.collect{|min,max| (min+max)/2.0}; end 
    #
    # Returns the _iter_'th Iteration
    #
    def Iteration.[](iter); @@all[iter]; end
    #
    # Returns the Iteration w/ the best fcn min value
    #
    def Iteration.best; @@all[@@best_index]; end
    #
    # Returns the number iterations
    #
    def Iteration.length; @@all.length; end
    #
    # Iterates of all Iterations
    # 
    def Iteration.each(&block); @@all.each{|iter| yield(iter)}; end
    #
    # Comparisson operator for Iteration (compares fcn min)
    #
    def <=>(iter); self.fcn_min <=> iter.fcn_min; end
    #
    # Sort the iterations by fcn min (best first to worst last)
    #
    def Iteration.sort!
      @@all.sort!
      @@best_index = 0
    end
    #
    # Set Iteration from fit output file _xml_file_.
    #
    def Iteration.set(xml_file)
      @@all = []
      @@xml_file = xml_file
      doc = REXML::Document.new(File.new(xml_file))
      best_fcn = 1e30
      doc.root.elements.each('iteration'){|iter|
        fcn_min = iter.attributes['fcn-min'].to_f
        num_calls = iter.attributes['calls'].to_i
        bin_ranges = iter.attributes['bin-range'].split(',')
	bin_ranges = bin_ranges.collect{|b| b.split('-').collect{|x| x.to_i}}
        name2id = {}
        id = 1
        pars = [nil]
        iter.elements['minuit-pars'].elements.each('par'){|par|
          name2id[par.attributes['name']] = id
          pars[id] = par.attributes['value'].to_f
          id += 1
        }
        cov_rows = [Array.new(pars.length()+1,0)]
        iter.elements['cov-matrix'].elements.each('row'){|row|
          list = row.attributes['values'].split(',')
          row_ary = [0]
          list.each{|e| row_ary.push e.to_f}
          cov_rows.push row_ary
        }
        cov = Matrix.rows(cov_rows)
        itr = Iteration.new(name2id,pars,cov,fcn_min,num_calls,bin_ranges)
        @@all.push itr
        if(fcn_min < best_fcn)
          @@best_index = @@all.length()-1 
          best_fcn = fcn_min
        end
	#pars.each_index{|id| puts "#{id} #{pars[id]}"}
      }
    end    
    #
    # Set the angle expression
    #
    def Iteration.set_angle_expr(*expr) @@angle_expr = expr end
    #
    # Defines angle parameters
    #
    def set_angles
      return nil if(@@angle_expr.nil?)
      angle_ids = []
      @names2ids.each{|name,id| 
	angle = false
	@@angle_expr.each{|expr| angle = true if(name.match(expr))}
	angle_ids.push(id) if(angle)
      }
      # put values into range -pi to pi
      sigmas = Array.new(pars.length,0)
      pars.each_index{|id|
	sigmas[id] = Math.sqrt(@cov_matrix[id,id])
	next unless(angle_ids.include?(id))
	val = pars[id]	
	loop{
	  if(val > 0) then val -= 2*Math::PI
	  else val += 2*Math::PI end
	  break if(val.abs <= Math::PI)
	}
	pars[id] = val
      }
      # fix covariance matrix elements
      cov_rows = [Array.new(pars.length + 1,0)]
      pars.each_index{|id|
	row = []	
	pars.each_index{|id2| row[id2] = @cov_matrix[id,id2]}
	cov_rows[id] = row
	next unless(angle_ids.include?(id) and sigmas[id] > Math::PI)
	pars.each_index{|id2|
	  next if(id2 == 0)
	  rho = cov_rows[id][id2]/(sigmas[id]*sigmas[id2])
	  if(rho > 1.0)
	    #print "Warning! Covariance corelation factor > 1 between pars "
	    #puts "#{id} and #{id2} (#{rho}) - setting it to 1)"
	    rho = 1
	  end
	  cov = rho*Math::PI
	  if(angle_ids.include?(id2))
	    if(sigmas[id2] > Math::PI) then cov *= Math::PI
	    else cov *= sigmas[id2] end
	  else
	    cov *= sigmas[id2]
	  end	    
	  cov_rows[id][id2] = cov
	}
      }
      @cov_matrix = Matrix.rows(cov_rows)
    end
  end
end
