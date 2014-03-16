module Plot
  #
  # The Plot::DYields class plots differential yields.
  #
  class DYields
    #
    # Kinematic variable to plot against
    #
    attr_accessor :kv
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
    # Add DYields command line arguments to _cmdline_
    #
    def DYields.add_args(cmdline,options)
      cmdline.separator 'Plot::DYields options:'
      cmdline.on('-k KV',String,'Kinvar to plot against'){|kv| 
	options[:k] = kv.to_sym
      }
      cmdline.on('-f reg-ex1,reg-ex2,...',Array,
                 'Use files matching these reg-exps'){|reg_ary|
	options[:f] = reg_ary
      }
      cmdline.on('--log','Plot on log scale'){options[:log] = true}
    end
    #   
    # Initialize using _options_ Hash.
    #
    def initialize(options)
      @reg_exprs,@canvases,@graphs,@histos = [],[],[],[]
      @kv = options[:k]
      @reg_exprs = options[:f]
      @log = options[:log]
    end
    #
    # Make plots for differential cross section _dataset_.
    #
    def _make_plots_dcs(dataset,pars,cov_matrix,canvas)
      canvas.cd
      gPad.SetLogy if @log
      dataset.read_in_dcs
      dataset.read_in_amps(PWA::ParIDs.max_id)
      legend = TLegend.new 0.7,0.7,1.0,1.0
      x,y,xerr,yerr = *(dataset.graph_pts_meas(@kv))
      gr_m = TGraphErrors.new(x.length,x,y,xerr,yerr)
      gr_m.SetName "gr_#{dataset.name}_meas"
      gr_m.SetTitle(dataset.name)
      gr_m.SetMarkerStyle(20)
      gr_m.Draw('ap')
      @graphs.push gr_m
      legend.AddEntry(gr_m,'measured','p')
      gPad.Update
      #
      @reg_exprs.each_index{|r|
	x,y,xerr,yerr = *(dataset.graph_pts_calc(@kv,pars,cov_matrix,
						 @reg_exprs[r]))
	gr = TGraphErrors.new(x.length,x,y,xerr,yerr)
	gr.SetName "gr_#{dataset.name}_#{@reg_exprs[r]}"
	gr.SetMarkerStyle(22)
	color = r+2
	if color==10 then color = 50 end
	gr.SetMarkerColor(color)
	gr.Draw('psame')
	gPad.Update
	@graphs.push gr
	legend.AddEntry(gr,@reg_exprs[r],'p')
      }
      gr_m.Draw('psame')
      legend.Draw
      gPad.Update
    end
    protected :_make_plots_dcs
    #
    # Make plots for event-based _dataset_.
    #
    def _make_plots_evt(dataset,pars,canvas)
      canvas.cd
      gPad.SetLogy if @log
      dataset.read_in_amps(PWA::ParIDs.max_id,:raw)
      dataset.read_in_norm(:raw)
      legend = TLegend.new 0.7,0.7,1.0,1.0
      @reg_exprs.each_index{|r|	
	title,num_bins,min,max,bins = dataset.histo_bins(@kv,pars,
							 @reg_exprs[r],:raw)
	h = TH1F.new("h_#{dataset.name}_#{reg_exprs[r]}",
		     title,num_bins,min,max)
	bins.each_index{|b| h.SetBinContent(b+1,bins[b])}
	integral = h.Integral
	if(integral > 0)	  
	  scale = dataset.calc_yield(pars,@reg_exprs[r],:raw)/integral
	  scale *= num_bins/(max-min)	  
	  h.Scale scale
	end	
	h.SetMinimum 0 unless @log
	h.SetMarkerColor(r+1)
	h.SetMarkerStyle(20)
	option = 'psame'
	option = 'p' if (r == 0)
	h.Draw option
	@histos.push h
	legend.AddEntry(h,@reg_exprs[r],'p')
	gPad.Update
      }
      legend.Draw
      gPad.Update      
    end
    protected :_make_plots_evt
    #
    # Make plots for MINUIT parameters _pars_.
    #
    def make_plots(pars,cov_matrix)
      PWA::Dataset.each{|dataset|
        cind = @canvases.length
	if(dataset.type == :dcs or dataset.type == :evt)
	  @canvases.push ::TCanvas.new("dyields_canvas_#{cind}",'',
				       25 + 50*cind,25,500,500)
	end
	if(dataset.type == :dcs) 
	  self._make_plots_dcs(dataset,pars,cov_matrix,@canvases.last)
	elsif(dataset.type == :evt)
	  self._make_plots_evt(dataset,pars,@canvases.last)
	end
      }
    end
    #
    # Does nothing.
    #
    def plot; end
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
