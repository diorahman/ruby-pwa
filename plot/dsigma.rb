module Plot
  #
  # The Plot::DSigma class plots differential cross sections.
  #
  class DSigma
    #
    # Number of points
    #
    attr_accessor :num_pts
    #
    # Kinematic variable to plot against
    #
    attr_accessor :k
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
    # Add DSigma command line arguments to _cmdline_
    #
    def DSigma.add_args(cmdline,options)
      cmdline.separator 'Plot::DSigma options:'
      cmdline.on('-n NPTS',String,'Number of pts'){|n| options[:n] = n.to_i}
      cmdline.on('-k KV',String,'Kinvar to plot against'){|kv| 
	options[:k] = kv.to_sym
      }
      cmdline.on('--log','Plot on log scale'){options[:log] = true}
    end
    #   
    # Initialize using _options_ Hash.
    #
    def initialize(options)
      @canvases,@graphs,@histos = [],[],[],[]
      @kv = options[:k]
      @log = options[:log]
      @num_pts = options[:n]
    end
    #
    # Make plots for MINUIT parameters _pars_.
    #
    def make_plots(pars,cov_matrix)
      PWA::Dataset.each{|dataset|
	next unless dataset.type == :evt
	cind = @canvases.length
        @canvases.push ::TCanvas.new("dsigma_canvas_#{cind}",'',25 + 50*cind,
                                     25,500,500)
	@canvases.last.cd
	gPad.SetLogy if @log
	name = "#{dataset.name}_#{@kv}"
	#
	# data histo
	#
	title,num_bins,min,max,bins,bin_errors = dataset.histo_bins([@kv],pars,
								    :unwtd,
								    :data)
	h_data = TH1F.new("h_#{name}_data",name,num_bins,min,max)
	h_data.Sumw2
	bins.each_index{|b| 
	  h_data.SetBinContent(b+1,bins[b])
	  h_data.SetBinError(b+1,bin_errors[b])
	}
	h_data.GetXaxis.SetTitle title
	h_dsigma = TH1F.new("h_#{name}_dsigma",name,num_bins,min,max)
	h_dsigma.Sumw2
	bins.each_index{|b| 
	  h_dsigma.SetBinContent(b+1,bins[b])
	  h_dsigma.SetBinError(b+1,bin_errors[b])
	}
	h_dsigma.GetXaxis.SetTitle title
	#
	# acc histo
	#
	dataset.read_in_amps(PWA::ParIDs.max_id,:acc)
	dataset.read_in_norm(:acc)
	acc_yield = dataset.calc_yield(pars,'.',:acc)
	title,num_bins,min,max,bins,bin_errors = dataset.histo_bins([@kv],pars,'.',:acc)
	h_acc = TH1F.new("h_#{name}_acc",name,num_bins,min,max)
	h_acc.Sumw2
	bins.each_index{|b| 
	  h_acc.SetBinContent(b+1,bins[b])
	  h_acc.SetBinError(b+1,bin_errors[b])
	}
	h_acc.GetXaxis.SetTitle title
	integral = h_acc.Integral
	h_acc.Scale(acc_yield/integral) if(integral > 0)
	#
	# raw histo
	#
	dataset.read_in_amps(PWA::ParIDs.max_id,:raw)
	dataset.read_in_norm(:raw)
	raw_yield = dataset.calc_yield(pars,'.',:raw)
  title,num_bins,min,max,bins,bin_errors = dataset.histo_bins([@kv],pars,'.',:raw)
	h_raw = TH1F.new("h_#{name}_raw",name,num_bins,min,max)
	h_raw.Sumw2
	bins.each_index{|b| 
	  h_raw.SetBinContent(b+1,bins[b])
	  h_raw.SetBinError(b+1,bin_errors[b])
	}
	h_raw.GetXaxis.SetTitle title
	integral = h_raw.Integral
	h_raw.Scale(raw_yield/integral) if(integral > 0)
  #
	# get dsigma
	#
	h_dsigma.Divide(h_acc) 
	h_dsigma.Multiply(h_raw)
  @histos.push h_acc
  @histos.push h_raw
	range = max - min
	h_dsigma.Scale(num_bins/range)
        #
        # get normalization error
        #
        rel_err_norm = dataset.get_norm_rel_err
	#
	# make the graph
	#
	x,y,xerr,yerr = [],[],[],[]
	num_bins = h_dsigma.GetNbinsX
	num_pts = num_bins
	num_pts = @num_pts unless @num_pts.nil?
	num_pts.times{|p|
	  dsigma,error2,non_zero_bins,centroid = 0,0,0,0
	  (num_bins/num_pts).times{|b|
	    bin = (num_bins/num_pts)*p + b + 1
	    bin_content = h_dsigma.GetBinContent(bin)
	    bin_error = h_dsigma.GetBinError(bin)
	    next unless bin_content > 0
	    non_zero_bins += 1
	    dsigma += bin_content
	    error2 += bin_error**2
	    centroid += h_dsigma.GetBinCenter(bin)
	  }
	  next if(non_zero_bins == 0)
	  x.push centroid/non_zero_bins.to_f
	  xerr.push 0.5*non_zero_bins*(range/num_bins.to_f)
	  y.push dsigma/non_zero_bins.to_f
          err2 = error2 + (rel_err_norm*dsigma)**2
	  yerr.push Math.sqrt(err2)/non_zero_bins.to_f	  
	}
	gr_sigma = TGraphErrors.new(x.length,x,y,xerr,yerr)
	wbin = *(dataset.name.match(/Wbin\d+-\d+/))
	gr_sigma.SetName "gr_#{name}_#{wbin}"
	title = wbin
	gr_sigma.SetTitle title
	gr_sigma.SetMarkerStyle 20
	gr_sigma.Draw 'ap'
	@graphs.push gr_sigma
	gPad.Update
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
