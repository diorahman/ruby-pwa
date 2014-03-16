# Author:: Mike Williams
module Create
  # The Create::Parameter class is used to create a MINUIT paramater for
  # a new fit. Setting the attributes of a Create::Parameter allows the user
  # to determine how a MINUIT parameter will be used in a fit. See the 
  # _Attributes_ below for details.
  #
  # ==Example Usage
  #  par.start_value = [0,2*Math::PI] # for random start in range
  #  par.start_value = 66 # to start at a specific value
  #  par.limits = :no_limits # no limits
  #  par.limits = [-1,1] # set parameter limits
  #  par.step_size = :constant # constant parameter
  #  par.step_size = :variable # variable parameter
  #  par.step_size = 0.001 # variable 
  #  par.tags = ['tag1','tag2'] # use these tags from amp file in name
  #  par.tags = [:bin,'tag1'] # create a unique parameter in each bin
  #  par.name = 'the name' # set name (overrides tags)
  #  # etc...
  #
  class Parameter
    #
    # Value at which the parameter should start. To specify a range of values
    # (from which a value will be chosen at random) use <tt>[min,max]</tt>
    # (default's to <tt>0</tt>).
    #
    attr_accessor :start_value
    #
    # Limits to be placed on the parameter during a fit (<tt>[min,max]</tt>).
    # To specify no limits (default), use either <tt>:no_limits</tt> or 
    # <tt>[0,0]</tt>.
    #
    attr_accessor :limits
    #
    # Initial step size (approximate error). For a constant parameter, use 
    # either <tt>:constant</tt> or <tt>0</tt>. For a variable parameter, any
    # positive number is allowed (default's to <tt>:variable</tt> which is
    # equal to <tt>0.1</tt>).
    #
    attr_accessor :step_size
    #
    # File tags used to build the parameter's name. If none are specified 
    # (default), then the name will simply be the handle used by the amplitude
    # creating the parameter. To specify that a unique parameter should be used
    # for each bin, add the tag <tt>:bin</tt>.
    #
    # Note: Directly setting _name_ overrides using _tags_.
    attr_accessor :tags
    #
    # Directly set the parameter's name (overriding the use of _tags_).
    #
    attr_accessor :name
    #
    # All Parameter's created
    #
    @@params = Hash.new
    #
    # Initialize a new parameter (set up default values of attributes).
    #
    def initialize
      @start_value,@limits,@step_size = 0,:no_limits,:variable
    end
    #
    # Register _param_ as parameter _name_.
    #
    def Parameter.[]=(name,param)
      param.name = name; @@params[name] = param
    end
    #
    # Returns Parameter _name_.
    #
    def Parameter.[](name); @@params[name]; end
    #
    # Iterates over all Parameters.
    #
    def Parameter.each; @@params.each{|name,par| yield name,par}; end
    #
    # Should this Parameter be unique in each bin (does _tags_ contain 
    # <tt>:bin</tt>)?
    #
    def bin_dependent?; return false if @tags.nil?; @tags.include?(:bin); end
    #
    # Maps out which Parameters are used by which Datasets.
    #
    def Parameter.map_pars_to_datasets
      pars2datasets = Hash.new
      @@params.each{|name,par| d_ary = []	
	Dataset.each{|dataset| 
	  dataset.each_amp{|amp| 
	    if(amp.uses_par?(name))
	      d_ary.push dataset.name
	      break
	    end
	  }
	}
	pars2datasets[name] = d_ary.join(':')
      }
      @@datasets2pars = Hash.new
      pars2datasets.each{|par_name,dset_val|
	@@datasets2pars[dset_val] = [] if(@@datasets2pars[dset_val].nil?)
	@@datasets2pars[dset_val].push par_name
      }
    end
    #
    # How many Parameters are bin-dependent?
    #
    def Parameter.num_bin_dependent
      num = 0
      Parameter.each{|name,par| num+=1 if(par.bin_dependent?)}
      num
    end
    #
    # How many parameters are bin-independent?
    #
    def Parameter.num_bin_independent
      @@params.length - Parameter.num_bin_dependent
    end
    #
    # Print all MINUIT parameter definitions to file in _dir_.
    #
    def Parameter.print(dir)
      Parameter.map_pars_to_datasets
      file = File.new("#{dir}/params.rb",'w')
      file.print "# MINUIT parameter definition file\n"
      file.print "PWA::Fcn.instance.parameter_def_proc{\n"
      if(Parameter.num_bin_independent > 0)
	file.print "  # bin-independent parameters\n"
	Parameter.each{|name,par| 
	  next if(par.bin_dependent?)
	  file.print '  '; par.print file
	}
      end
      if(Parameter.num_bin_dependent > 0)
	file.print "  # bin-dependent parameters\n"
	@@datasets2pars.each{|dset_val,par_ary|
	  file.print '  bin_list('
	  bins = []
	  dset_val.split(':').each{|dset_name| 
	    bins.push Dataset[dset_name].bins_dir
	  }
	  list = bins.collect{|b| "'#{b}'"}.join(',')
	  file.print "[#{list}],$bin_ranges).each{|bin|\n"
	  par_ary.each{|par_name| next if(!Parameter[par_name].bin_dependent?)
	    file.print '    '
	    Parameter[par_name].print file
	  }
	  file.print "  }\n"
	}
      end
      file.print "}\n"     
    end
    #
    # Print MINUIT parameter definition to _file_.
    #
    def print(file)      
      s = "PWA::Fcn.define_parameter(\"#{@name}\","
      if(@start_value.instance_of?(Array))
        s += "random(#{@start_value[0]},#{@start_value[1]}),"
      elsif(@start_value.instance_of?(Symbol))
        s += "#{@start_value}[bin],"
      else s += "#{start_value}," end
      if(@step_size.instance_of?(Symbol)) then s += ":#{@step_size},"      
      else s += "#{@step_size}," end
      if(@limits.instance_of?(Array))
        s += "[#{@limits[0]},#{limits[1]}])"
      else s += ":#{@limits})" end
      file.print "#{s}\n"
    end
    #
  end
  #
end
