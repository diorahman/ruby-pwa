# Author:: Mike Williams
require 'utils.rb'
require "pwa/lib/#{ENV['OS_NAME']}/cppvector"
require "pwa/lib/#{ENV['OS_NAME']}/dataset"
require 'pwa/amp'
require 'pwa/dcs'
require 'pwa/evt'
require 'pwa/parids'
#
module PWA
  #
  # The PWA::Dataset class is a generic class for handling all datasets during
  # a fit. The Dataset can be either of type <tt>:evt</tt> (event-based) or
  # <tt>:dcs</tt> (differential cross section). The type is determined during
  # initialization and causes the Dataset to extend itself w/ either PWA::Evt 
  # or PWA::Dcs.
  #
  class Dataset
    #
    # Make methods defined in dataset.cpp protected
    #
    protected :_resize,:_set_params
    #
    # Name of the Dataset
    #
    attr_reader :name
    #
    # Array of coherencies for this Dataset
    #
    attr_reader :coherence
    #
    # Dataset type (<tt>:evt</tt> or <tt>:dcs</tt>)
    #
    attr_reader :type
    #
    # global list of all Dataset's
    #
    @@all = Array.new
    #
    # Initialize dataset _name_, also add it to Dataset's global list.
    #
    def initialize(name,type); 
      @type = type
      self.extend PWA::Dcs if(type == :dcs)
      self.extend PWA::Evt if(type == :evt)
      @name = name; @amps = []; @coherence = []
      @amp_vals = CppVectorFlt3D.new
      @params = CppVectorDbl2D.new
      @dparams = CppVectorDbl3D.new      
      yield(self) if block_given?
      @index = @@all.length
      @@all.push self
    end
    #
    # Iterates over all Dataset's currently defined.
    #
    def Dataset.each; @@all.each{|dset| yield dset}; end
    #
    # Number of Dataset's defined.
    #
    def Dataset.length; @@all.length; end
    #
    # Returns the Dataset w/ name or index _id_.
    #
    def Dataset.[](id)
      if(id.instance_of?(String))
	@@all.each{|dset| return dset if(dset.name == name)}
      else
	return @@all[id]
      end
    end
    #
    # Add _amp_ w/ _coherence_ to this Dataset.
    #
    def add_amp(amp,coherence)
      @coherence.push coherence if(@coherence.index(coherence).nil?)
      coh_ind = @coherence.index(coherence)
      @amps[coh_ind] = [] if(@amps[coh_ind].nil?)
      @amps[coh_ind].push amp
    end
    #
    # Iterates over amplitudes in this Dataset
    #
    def each_amp 
      @amps.each_index{|ic| @amps[ic].each_index{|a| yield(@amps[ic][a],ic,a)}}
    end
    #
    # Use all files when calculating the amplitude.
    #
    def use_all_files; self.each_amp{|amp,ic,a| amp.use = true}; end
    #
    # Only use files which match regular expression _reg_ex_ when calculating 
    # the amplitude.
    #
    def use_files_matching(reg_ex)      
      self.each_amp{|amp,ic,a| amp.use = matches_exprs?(amp.file,[reg_ex])}
    end
    #
    # Prints generic Dataset setup to the screen
    #
    def _print_set_up
      print "Dataset: #{@name}    Type: #{@type}\n"
      amps_str = @amps.collect{|ic_amps| ic_amps.length}.join(',')
      print "Amps:    [#{amps_str}]\n"
    end
    protected :_print_set_up
    #
    # Free all memory used by this Dataset stored in c++ vectors
    #
    def clear
      @params.clear
      @dparams.clear
      @amp_vals.clear
      @norm_vals.clear unless @norm_vals.nil?
    end
    #
    # Remove all Dataset's from global list (and clear them)
    #
    def Dataset.clear
      Dataset.each{|dataset| dataset.clear}
      @@all.clear
    end
  end
end
