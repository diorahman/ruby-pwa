# Author:: Mike Williams
require 'complex'
module PWA
  #
  # The PWA::AmpParam class handles a single amplitude parameter for PWA::Amp.
  #
  class AmpParam
    #
    # Name w/in the PWA::Amp (shorthand)
    #
    attr_reader :handle
    #
    # Method object used to calculate dval/dpar by PWA::Amp.
    #
    attr_reader :deriv_method
    def initialize(handle,deriv_method)
      @handle,@deriv_method = handle,deriv_method
    end
  end
  #
  # The PWA::Amp class handles a single amplitude during fitting.
  #
  class Amp
    #
    # Name of the amplitude file
    #
    attr_reader :file
    #
    # Method object used to form MINUIT parameters into a Complex value
    #
    attr_accessor :value_method
    #
    # Use this amplitude when calculating the intensity?
    #
    attr_accessor :use
    #
    def initialize(file) 
      @file = file
      @params = Array.new 
      @pars_hash = Hash.new
      @use = true
    end
    #
    # Builds the internal parameter Hash...keep it around for performance.
    #
    def set_pars(pars)
      @params.each_index{|id| 
        @pars_hash[@params[id].handle] = pars[id] unless @params[id].nil?
      }
    end
    #
    # Add a MINUIT parameter for this amplitude.
    #
    def add_parameter(id,handle,deriv_method) 
      @params[id] = AmpParam.new(handle,deriv_method)
    end
    #
    # Returns the overall parameter value (Complex)
    #
    def value(vars=nil) @value_method.call(@pars_hash,vars); end
    #
    # Returns the overall parameter derivative for _id_.
    #
    def deriv(id,vars=nil)
      return 0 if @params[id].nil?
      @params[id].deriv_method.call(@pars_hash,vars)
    end
    #
  end
end
