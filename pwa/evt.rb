# Author:: Mike Williams
require "pwa/lib/#{ENV['OS_NAME']}/evt.so"
require 'pwa/kinvar.rb'
module PWA
  #
  # The PWA::Evt module is an extension for the PWA::Dataset class used for
  # event-bases log liklihood fitting.
  #
  module Evt
    #
    # Returns directory Hash. Keys are <tt>:data,:acc,:raw</tt>. The directory
    # should contain all files (amps,cuts,etc...) needed.
    #
    #  dataset.dir[:data] = '/some_dir/data/'
    #  dataset.dir[:acc] = '/some_dir/acc/'    
    #  dataset.dir[:raw] = '/some_dir/raw/'    
    #
    def dir
      @dir = {} if @dir.nil?
      @dir
    end
    #
    # Returns normalization integral Hash. Keys are <tt>:acc,:raw</tt>. Values 
    # should be XML file names for <em>norm-int</em> files.
    #
    def norm
      @norm_vals = CppVectorFlt3D.new if @norm_vals.nil?
      @norm = {} if @norm.nil?
      @norm
    end
    #
    # Returns kinematic variables Hash. Keys are <tt>:data,:acc,:raw</tt>. 
    # Values should be XML <em>kinvar</em> file names.
    #
    def kinvar
      @kinvar = {} if @kinvar.nil?
      @kinvar
    end
    #
    # Returns the cuts Hash. Keys are <tt>:data,:acc</tt>. 
    # Values should be <em>cuts</em> file names.
    #
    def cuts
      @cuts = {} if @cuts.nil?
      @cuts
    end
    #
    # Returns Array of cuts values for _type_ (<tt>:data,...</tt>).
    #
    def get_cuts(type)
      cuts = nil
      unless(@cuts.nil? or @cuts[type].nil?)
        cuts_file = File.new("#{@dir[type]}/#{@cuts[type]}")
        cuts = []
        while(cut = cuts_file.gets) 
	  sig = cut.split(' ')[0].to_f
          cuts.push sig
        end
        cuts_file.close
      end
      cuts
    end
    #
    # Returns Arrays of cuts w/ signal q-values and errors
    #
    def get_cuts_and_errors(type)
      cuts,errs = nil,nil
      unless(@cuts.nil? or @cuts[type].nil?)
        cuts_file = File.new("#{@dir[type]}/#{@cuts[type]}")
        cuts,errs = [],[]
        while(cut = cuts_file.gets) 
	  sig = cut.split(' ')[0].to_f
	  err = cut.split(' ')[1].to_f
          cuts.push sig
	  errs.push err
        end
        cuts_file.close
      end
      return cuts,errs
    end
    #
    # Returns the number of events of _type_ which pass _cuts_.
    #
    def get_num_events(type,cuts)
      return nil if(@amps.length == 0)
      file = File.new("#{@dir[type]}/#{@amps[0][0].file}")
      num_events,event_index = 0,0
      while(file.read(8))
        unless cuts.nil?
          num_events += 1 if(cuts[event_index] > 0)
        else
          num_events += 1
        end
        event_index += 1
      end
      num_events
    end
    #
    # Read in amplitude values for _type_.
    #
    def read_in_amps(max_par_id,type)
      cuts = self.get_cuts(type)
      @num_events = self.get_num_events(type,cuts)
      @wts = Array.new(@num_events,1)
      unless(cuts.nil?)
	keep_index = 0
	cuts.each_index{|c| 
	  if(cuts[c] > 0)
	    @wts[keep_index] = cuts[c] 
	    keep_index += 1
	  end
	}
      end
      self._resize(@num_events,max_par_id)      
      self.each_amp{|amp,ic,a| 
        file = "#{@dir[type]}/#{amp.file}"
	raise "File #{file} does NOT exist." unless File.exists?(file)
        self.read_in_amps_for_file(cuts,ic,a,file)
      }
    end
    #
    # Read in normalization integral values for _type_.
    #
    def read_in_norm(type,max_par_id=nil)
      unless(max_par_id.nil?)
        cuts = self.get_cuts(type)
        @num_events = self.get_num_events(type,cuts)
        self._resize(@num_events,max_par_id) 
      end
      doc = REXML::Document.new(File.new("#{@dir[type]}/#{@norm[type]}"))
      doc.root.elements.each('incoherent-waveset'){|ic_elem|
        files = []
        ic_elem.elements.each('wave'){|w| files.push w.attributes['file']}
        norm_vals = []
        row_index = -1
        ic_elem.elements['normint-elements'].elements.each('row'){|row|
          row_index += 1
          val_ary = row.text.split('|')
          norm_vals.push []
          val_ary.each{|c| 
            m,r,i = *(c.match(/\((.+)\,(.+)\)/))
            norm_vals.last.push Complex.new(r.to_f,i.to_f)
          }
        }
        @amps.each_index{|ic|
          @amps[ic].each_index{|a1|            
            a1_ind = files.index(@amps[ic][a1].file)
	    next if(a1_ind.nil?)
            @amps[ic].each_index{|a2|
              a2_ind = files.index(@amps[ic][a2].file)
	      raise "no norm-int entry for #{@amps[ic][a2].file}" if(a2_ind.nil?)	      
	      @norm_vals[ic,a1,a2] = norm_vals[a1_ind][a2_ind]
            }
          }
        }
      }
    end
    #
    # Returns the relative error on the normalization scale factors
    #
    def get_norm_rel_err
      rel_err2 = 0
      # 1st get acc
      doc = REXML::Document.new(File.new("#{@dir[:acc]}/#{@norm[:acc]}"))
      doc.root.elements.each('scale-factor'){|factor|
        next unless(factor.attributes['name'] == 'total-scale-factor')
        rel_err2 += (factor.attributes['relative-error'].to_f)**2
      }
      # now raw
      doc = REXML::Document.new(File.new("#{@dir[:raw]}/#{@norm[:raw]}"))
      doc.root.elements.each('scale-factor'){|factor|
        next unless(factor.attributes['name'] == 'total-scale-factor')
        rel_err2 += (factor.attributes['relative-error'].to_f)**2
      }
      Math.sqrt(rel_err2)
    end
    #
    # Returns the total scale factor
    #
    def get_norm_scale
      scale_factor = 1.0
       # 1st get acc
      doc = REXML::Document.new(File.new("#{@dir[:acc]}/#{@norm[:acc]}"))
      doc.root.elements.each('scale-factor'){|factor|
        next unless(factor.attributes['name'] == 'total-scale-factor')
        scale_factor *= 1.0/factor.attributes['value'].to_f
      }
      # now raw
      doc = REXML::Document.new(File.new("#{@dir[:raw]}/#{@norm[:raw]}"))
      doc.root.elements.each('scale-factor'){|factor|
        next unless(factor.attributes['name'] == 'total-scale-factor')
        scale_factor *= factor.attributes['value'].to_f
      }
      scale_factor
    end
    #
    # Returns -2*(-log(L) + norm) given MINUIT parameters _pars_. If _flag_ is
    # 2, then derivatives are calculated and filled in _derivs_.
    #
    def fcn_val(flag,pars,derivs)
      do_derivs = flag == 2 ? true : false
      self._set_params(pars,nil,do_derivs)
      lderivs = Array.new(pars.length,0)
      log_l = self.calc_log_liklihood(flag,pars,lderivs)
      nderivs = Array.new(pars.length,0)
      norm_int = self.calc_norm(flag,pars,nderivs)
      if(flag == 2)
        derivs.each_index{|p| next if(derivs[p].nil?)
          derivs[p] = 2*(lderivs[p] + nderivs[p])
        }
      end
     # puts "#{self.name} #{norm_int}"
     # puts "#{self.name} #{log_l} #{norm_int}"
      2*(log_l + norm_int)
    end
    #
    # Initialize to run a fit (read in amps + norm-int).    
    #
    def init_for_fit(max_par_id)
      self.read_in_amps(max_par_id,:data)
      self.read_in_norm(:acc)
      msg = "#{@name}: read amps for #{@num_events} events + norm-int"
      if(parallel?) then msg += "(on #{MPI.processor_name})."
      else msg += '.' end
      msg
    end
    #
    # Print set up to the screen.
    #
    def print_set_up
      self._print_set_up
      [:data,:acc,:raw].each{|type| puts "Dir(#{type}): #{@dir[type]}"}
      [:data,:acc].each{|type| 
	puts "Cuts(#{type}): #{@cuts[type]}" unless(@cuts.nil?)
      }
      [:acc,:raw].each{|type| puts "Norm(#{type}): #{@norm[type]}"}
      [:data,:acc,:raw].each{|type| puts "KV(#{type}): #{@kinvar[type]}"}
    end
    #
    # Returns the calculated yield of _type_ using all amps that match 
    # _reg_exp_ for MINUIT parameters _pars_.
    #
    def calc_yield(pars,reg_exp,type)
      y = nil
      if(type == :data)
        cuts = self.get_cuts(type)
        y = 0
        cuts.each{|cut| y += cut if(cut >= 0)}
      else
        self.use_files_matching(reg_exp) 
        self._set_params(pars,nil,false)
        y = self.calc_norm(0,pars,nil)
        self.use_all_files
      end
      y
    end
    #
    # Same as calc_yield but also returns error
    #
    def calc_yield_and_error(pars,cov_matrix,reg_exp,type)
      self.use_files_matching(reg_exp) 
      self._set_params(pars,nil,true)
      derivs = Array.new(pars.length,0)
      y = self.calc_norm(2,pars,derivs)
      self.use_all_files
      err2 = 0
      pars.length.times{|i|	
	pars.length.times{|j| 
	  err2 += derivs[i]*cov_matrix[i,j]*derivs[j]
	}
      }
      err = 0
      err = Math.sqrt(err2) if(err2 > 0)
      [y,err]
    end
    #
    # Sets up to get intensities
    #
    def set_for_intensities(pars,reg_expr)
      self.use_files_matching(reg_expr) 
      self._set_params(pars,nil,false)
      return nil
    end
    #
    # Returns histogram bins filled w/ yields vs. _kv_ of _type_ using all amps
    # that match _reg_exp_ for MINUIT parameters _pars_.
    #
    def histo_bins(kv,pars,reg_exp,type,condition=nil)
      dim = 1
      if(kv.instance_of?(Array))
        dim = kv.length
        raise "unsupported dimension: #{dim}" if(dim > 2)
        kv = kv.collect{|k| k.to_s}
      else
        kv = [kv.to_s]
      end
      unless reg_exp == :unwtd
        self.use_files_matching(reg_exp) 
        self._set_params(pars,nil,false)
      end
      cond = nil
      unless(condition.nil?)
	cond = condition.gsub('[','kv_vals["')
	cond.gsub!(']','"]')
      end
      cuts,errs = self.get_cuts_and_errors(type)
      kv_file = PWA::KinvarFile.new("#{@dir[type]}/#{@kinvar[type]}")
      event = 0
      ev_index = 0
      kinvars = Array.new
      kv.each{|k| kinvars.push kv_file[k]}
      kv_inds = Array.new(kinvars.length)
      num_bins = kinvars[0].num_bins
      bins,bin_errors = Array.new(num_bins,0),Array.new(num_bins,0)
      if(dim > 1)
	bins.each_index{|i| 
	  bins[i] = Array.new(kinvars[1].num_bins,0)
	  bin_errors[i] = Array.new(kinvars[1].num_bins,0)
	} 
      end
      num_events = self.get_num_events(type,cuts)
      num_events = 1e30 if num_events.nil?
      while(!kv_file.eof and event < num_events)
        kv_vals = kv_file.read	
	break if(!cuts.nil? and cuts[ev_index].nil?)
	kinvars.each{|k| break if(kv_vals[k].nil?)}
	pass = (cuts.nil? or cuts[ev_index] > 0)
	pass_cond = true
	pass_cond = eval(cond) unless(cond.nil? or !pass)
        if(pass and pass_cond)
          wt = 1.0
	  wt = cuts[ev_index] unless cuts.nil?
          wt = self.intensity event unless(reg_exp == :unwtd)
	  kinvars.each_index{|i|
	    kv_inds[i] = kinvars[i].bin_index(kv_vals[kv[i]])
	  }
	  if(dim == 1) 
	    if(kv_inds[0] >= 0)
	      bins[kv_inds[0]] += wt unless(kv_inds[0].nil?)
	      bin_errors[kv_inds[0]] += errs[ev_index] unless(kv_inds[0].nil? or errs.nil?)
	    end
	  else 
	    if(kv_inds[0] >= 0 and kv_inds[1] >= 0)
	      bins[kv_inds[0]][kv_inds[1]] += wt unless(kv_inds[1].nil?)
	      bin_errors[kv_inds[0]][kv_inds[1]] += errs[ev_index] unless(kv_inds[1].nil? or errs.nil?)
	    end
	  end
          event += 1
        end
	event += 1 if(pass and !pass_cond)
        ev_index += 1
      end
      # add statistical errors
      if(dim == 1)
	bins.each_index{|b|
	  bin_errors[b] = Math.sqrt(bins[b] + bin_errors[b]**2)
	}
      else
	bins.each_index{|b1|
	  bins[b1].each_index{|b2| 
	    bin_errors[b1][b2] = Math.sqrt(bins[b1][b2]+bin_errors[b1][b2]**2)
	  }
	}
      end
      #
      self.use_all_files
      if(dim == 1)
	title = kinvars[0].title
	num_bins = kinvars[0].num_bins
	range_min = kinvars[0].range_min
	range_max = kinvars[0].range_max
      else
	title = kinvars.collect{|k| k.title}
	num_bins = kinvars.collect{|k| k.num_bins}
	range_min = kinvars.collect{|k| k.range_min}
	range_max = kinvars.collect{|k| k.range_max}
      end
      return title,num_bins,range_min,range_max,bins,bin_errors
    end
    #
    #
  end
end
