require 'rexml/document'
require 'singleton'
require 'pwa/parallel'
require 'ftools.rb'
module PWA
  #
  # The PWA::Fcn class is used by MINUIT during fitting.
  #
  class Fcn
    include Singleton
    #
    # Number of calls to _fcn_ made so far.
    #
    attr_accessor :num_calls
    #
    # Print updates every <tt>num_calls_per_print</tt> calls.
    #
    attr_accessor :num_calls_per_print
    #
    # Number of iterations to run.
    #
    attr_accessor :num_iters
    #
    # Current iteration index (starts at 0...this is Ruby)
    #
    attr_reader :iter
    #
    # Output file path
    #
    attr_accessor :out_path
    #
    # Registers Fcn with Minuit. Also sets the minimization strategy to 2 and
    # tells Minuit that we're going to calculate the derivatives ourselves.
    #
    def initialize
      @num_calls = 0
      @num_calls_per_print = 100
      @num_iters = 1
      @out_path = './'
      if(!parallel? or Parallel.master?)
	Minuit.register_fcn(self)
	Minuit.set_strategy 2
	Minuit.set_gradient 1
      end
    end
    #
    # Code block to execute during minimization
    #
    def minimization_proc(&proc); @min_proc = proc; end
    #
    # Code block to execute when setting parameters for a new fit.
    #
    def parameter_def_proc(&proc); @par_def_proc = proc; proc.call; end
    #
    # Define a MINUIT parameter for a new fit.
    #
    def Fcn.define_parameter(name,start,step,limits)
      PWA::ParIDs.push name
      if(!parallel? or Parallel.master?)
	Minuit::Parameter.define(PWA::ParIDs[name],name,start,step,limits)
      end
    end
    #
    # Minimize _fcn_.
    #
    def minimize
      @num_iters.times{|iter|
	@iter = iter
	@num_calls = 0; Minuit.call_fcn(666); # reset MINUIT
	@par_def_proc.call # reset parameter values
	begin
	  @min_proc.call     # minimize
	rescue Interrupt
	  interrupt = true
	  print 'Interrupted! Write Output (yes,no)? '
	  answer = STDIN.gets.chop.downcase
	  if(answer != 'yes') then exit end
	end
	puts "final fcn-min: #{Minuit::Status.fcn_min}"
	self.write_output("#{@out_path}/#{bin_ranges_to_s($bin_ranges)}.xml")
	print_line(':')	
      }
    end
    #
    # Adds XML output to _doc_
    #
    def _add_iteration(doc)
      attr = {'fcn-min' => Minuit::Status.fcn_min,'calls' => @num_calls}
      attr['bin-range'] = bin_ranges_to_s($bin_ranges)
      iter = doc.root.add_element 'iteration',attr
      pars = iter.add_element 'minuit-pars'
      Minuit::Parameter.each{|par|
	attr = {'name' => PWA::ParIDs.name(par.id)}
	attr['value'] = sprintf("%g",par.value)
	pars.add_element('par',attr)
      }
      cov_matrix = iter.add_element 'cov-matrix'
      Minuit.par_ids.each{|i|
	vals = []
	Minuit.par_ids.each{|j| vals.push sprintf("%g",Minuit::CovMatrix[i,j])}
	cov_matrix.add_element('row',{'values' => vals.join(',')})
      }
    end
    protected :_add_iteration
    #
    # Writes fit output to XML _file_
    #
    def write_output(file)
      doc = nil
      if(File.exists?(file))
	doc = REXML::Document.new(File.new(file))
      else
	doc = REXML::Document.new 
	doc << REXML::XMLDecl.new
	doc.add_element 'pwa-fit'
      end
      self._add_iteration(doc)
      out = File.new(file,'w')
      doc.write(out,0)
      out.close
    end
    #
    # Protected method used in fcn for setting derivatives
    #
    def _add_derivs(dset_derivs,derivs)
      derivs.each_index{|d| 
	derivs[d]+=dset_derivs[d] unless derivs[d].nil?
      }
    end
    protected :_add_derivs
    #
    # Method used by MINUIT during minimization
    #
    def fcn(flag,pars,derivs)
      fcn_val = 0.0
      if(parallel?)
	Parallel.send_to_children(false,:terminate)
	Parallel.send_to_children(flag,:fcn_flag)
	Parallel.send_to_children(pars,:params)
	#
	# do the master nodes calculations
	#
	Parallel.each_dataset_on_node{|dataset|
	  dset_derivs = Array.new(pars.length,0)
	  fcn_val += dataset.fcn_val(flag,pars,dset_derivs)
	  self._add_derivs(dset_derivs,derivs) if(flag == 2)
	}
	#
	# add the child node calculations
	#
	Parallel.recv_from_children(:fcn_val).each{|fcn_vals| 
	  fcn_vals.each{|f| fcn_val += f}
	}
	if(flag == 2)
	  Parallel.recv_from_children(:derivs).each{|node_derivs|
	    node_derivs.each{|dderivs| self._add_derivs(dderivs,derivs)}
	  }
	end
      else
	Dataset.each{|dataset|
	  dset_derivs = Array.new(pars.length,0)
	  fcn_val += dataset.fcn_val(flag,pars,dset_derivs)
	  self._add_derivs(dset_derivs,derivs) if(flag == 2)
	}
      end
      @num_calls += 1
      self.print_status pars
      fcn_val
    end
    #
    # Prints minimization status to the screen
    #
    def print_status(pars)
      if(@num_calls % @num_calls_per_print == 0)
	status = "calls: #{@num_calls} fcn-min: #{Minuit::Status.fcn_min}"
	unless parallel?
	  dummy = Array.new(pars.length)
	  Dataset.each{|dataset| next unless dataset.type == :evt	  
	    status += " norm-int(#{dataset.name}): "
	    status += "#{dataset.calc_norm(0,pars,dummy)}"
	  }
	end
	puts status
      end
    end
    #
  end
end    
