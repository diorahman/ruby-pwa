module Plot
  #
  # The Plot::PhaseDiffs class plots MINUIT parameters.
  #
  class PhaseDiffs
    #
    # Regular expressions to match to parameter names
    #
    attr_accessor :reg_exprs
    #
    # ROOT TCanvas produced
    #
    attr_reader :canvas
    #
    # Array of ROOT TGraphs for each parameter diffs
    #
    attr_reader :graphs
    #
    # Add PhaseDiffs command line arguments to _cmdline_
    #
    def PhaseDiffs.add_args(cmdline,options)
      cmdline.separator 'Plot::PhaseDiffs options:'
      cmdline.on('--par reg-ex1,reg-ex2',Array,
                 'Use parameters these reg-exps'){|reg_ary|
	unless(reg_ary.length == 2)
	  raise "Error! 2 expressions must be passed to par." 
	end
	options[:par] = [] if(options[:par].nil?)
	options[:par].push reg_ary
      }
    end
    #   
    # Initialize using _options_ Hash.
    #
    def initialize(options)
      @graphs = []
      @diffs = []
      @errs = []
      @reg_exprs = options[:par]
      @canvas = ::TCanvas.new('phase_diffs_canvas','',25,25,500,500)
    end
    #
    # Produce plots for MINUIT parameters _pars_.
    #
    def make_plots(pars,cov_matrix)
      @reg_exprs.each_index{|r|
	pars.each_index{|id1| 
	  next if(pars[id1].nil?) 
	  name1 = PWA::ParIDs.name(id1)
	  next unless matches_exprs?(name1,[@reg_exprs[r][0]])
	  match1,mean1,min1,max1,title1 = *(bin_info(name1))	
	  val2 = nil
	  err2_2 = nil
	  pars.each_index{|id2|
	    next if(pars[id2].nil?) 
	    name2 = PWA::ParIDs.name(id2)
	    next unless matches_exprs?(name2,[@reg_exprs[r][1]])
	    match2,mean2,min2,max2,title2 = *(bin_info(name2))	
	    next unless mean1 == mean2	    
	    val2 = pars[id2]
	    err2_2 = cov_matrix[id2,id2]
	    break
	  }
	  @diffs[r] = [] if(@diffs[r].nil?)
	  @errs[r] = [] if(@errs[r].nil?)
	  @diffs[r].push [mean1,pars[id1] - val2]
	  @errs[r].push [mean1,Math.sqrt(err2_2 + cov_matrix[id1,id1])]
	  break
	}
      }
    end
    #
    # Produce any final plots. This class produces the parameter diff graphs
    # here.
    #
    def plot
      multi_graph = TMultiGraph.new
      legend = TLegend.new 0.6,0.6,0.9,0.9
      legend.SetHeader 'Phase Diffs'
      color = 1
      @reg_exprs.each_index{|r|
	w = @diffs[r].collect{|x| x[0]}
	diffs = @diffs[r].collect{|x| x[1]}
	errs = @errs[r].collect{|x| x[1]}
	# force b/t 0 and pi/2
	diffs.each_index{|d|
	  while(diffs[d] < 0) 
	    diffs[d] += Math::PI
	  end
	  while(diffs[d] > Math::PI)
	    diffs[d] -= Math::PI
	  end
#	  while(diffs[d] > Math::PI/2.0)
#	    diffs[d] -= Math::PI/2.0
#	  end
	}
	gr = TGraphErrors.new(w.length,w,diffs,Array.new(w.length,0),errs)
	gr.SetMarkerStyle 20
	gr.SetMarkerColor color
	multi_graph.Add gr
	@graphs.push gr
	label = "#{@reg_exprs[r][0]} - #{@reg_exprs[r][1]}"
	legend.AddEntry(gr,label,'p')
	color += 1
      }      
      return nil if(@graphs.length == 0)
      #
      multi_graph.Draw 'ap' 
      legend.Draw
    end
    #
    # Run TApplication? (always true for Params)
    #
    def run_app?; true; end
    #
    # Write graphs to current ROOT file.
    #
    def write ;@graphs.each{|gr| gr.Write}; end
  end
end
