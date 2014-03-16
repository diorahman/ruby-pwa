module Plot
  #
  # The Plot::Yields class plots yields.
  #
  class Yields
    #
    # Regular expressions to match against amps file names to plot yields for.
    #
    attr_accessor :reg_exprs
    #
    # Array of ROOT TCanvas's produced
    #
    attr_reader :canvases
    #
    # Array of ROOT TGraphs produced
    #
    attr_reader :graphs
    #
    # Array of ROOT TH1Fs produced
    #
    attr_reader :histos
    #
    # Type of yield (defaults to raw)
    #
    attr_accessor :type
    #
    # Add Yields command line arguments to _cmdline_
    #
    def Yields.add_args(cmdline,options)
      cmdline.separator 'Plot::Yields options:'
      cmdline.on('-f reg-ex1,reg-ex2,...',Array,
                 'Use files matching these reg-exps'){|reg_ary|
	options[:f] = reg_ary
      }
      cmdline.on('--acc','Plot accepted yields'){options[:acc] = true}
      cmdline.on('--likelihood','Plot the likelihood value for this iteration'){options[:likelihood] = true}
      cmdline.on('--log','Plot on log scale'){options[:log] = true}
    end
    #   
    # Initialize using _options_ Hash.
    #
    def initialize(options)
      @reg_exprs,@canvases,@graphs,@histos = [],[],[],[]
      @reg_exprs = options[:f]
      @log = options[:log]
      @likelihood = options[:likelihood]
      @bins = []
      @yields = Array.new(@reg_exprs.length)
      @yields.each_index{|y| @yields[y] = Array.new}
      @errors = Array.new(@reg_exprs.length)
      @errors.each_index{|y| @errors[y] = Array.new}
      @type = :raw
      @type = :acc unless(options[:acc].nil?)
    end
    #
    # Make plots for MINUIT parameters _pars_ for :evt datasets
    #
    def _make_plots_evt(dataset,pars,cov_matrix)
      num_regs = @reg_exprs.length      
      dataset.read_in_norm(@type,PWA::ParIDs.max_id)        
      @bins.push(bin_info(dataset.name)[1])
      @reg_exprs.each_index{|r| 
	y,e = *(dataset.calc_yield_and_error(pars,cov_matrix,@reg_exprs[r],@type))
	@yields[r].push y
	@errors[r].push e
      }
    end
    #
    # Make plots for MINUIT parameters _pars_ for :dcs datasets
    #
    def _make_plots_dcs(dataset,pars,cov_matrix)
      num_regs = @reg_exprs.length 
      x_width,x_num = 0.0,0
      dataset.read_in_t_values
      dataset.read_in_amps(PWA::ParIDs.max_id)
      @kv = "t".to_sym
      @bins.push(bin_info(dataset.name)[1])  
      @reg_exprs.each_index{|r|
	x,y,xerr,yerr = *(dataset.graph_pts_calc(@kv,pars,cov_matrix,
						 @reg_exprs[r]))
	x_width = (x[2].to_f - x[3].to_f).abs
	sum = 0.0
	x.each_index{|d|; sum += y[d] * x_width	}
	err_sum = 0.0
	x.each_index{|d| err_sum += (yerr[d])**2 * x_width }
	@yields[r].push(sum)
	@errors[r].push(Math::sqrt(err_sum))
      }
    end
    #
    # Make plots for MINUIT parameters _pars_.
    #
    def make_plots(pars,cov_matrix)
      PWA::Dataset.each{|dataset|
	if dataset.type == :evt
	  self._make_plots_evt(dataset,pars,cov_matrix)
	elsif dataset.type == :dcs
	  self._make_plots_dcs(dataset,pars,cov_matrix)
	end
      }
    end
    #
    # draw it
    #
    def plot 
      @canvases.push ::TCanvas.new("yields_canvas",'',25,25,500,500) 
      legend = TLegend.new 0.7,0.7,1.0,1.0
      @canvases.last.cd
      multi_graph = TMultiGraph.new
      @reg_exprs.each_index{|r|
	n = @bins.length
	xerr = Array.new(n,0)
	gr = TGraphErrors.new(n,@bins,@yields[r],xerr,@errors[r])
        @graphs.push(gr)
	@graphs.last.SetName "gr_#{@reg_exprs[r]}"
        @graphs.last.SetTitle "Yields"
        @graphs.last.SetMarkerStyle 20
        @graphs.last.SetMarkerColor(1+r)
        legend.AddEntry(@graphs.last,@reg_exprs[r],'p')
        multi_graph.Add @graphs.last
      }
      multi_graph.Draw 'ap' 
      legend.Draw
      gPad.Update 
    end
    #
    # Run TApplication?
    #
    def run_app?; @canvases.length > 0; end
    #
    # Write all graphs and histograms produced to current ROOT file.
    #
    def write 
      @graphs.each{|gr| gr.Write} 
      @histos.each{|h| h.Write}
    end
  end
end
