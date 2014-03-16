module Plot
  #
  # The Plot::Compare class plots comparisons b/t measurements and fit results.
  #
  #
  class Compare
    #
    # Kinematic variable to plot against
    #
    attr_accessor :kv
    #
    # Plot on log scale?
    #
    attr_accessor :log
    # Plot only the weighted acc (to save time)
    #
    attr_accessor :only_wt_acc
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
    # Add Compare command line arguments to _cmdline_
    #
    def Compare.add_args(cmdline,options)
      cmdline.separator 'Plot::Compare options:'
      cmdline.on('-k KV',String,'Kinvar to plot against'){|kv| 
	options[:k] = kv.to_sym
      }
      cmdline.on('--log','Plot on log scale'){options[:log] = true}
      cmdline.on('--only-wt-acc','Plot only the weighted acc for event fits.'){options[:only_wt_acc] = true}
    end
    #   
    # Initialize using _options_ Hash.
    #
    def initialize(options)
      @canvases,@graphs,@histos = [],[],[]
      @kv = options[:k]
      @log = options[:log]
      @only_wt_acc = options[:only_wt_acc]
    end
    #
    # Make plots for differential cross section _dataset_.
    #
    def _make_plots_dcs(dataset,pars,cov_matrix)
      cind = @canvases.length
      canvas =  ::TCanvas.new("compare_canvas_#{cind}",'',25 + 50*cind,
			      25,500,800)
      canvas.cd
      dataset.read_in_dcs
      dataset.read_in_amps(PWA::ParIDs.max_id)
      canvas.Divide(1,3)	
      canvas.cd(1)
      gPad.SetLogy if @log
      xm,ym,xerrm,yerrm = *(dataset.graph_pts_meas(@kv))
      gr_m = TGraphErrors.new(xm.length,xm,ym,xerrm,yerrm)
      gr_m.SetTitle(dataset.name)
      gr_m.SetMarkerStyle(20)
      gr_m.Draw('ap')
      @graphs.push gr_m
      gPad.Update
      xc,yc,xerrc,yerrc = *(dataset.graph_pts_calc(@kv,pars,cov_matrix,'.'))
      gr_c = TGraph.new(xc.length,xc,yc)
      gr_c.SetMarkerStyle(22)
      gr_c.SetMarkerColor(2)
      gr_c.Draw('psame')
      gPad.Update
      @graphs.push gr_c
      gr_m.Draw('psame')
      gPad.Update
      canvas.cd(2)
      x = xm
      chi2,diff = [],[]
      chi2_tot = 0
      xm.each_index{|pt|
	diff.push Math.sqrt(ym[pt])-Math.sqrt(yc[pt])
	chi_sq = ((ym[pt]-yc[pt])**2)/(yerrm[pt]**2 - yerrc[pt]**2)
	sign = (ym[pt]-yc[pt])/((ym[pt]-yc[pt]).abs)
	chi2.push(chi_sq*sign)	  
	chi2_tot += chi_sq
	@chi2_ary.push(chi_sq*sign)
	@kv_ary.push xm[pt]
	@w_ary.push bin_info(dataset.name)[1]
      }
      gr_chi2 = TGraph.new(x.length,x,chi2)
      gr_chi2.SetTitle("#chi^{2}")
      gr_chi2.SetMarkerStyle(20)
      gr_chi2.Draw('ap')
      gPad.Update
      canvas.cd(3)
      gr_diff = TGraph.new(x.length,x,diff)
      gr_diff.SetTitle("#sqrt{meas}-#sqrt{calc}")
      gr_diff.SetMarkerStyle(20)
      gr_diff.Draw('ap')
      gPad.Update
      canvas.cd
      ndf = dataset.dcs_pts.length.to_f
      @w.push bin_info(dataset.name)[1]
      @chi2_ndf.push chi2_tot/ndf
      @canvases.push canvas
    end
    protected :_make_plots_dcs
    #
    # Make plots for event-based _dataset_.
    #
    def _make_plots_evt(dataset,pars)
      cind = @canvases.length
      canvas =  ::TCanvas.new("compare_canvas_#{cind}",'',25 + 50*cind,
			      25,500,500)
      canvas.cd
      dataset.read_in_amps(PWA::ParIDs.max_id,:acc)
      dname = dataset.name
      # data
      if ( !only_wt_acc )
        title,num_bins,min,max,bins,bin_errors = dataset.histo_bins([@kv],pars,:unwtd,:data)
        h_data = TH1F.new("h_#{dataset.name}_data",dname,num_bins,min,max)
        bins.each_index{|b| 
    h_data.SetBinContent(b+1,bins[b])
    h_data.SetBinError(b+1,bin_errors[b])
        }
        h_data.GetXaxis.SetTitle title
        h_data.SetFillColor(11)
        h_data.Draw
        data_integral = h_data.Integral
        @histos.push h_data
        gPad.Update
      end
      # unwtd acc
      if ( !only_wt_acc )
        title,num_bins,min,max,bins = dataset.histo_bins([@kv],pars,:unwtd,:acc)
        h_acc = TH1F.new("h_#{dataset.name}_acc",dname,num_bins,min,max)
        bins.each_index{|b| h_acc.SetBinContent(b+1,bins[b])}
        acc_integral = h_acc.Integral
        print "wt: data_integral:#{data_integral}\tacc_integral:#{acc_integral}\n"
        h_acc.Scale(data_integral/acc_integral) if(acc_integral > 0)
        h_acc.SetLineColor 4
        h_acc.Draw 'same'
        gPad.Update
        @histos.push h_acc
      end
      # wtd acc
      dataset.read_in_norm(:acc)
      y = dataset.calc_yield(pars,'.',:acc)
      title,num_bins,min,max,bins = dataset.histo_bins([@kv],pars,'.',:acc)
      h_acc_wt = TH1F.new("h_#{dataset.name}_acc_wt",dname,num_bins,min,max)
      if( only_wt_acc )
        h_data = TH1F.new("h_#{dataset.name}_data",dname,num_bins,min,max)
        h_acc = TH1F.new("h_#{dataset.name}_acc",dname,num_bins,min,max)
      end
      bins.each_index{|b| h_acc_wt.SetBinContent(b+1,bins[b])}
      wt_acc_integral = h_acc_wt.Integral
      print "\nwt: dataset.calc_yield:#{y}\twt_acc_integral:#{wt_acc_integral}\n"
      h_acc_wt.Scale(y/wt_acc_integral) if(wt_acc_integral > 0)
      h_acc_wt.SetLineColor 2
      h_acc_wt.Draw 'same'
      gPad.Update
      @histos.push h_acc_wt
      @canvases.push canvas
      if( !only_wt_acc )
      # chi^2
      chi2_tot = 0.0
      ndf = 0.0
      h_data.GetNbinsX.times{|b|
	xm = h_data.GetBinContent(b+1)
	em = h_data.GetBinError(b+1)
	xc = h_acc_wt.GetBinContent(b+1)
	ec = h_acc_wt.GetBinError(b+1)
	if(h_acc.GetBinContent(b+1) > 0)
	  sign = (xm-xc)/((xm-xc).abs)
	  chi_sq = ((xm-xc)**2)/(em**2 + ec**2)
	  @chi2_ary.push(chi_sq*sign)
	  @kv_ary.push xm
	  @w_ary.push bin_info(dataset.name)[1]
	  chi2_tot += chi_sq
	  ndf += 1.0
	end
      }
      @w.push bin_info(dataset.name)[1]
      @chi2_ndf.push chi2_tot/ndf
    end
    end
    protected :_make_plots_evt
    #
    # Make plots for MINUIT parameters _pars_.
    #
    def make_plots(pars,cov_matrix)
      @chi2_ary,@w_ary,@kv_ary,@chi2_ndf,@w = [],[],[],[],[]
      #
      PWA::Dataset.each{|dataset|
	if(dataset.type == :dcs)
	  self._make_plots_dcs(dataset,pars,cov_matrix)
	elsif(dataset.type == :evt)
	  self._make_plots_evt(dataset,pars)
	end
      }
    end
    #
    # Produce any final plots. This class produces chi^2 plots here.
    #
    def plot      
      if(@chi2_ndf.length > 1)
	TCanvas.new("chi2_v_W",'',50,50,600,600).cd()
	gr_chi2_v_t_w = TGraph2D.new(@chi2_ary.length,@w_ary,@kv_ary,@chi2_ary)
	gr_chi2_v_t_w.SetTitle '#chi^{2} vs t vs W'
	gr_chi2_v_t_w.Draw("contz") 
	TCanvas.new('chi2_ndf_canvas','',100,50,600,600).cd()
	gr_chi2_ndf = TGraph.new(@chi2_ndf.length,@w,@chi2_ndf)
	gr_chi2_ndf.SetTitle '#chi^{2}/pt'
	gr_chi2_ndf.SetMarkerStyle(20)
	gr_chi2_ndf.Draw 'ap' 
      end
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
