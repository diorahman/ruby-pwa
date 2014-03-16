# Author:: Mike Williams
require 'rexml/document'
module PWA
  #
  # The PWA::Kinvar class handles kinematic variables used in event-based 
  # fitting.
  #
  class Kinvar
    #
    # Name (String)
    #
    attr_reader :name
    #
    # Number of bins to use when plotting
    #
    attr_reader :num_bins
    #
    # Minimum range when plotting
    #
    attr_reader :range_min
    #
    # Maximum range when plotting
    #
    attr_reader :range_max
    #
    # Title when plotting
    #
    attr_reader :title
    #
    # Initialize from an XML element (from REXML).
    #
    def initialize(xml_elem)
      @name      = xml_elem.attributes['name']
      @num_bins  = xml_elem.attributes['num-bins'].to_i
      @range_min = xml_elem.attributes['min'].to_f
      @range_max = xml_elem.attributes['max'].to_f
      @title     = xml_elem.attributes['title']
    end
    #
    # Returns the bin index corresponding to _value_.
    #
    def bin_index(value) 
      return -1 if(value < @range_min or value > @range_max)
      (@num_bins*(value - @range_min)/(@range_max - @range_min)).to_i
    end
    #
    # Returns the mean value of bin _bin_index_.
    #
    def value(bin_index)
      @range_min + (bin_index + 0.5)*(@range_max - @range_min)/@num_bins.to_f
    end    
    #
  end
  #
  # The PWA::KinvarFile class handles reading kinematic variables from the 
  # binary files storing them.
  #
  class KinvarFile 
    #
    # XML kinvar file name
    #
    attr_reader :xml_file
    #
    # Binary kinvar file name
    #
    attr_reader :data_file
    #
    # Array of PWA::Kinvar's in this file
    #
    attr_reader :kinvars
    #
    # Initialize from an XML file.
    #
    def initialize(xml_file_name)
      @xml_file_name = xml_file_name
      @kinvars = Array.new
      doc = REXML::Document.new(File.new(xml_file_name))    
      kv_elem = doc.elements['kinematic-variables']
      kv_elem.elements.each('kinvar'){|kv| @kinvars.push Kinvar.new(kv)}
      @data_file = kv_elem.elements['dat-file'].attributes['file']
      @file = File.new(@data_file,'rb')
    end  
    #
    # Returns the Kinvar object w/ name _kinvar_
    #
    def [](kinvar) 
      @kinvars.each{|kv| return kv if(kv.name == kinvar)}; nil 
    end
    #
    # Have we reached the end of the file?
    #
    def eof; @file.eof; end
    #
    # Read the next event's kinematic variables (returns their values via Hash)
    #
    def read
      num_kv = @kinvars.length
      unpck = String.new
      num_kv.times{unpck += 'd'}
      vals = @file.read(num_kv*8).unpack(unpck)
      vals_hash = Hash.new
      num_kv.times{|kv| vals_hash[@kinvars[kv].name] = vals[kv]}
      vals_hash
    end
    #
  end
  #
end
