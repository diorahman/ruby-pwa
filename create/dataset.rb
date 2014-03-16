# Author:: Mike Williams
require 'utils.rb'
module Create
  #
  # The Create::Dataset class is used to set up a dataset for a new fit. When
  # creating a dataset, the user must specify a name and type. The type can be
  # either <tt>:dcs</tt> for chi^2 differential cross section fits or
  # <tt>:evt</tt> for log liklihood event-based fits. The user must then set
  # the required attributes (see Attributes section below for details).
  #
  # ==Example Usage
  #  dataset = Dataset.new('my_dataset',type) # type = :evt or :dcs
  #  dataset.coherence_tags = ['tag1','tag2','tag3']
  #  dataset.read_amps_from "/...full path to amp files.../WbinXXXX-YYYY/"
  #  dataset.use_amps_matching 'expr1','expr2'
  #
  # Then for <tt>:evt</tt> datasets only,
  #  dataset.norm[:raw]  = 'coherence=mz_g.mz_i.mz_f.final_state:.norm-int.xml'
  #  dataset.norm[:acc]  = :$acc_norm_file
  #  dataset.cuts[:data] = :$data_cuts_file 
  #  dataset.cuts[:acc]  = :$acc_cuts_file 
  #  dataset.kinvar[:data] = 'kinvar.xml'
  #  dataset.kinvar[:acc] = 'kinvar.xml'
  #  dataset.kinvar[:raw] = 'kinvar.xml'
  # Note, that we can set <tt>norm/cuts</tt> files directly w/ a String or we
  # can specify a Ruby variable via its Symbol. This variable must be defined
  # at fit run-time (most likely via a required ruby file).
  #
  # For <tt>:dcs</tt> datasets only,
  #  dataset.dcs_file = 'dcs.xml'
  #
  #
  class Dataset
    #
    # File tags used to determine coherence (<tt>['tag1','tag2',...]</tt>).
    #
    attr_accessor :coherence_tags
    #
    # XML file w/ differential cross section values (no path). For Datasets w/
    # type <tt>:dcs</tt> only.
    #
    attr_accessor :dcs_file
    #
    # Dataset type (set via _new_).
    # * <tt>:dcs</tt> for chi^2 differential cross section fits
    # * <tt>:evt</tt> for log liklihood event-based fits
    #
    attr_reader :type
    #
    # Top directory. For <tt>:dcs</tt> datasets, this is the directory which
    # contains the bins. For <tt>:evt</tt> datasets, this is the directory
    # which contains <tt>data,acc,raw</tt>.
    #
    # Note: Automatically set by read_amps_from method.
    attr_accessor :top_dir
    #
    # Directory to read bins from (automatically set by read_amps_from).
    #
    attr_accessor :bins_dir
    #
    # Hash of cuts file names (no path). For Datasets w/ type <tt>:evt</tt> 
    # only. Keys <tt>:data</tt> and <tt>:acc</tt> can be set. 
    #
    attr_accessor :cuts
    #
    # Hash of normalization integral file names (no path). For Datasets w/ type
    # <tt>:evt</tt> only. Keys <tt>:acc</tt> and <tt>:raw</tt> can be set.
    #
    # Note: Use a <tt>Symbol</tt> to set a value to a Ruby variable.
    attr_accessor :norm
    #
    # Hash of kinematic variable file names (no path). For Datasets w/ type
    # <tt>:evt</tt> only. Keys <tt>:data, :acc</tt> and <tt>:raw</tt> can be 
    # set.
    #
    # Note: Use a <tt>Symbol</tt> to set a value to a Ruby variable.
    attr_accessor :kinvar
    #
    # Name of the Dataset (set via _new_).
    #
    attr_reader :name
    #
    # Extension module (for special types)
    #
    attr_accessor :extension
    #
    @@datasets = Hash.new
    #
    # Create dataset _name_ w/ _type_ (<tt>:evt</tt> or <tt>:dcs</tt>).
    #
    def initialize(name,type) 
      @name,@type = name,type
      @reg_exprs = []
      @amps = Hash.new
      @cuts = Hash.new; @norm = Hash.new; @kinvar = Hash.new
      @@datasets[name] = self
    end
    #
    # utility method used during printing
    #
    def _print_attr(attr_str)
      attr = eval(attr_str)
      return "\n" if(attr.instance_of?(String) and attr.empty?)
      return "\n" if(attr.nil?)
      s = "    dataset.#{attr_str} = "
      s += "'#{attr}'\n" if(attr.instance_of?(String))
      s += "#{attr}[bin]\n" if(attr.instance_of?(Symbol))
      s
    end
    protected :_print_attr
    #
    # Returns Dataset _name_
    #
    def Dataset.[](name); @@datasets[name]; end
    #
    # Iterates over all Datasets.
    #
    def Dataset.each; @@datasets.each{|name,dset| yield dset}; end      
    #
    # Read amplitude files from _dir_ (also sets @top_dir)
    #
    def read_amps_from(dir) 
      @read_dir = dir
      @bins_dir = @read_dir.sub(@read_dir.split('/').last,'')
      if(@type == :evt)
	bd_ary = bins_dir.split('/'); bd_ary.pop
	@top_dir = bd_ary.join('/')
      else @top_dir = bins_dir
      end
    end
    #
    # Use amplitude files matching these regular expressions. This method can
    # be called mutltiple times to add more expressions.
    #
    #  dataset.use_amps_matching 'exp1','exp2'
    #  dataset.use_amps_matching 'exp3','exp4','exp5'
    #
    def use_amps_matching(*reg_exprs); @reg_exprs.push(reg_exprs).flatten!; end
    #
    # Gets all amplitude files from directory specified in read_amps_from.
    #
    def _get_amps()
      files = nil
      Dir.open(@read_dir){|dir|
        files = dir.entries.delete_if{|f| !matches_exprs?(f,@reg_exprs)}
      }
      files.each{|f|
        if(@type == :evt) # check for 0 amps
          skip_file = true
          File.open("#{@read_dir}/#{f}",'rb') {|amps_file|
            10.times {
              amp = amps_file.read(8)
              raise "read failed for #{@read_dir}/#{f}" if(amp.nil?)        
              real,imag = amp.unpack("ff")
              if(real != 0 or imag != 0)
                skip_file = false
                break
              end
            }
          }
          next if skip_file
        end
        found_rule = false
        Create::Rule.each{|rule|
          if(rule.matches?(f))
            amp = rule.create_amp(f)
            coh = @coherence_tags.collect{|t|"#{t}=#{amp[t]}"}.join(':')
            @amps[coh] = Array.new if @amps[coh].nil?
            @amps[coh].push amp
            found_rule = true
            break
          end
        }
        if(!found_rule)
          puts "Error! Could not find Rule matching #{f}."
          exit
        end
      }
    end
    protected :_get_amps
    #
    # Iterates over amps
    #
    def each_amp; @amps.each{|coh,amps| amps.each{|amp| yield amp}}; end
    #
    # Print the dataset definition to directory _dir_. The file will be called
    # <tt>dataset=name.rb</tt> (where _name_ is the name of this Dataset).
    #
    def print(dir)
      file_name = "dataset=#{@name}.rb"
      file = File.new("#{dir}/#{file_name}",'w')
      file.print "# #{@name} dataset definition file\n"
      file.print "bin_list('#{@bins_dir}',$bin_ranges).each{|bin|\n"
      file.print "  PWA::Dataset.new(\"#{@name}:\#\{bin}\",:#{@type}){"
      file.print "|dataset|\n"
      file.print "    dataset.extend #{@extension}\n" unless @extension.nil?
      if(@type == :evt)	
        [:data,:acc,:raw].each{|type|
          file.print "    dataset.dir[:#{type}] = "
          file.print "\"#{@top_dir}/#{type}/\#\{bin}/\"\n"
        }
        [:data,:acc].each{|type| file.print self._print_attr("cuts[:#{type}]")}
        [:acc,:raw].each{|type| file.print self._print_attr("norm[:#{type}]")}
        [:data,:acc,:raw].each{|type| 
          file.print self._print_attr("kinvar[:#{type}]")
        }
      else
        file.print "    dataset.top_dir = \"#{@top_dir}/\#\{bin}/\"\n"      
	file.print "    dataset.dcs_file = \"#{@dcs_file}\"\n"
      end
      self._get_amps
      @amps.each{|coherence,amps|
        amps.each{|amp|
          amp.print(file)
          file.print "    dataset.add_amp(amp,'#{coherence}')\n"
        }
      }
      file.print "  }\n"
      file.print "}\n"
      file.close
      file_name
    end
  end
  #
end
