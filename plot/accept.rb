module Plot
  #
  # The Plot::Acceptance class plots physics acceptance
  #
  class Acceptance
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
    # Add Acceptance command line arguments to _cmdline_
    #
    def Acceptance.add_args(cmdline,options)
      cmdline.separator 'Plot::Acceptance options:'
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
        @canvases.push ::TCanvas.new("acceptance_canvas_#{cind}",'',25 + 50*cind,
                                     25,500,500)
	@canvases.last.cd
	gPad.SetLogy if @log
	name = "#{dataset.name}_#{@kv}"
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
	#h_acc.Scale(acc_yield/integral) if(integral > 0)
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
	#h_raw.Scale(raw_yield/integral) if(integral > 0)
  #
	# get weighted acceptance
	#
  h_acc.Divide(h_raw)
  @histos.push h_acc
  wbin = *(dataset.name.match(/Wbin\d+-\d+/))
  title = wbin
  h_acc.SetTitle title
  h_acc.SetName "h_acceptance_#{name}_#{wbin}"
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
