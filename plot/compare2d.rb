module Plot
  #
  # The Plot::Compare class plots comparisons b/t measurements and fit results.
  #
  #
  class Compare2D
    #
    # Kinematic variables to plot against
    #
    attr_accessor :kvs
    #
    # Extra condition for kinvar to satisfy
    #
    attr_accessor :condition
    #
    # Plot on log scale?
    #
    attr_accessor :log
    #
    # Array of ROOT TCanvas's produced
    #
    attr_reader :canvases
    #
    # Array of ROOT TH1Fs produced
    #    
    attr_reader :histos
    #
    # Add Compare2D command line arguments to _cmdline_
    #
    def Compare2D.add_args(cmdline,options)
      cmdline.separator 'Plot::Compare2D options:'
      cmdline.on('-k KV',Array,'Kinvar to plot against'){|kv| 
	if(kv.length != 2)
	  raise "Wrong number of kinvars: #{kv.length} instead of 2"
	end
	options[:k] = kv.collect{|k| k.to_sym}
      }
      cmdline.on('--condition COND',String,'Extra condition (ex. [KV] > 0.4)'){
	|cond| options[:condition] = cond
      }
      cmdline.on('--log','Plot on log scale'){options[:log] = true}
    end
    #   
    # Initialize using _options_ Hash.
    #
    def initialize(options)
      @canvases,@histos = [],[]
      @kvs = options[:k]
      @log = options[:log]
      @condition = options[:condition]
    end
    #
    # Make plots for differential cross section _dataset_ (not supported).
    #
    def _make_plots_dcs(dataset,pars)
      raise 'Compare2D does not support :dcs Datasets.'
    end
    #
    # Make plots for event-based _dataset_.
    #
    def _make_plots_evt(dataset,pars)
      cind = @canvases.length
      canvas =  ::TCanvas.new("compare_canvas_#{cind}",'',25 + 50*cind,
			      25,500,500)
      canvas.Divide(2,2)      
      canvas.cd(1)
      dataset.read_in_amps(PWA::ParIDs.max_id,:acc)
      dname = dataset.name
      # data
      title,num_bins,min,max,bins = dataset.histo_bins(@kvs,pars,:unwtd,:data,@condition)
      h_data = TH2F.new("h_#{dataset.name}_data",'data',num_bins[0],min[0],
			max[0],num_bins[1],min[1],max[1])
      bins.each_index{|i| 
	bins[i].each_index{|j| h_data.SetBinContent(i+1,j+1,bins[i][j])}
      }
      h_data.GetXaxis.SetTitle title[0]
      h_data.GetYaxis.SetTitle title[1]
      h_data.Draw 'colz'
      data_integral = h_data.Integral
      data_min = h_data.GetMinimum
      data_max = h_data.GetMaximum
      @histos.push h_data
      gPad.Update
      # acc 
      canvas.cd(2)
      title,num_bins,min,max,bins = dataset.histo_bins(@kvs,pars,:unwtd,:acc,@condition)
      h_acc = TH2F.new("h_#{dataset.name}_acc",'acc(unwtd)',num_bins[0],min[0],
		       max[0],num_bins[1],min[1],max[1])
      bins.each_index{|i| 
	bins[i].each_index{|j| h_acc.SetBinContent(i+1,j+1,bins[i][j])}
      }
      h_acc.GetXaxis.SetTitle title[0]
      h_acc.GetYaxis.SetTitle title[1]
      acc_integral = h_acc.Integral
      h_acc.Scale(data_integral/acc_integral) if(acc_integral > 0)
      h_acc.SetMinimum data_min
      h_acc.SetMaximum data_max
      h_acc.Draw 'colz'      
      @histos.push h_acc
      gPad.Update
      # wtd acc
      canvas.cd 3
      dataset.read_in_norm(:acc)
      y = dataset.calc_yield(pars,'.',:acc)
      title,num_bins,min,max,bins = dataset.histo_bins(@kvs,pars,'.',:acc,@condition)
      h_acc_wt = TH2F.new("h_#{dataset.name}_acc_wt",'acc(wtd)',num_bins[0],
			  min[0],max[0],num_bins[1],min[1],max[1])
      bins.each_index{|i| 
	bins[i].each_index{|j| h_acc_wt.SetBinContent(i+1,j+1,bins[i][j])}
      }
      h_acc_wt.GetXaxis.SetTitle title[0]
      h_acc_wt.GetYaxis.SetTitle title[1]
      acc_integral_wt = h_acc_wt.Integral
      h_acc_wt.Scale(y/acc_integral_wt) if(acc_integral_wt > 0)
      h_acc_wt.SetMinimum data_min
      h_acc_wt.SetMaximum data_max
      h_acc_wt.Draw 'colz'      
      @histos.push h_acc_wt
      gPad.Update
      # chi^2 
      canvas.cd 4
      h_chi2 = TH2F.new("h_#{dataset.name}_chi2",'#chi^{2}',num_bins[0],min[0],
			max[0],num_bins[1],min[1],max[1])
      h_chi2.GetXaxis.SetTitle title[0]
      h_chi2.GetYaxis.SetTitle title[1]
      1.upto(bins.length){|i|
	1.upto(bins[i-1].length){|j|
	  data = h_data.GetBinContent(i,j)
	  derr = h_data.GetBinError(i,j)
	  acc = h_acc_wt.GetBinContent(i,j)
	  aerr = h_acc_wt.GetBinError(i,j)
	  if(aerr > 0 and derr > 0)
	    chi2 = ((data-acc)**2)/(aerr**2 + derr**2)
	    chi2 *= -1 if(acc > data)
	    h_chi2.SetBinContent(i,j,chi2)
	  end
	}
      }
      h_chi2.Draw 'colz'      
      @histos.push h_chi2
      gPad.Update
      #
      canvas.cd
      @canvases.push canvas
    end
    protected :_make_plots_evt
    #
    # Make plots for MINUIT parameters _pars_.
    #
    def make_plots(pars,cov_matrix)
      PWA::Dataset.each{|dataset|
	if(dataset.type == :dcs)
	  self._make_plots_dcs(dataset,pars)
	else
	  self._make_plots_evt(dataset,pars)
	end
      }
    end
    #
    # Produce any final plots. (nada para esto module)
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
      @histos.each{|h| h.Write}
    end
  end
end
