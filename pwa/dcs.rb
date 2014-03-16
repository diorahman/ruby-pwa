# Author:: Mike Williams
require "pwa/lib/#{ENV['OS_NAME']}/dcs.so"
module PWA
  #
  # A measured differential cross section point.
  #
  class DcsPt
    attr_accessor :cs,:cs_err,:vars
    def initialize(cs,cs_err,vars)
      @cs,@cs_err,@vars = cs,cs_err,vars
    end
  end
  #
  # The PWA::Dcs module is an extension for the PWA::Dataset class used for
  # differential cross section fitting.
  #
  module Dcs
    #
    # Phase space factor (what to multiply the intensity by to get dsigma/dx)
    #
    attr_reader :phsp_factor
    #
    # Measured differential cross section points
    #
    attr_reader :dcs_pts
    #
    # XML file w/ cross section points
    #
    attr_accessor :dcs_file
    #
    # Directory containing amps and <tt>@dcs_file</tt>
    #
    attr_accessor :top_dir
    #
    # Extract cross section points from XML file <tt>@dcs_file</tt>.
    #
    def read_in_dcs
      @dcs_pts = []
      doc = REXML::Document.new(File.new("#{@top_dir}/#{@dcs_file}"))
      global_vars = Hash.new
      doc.elements.each('dcs/global-var'){|glv| 
	attr = glv.attributes
        global_vars[attr['name'].to_sym] = attr['value'].to_f
      }
      phsp_elem = doc.elements['dcs/phase-space-factor']
      @phsp_factor = phsp_elem.attributes['value'].to_f
      doc.elements.each('dcs/pt'){|pt|
        vars = Hash.new
        global_vars.each{|sym,val| vars[sym] = val}
        cs,cs_err = nil,nil
        pt.attributes.each{|name,value|
          if(name == 'cs') then cs = value.to_f
          elsif(name == 'cs-err') then cs_err = value.to_f
          else vars[name.to_sym] = value.to_f
          end
        }
        @dcs_pts.push DcsPt.new(cs,cs_err,vars)
      }
    end
    #
    # Reads in t_values needed for yields module...
    #
    def read_in_t_values
      @dcs_pts = []
      doc = REXML::Document.new(File.new("#{@top_dir}/#{@dcs_file}"))
      global_vars = Hash.new
      doc.elements.each('dcs/global-var'){|glv| 
	attr = glv.attributes
        global_vars[attr['name'].to_sym] = attr['value'].to_f
      }
      phsp_elem = doc.elements['dcs/phase-space-factor']
      @phsp_factor = phsp_elem.attributes['value'].to_f
      count = 0
      self.each_amp{|amp,ic,a|
	if count < 1
	  count += 1
	  file = "#{@top_dir}/#{amp.file}"
	  doc = REXML::Document.new(File.new(file))
	  doc.elements.each('amp-vals'){|amp_vals|
	    amp_vals.elements.each('pt'){|pt|
	      pt.attributes.each{|name,value|
		if name == "t"
		  vars = Hash.new
                  global_vars.each{|sym,val| vars[sym] = val}
		  vars[name.to_sym] = value.to_f
		  pt.attributes.each{|name2,value2|
		    vars[name2.to_sym] = value2.to_f if name2 == "u"
		  }
		  @dcs_pts.push DcsPt.new(0.0,0.0,vars)
		end
	      }
	    }
	  }
	end
      }
    end
    #
    # Read in amplitude values
    #
    def read_in_amps(max_par_id)
      self._resize(@dcs_pts.length,max_par_id)
      # use 1st file to get index map
      ind_map = Hash.new
      doc = REXML::Document.new(File.new("#{@top_dir}/#{@amps[0][0].file}"))
      @dcs_pts.each_index{|p|
	best_diff = 1e10
	pt_ind = 0
	doc.elements.each('amp-vals/pt'){|pt|
	  pt.attributes.each{|tag,val|
	    if(tag != 'amp')
	      diff = (@dcs_pts[p].vars[tag.to_sym] - val.to_f).abs
	      if(diff < best_diff)
		best_diff = diff 
		ind_map[p] = pt_ind
              end
            end
          }      
	  pt_ind += 1	  
	}
      }
      ind_ary = Array.new
      ind_map.each{|p,pt_ind|
	ind_ary[pt_ind] = [] if(ind_ary[pt_ind].nil?)
	ind_ary[pt_ind].push p
      }
      self.each_amp{|amp,ic,a|
	file = "#{@top_dir}/#{amp.file}"
	doc = REXML::Document.new(File.new(file))
	pt_ind = -1
	amp_val = nil
	doc.elements.each('amp-vals/pt'){|pt| pt_ind += 1
	  next if(ind_ary[pt_ind].nil?)
	  m,r,i = *(pt.attributes['amp'].match(/\((.+)\,(.+)\)/))
	  amp_val = Complex.new(r.to_f,i.to_f)
	  ind_ary[pt_ind].each{|p| @amp_vals[p,ic,a] = amp_val}
	}
      }   
    end
    #
    # Initialize to run a fit (reads in cross section points and amps)
    #
    def init_for_fit(max_par_id)
      self.read_in_dcs
      self.read_in_amps(max_par_id)
      msg = "#{@name}: read amps for #{@dcs_pts.length} pts"
      if(parallel?) then msg += "(on #{MPI.processor_name})."
      else msg += '.' end
      msg
    end
    #
    # Prints setup to the screen
    #
    def print_set_up
      self._print_set_up
      print "Dir:      #{@top_dir}\n"
      print "Dcs File: #{@dcs_file}\n"      
    end
    #
    # Returns <tt>[x,y,xerr,yerr]</tt> pts of measured cross section
    #
    def graph_pts_meas(kv)
      x,x_err,y,y_err = [],[],[],[]
      @dcs_pts.each{|pt|
	x.push pt.vars[kv]
	x_err.push 0.0
	y.push pt.cs
	y_err.push pt.cs_err
      }
      [x,y,x_err,y_err]
    end
    #
    # Returns <tt>[x,y,xerr,yerr]</tt> pts of calculated cross section (only
    # uses files matching _reg_exp_).
    #
    def graph_pts_calc(kv,pars,cov_matrix,reg_exp)
      self.use_files_matching(reg_exp)
      y,y_err = *(self.calc_dcs(pars,cov_matrix))
      self.use_all_files
      x = @dcs_pts.collect{|pt| pt.vars[kv]}
      [x,y,Array.new(x.length,0),y_err]
    end
  end
end
