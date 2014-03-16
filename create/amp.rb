# Author:: Mike Williams
module Create
  # The Create::Amp class is used while creating a new fit to set up an
  # amplitude. For every amplitude, the user must define any MINUIT parameters
  # needed by the amplitude along w/ its <em>value method</em>. The 
  # <em>value method</em> is a Ruby method that takes as input the MINUIT
  # parameters and kinematic variables (for the _dcs_ case) and forms the 
  # overall parameter value that will multiply the amplitude value for each 
  # point/event.
  #
  # To define parameters, simply do
  #  # define parameter :a
  #  amp.parameter(:a){|par|
  #    # ...set par's attributes...
  #  }
  #  # define parameter :b
  #  amp.parameter(:b){|par|
  #    # ...set par's attributes...
  #  }
  #  amp.value_method = :some_method
  #
  # See Create::Parameter for details on setting parameter attributes. 
  #
  # <em>Value methods</em> should look like
  #  def some_method(pars,vars)
  #    a,b = pars[:a],pars[:b] # etc...
  #    x,y = vars[:x],vars[:y] # etc... (only for dcs case)
  #    val = # ... use a,b,x,y,...to set this
  #  end
  #
  # Ruby-PWA then assumes that the following <em>derivative methods</em> will
  # also be provided by the user
  #  def dsome_method_da(pars,vars) 
  #    # ...calc dval/da... 
  #  end
  #
  #  def dsome_method_db(pars,vars) 
  #    # ...calc dval/db... 
  #  end
  #
  # For better performance, <em>value/derivative methods</em> can be compiled 
  # c++ using Create::CppMethods.
  #
  class Amp
    # Ruby method of type <b>foo(pars,vars) -> Complex</b>
    attr_accessor :value_method
    # Name of the amplitude file (no path)
    attr_accessor :file_name
    #
    # Make a new Amp for file _file_name_
    #
    def initialize(file_name)
      @file_name = file_name
      @file_hash = file_hash(file_name)
      @params = Hash.new
    end
    #
    # Returns the value of file tag _tag_.
    #
    #  # for file 'a=1:b=2:.amps.xml'
    #  amp['a'] # -> '1'
    #  amp['b'] # -> '2'
    #  amp['c'] # -> nil
    #
    def [](tag); @file_hash[tag]; end
    #
    # Add a parameter for this Amp. The parameter will be passed to the 
    # <em>value method</em> w/ key _handle_.
    #
    #  # access this as pars[:x] in value method
    #  amp.parameter(:x){|par|
    #    # ...set par's attributes...
    #  }
    #
    def parameter(handle)
      par = Create::Parameter.new
      yield(par) if block_given?
      if(par.name.nil?)
        name = handle.to_s
        if(!par.tags.nil?)
          par.tags.each{|tag| 
	    if(tag == :bin) then name += ":\#\{bin\}"
	    else name += ":#{tag}=#{@file_hash[tag]}"
	    end
	  }
        end
        Create::Parameter[name] = par
      else Create::Parameter[par.name] = par
      end
      @params[handle] = name
    end
    #
    # Does this Amp use _parameter_?
    #
    def uses_par?(parameter); @params.values.include?(parameter); end
    #
    # Print this Amp's defintion to _file_.
    #
    def print(file)
      s = "    amp = PWA::Amp.new('#{@file_name}')\n"
      s += "    amp.value_method = method(:#{@value_method})\n"
      @params.each{|sym,name|
        par = Create::Parameter[name]
	pid = "PWA::ParIDs[\"#{par.name}\"]"
        dmeth = "method(:d#{@value_method}_d#{sym})"
        s += "    amp.add_parameter(#{pid},:#{sym},#{dmeth})\n"
      }
      file.print s
    end      
    #      
  end
  #
end
