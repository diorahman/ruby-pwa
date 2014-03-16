module Plot
  #
  # The Plot::Params class plots MINUIT parameters.
  #
  class Params
    #
    # Regular expressions to match to parameter names
    #
    attr_accessor :reg_exprs
    #
    # ROOT TCanvas produced
    #
    attr_reader :canvas
    #
    # Array of ROOT TGraphs for each parameter
    #
    attr_reader :graphs
    #
    # Add Params command line arguments to _cmdline_
    #
    def Params.add_args(cmdline,options)
      cmdline.separator 'Plot::Params options:'
      cmdline.on('--par reg-ex1,reg-ex2,...',Array,
                 'Use parameters these reg-exps'){|reg_ary|
	options[:par] = reg_ary
      }
      cmdline.on('--abs','Plot absolute values'){options[:abs] = true}
    end
    #   
    # Initialize using _options_ Hash.
    #
    def initialize(options)
      @graphs = []
      @reg_exprs = options[:par]
      @abs = options[:abs]
      @binned_pars = {}
      @unbinned_pars = {}
      @canvas = ::TCanvas.new('params_canvas','',25,25,500,500)
    end
    #
    # Produce plots for MINUIT parameters _pars_. This class simply files 
    # Arrays of the parameter values vs W that need plotted.
    #
    def make_plots(pars,cov_matrix)
      pars.each_index{|id| 
	next if(pars[id].nil?) 
	name = PWA::ParIDs.name(id)
	next unless matches_exprs?(name,@reg_exprs)
	match,mean,min,max,title = *(bin_info(name))	
	handle = name
	handle = name.sub(":#{match}",'') unless match.nil?
	val = pars[id]
	val = pars[id].abs if @abs
	err = Math.sqrt(cov_matrix[id,id])
	if(match.nil?) 
	  @unbinned_pars[handle] = val
	else 
	  @binned_pars[handle] = [] if(@binned_pars[handle].nil?)
	  @binned_pars[handle].push [mean,val,err] 
	end	
      }
    end
    #
    # Produce any final plots. This class produces the parameter value graphs
    # here.
    #
    def plot
      multi_graph = TMultiGraph.new
      legend = TLegend.new 0.6,0.6,0.9,0.9
      legend.SetHeader 'MINUIT Parameters'
      color = 1
      @binned_pars.each{|handle,par|
	next if(par.length == 0)
	w   = par.collect{|x| x[0]}
	val = par.collect{|x| x[1]}
	err = par.collect{|x| x[2]}
	gr = TGraphErrors.new(w.length,w,val,Array.new(w.length,0),err)
	gr.SetName "gr_#{handle}"
	gr.SetMarkerStyle 20
	gr.SetMarkerColor color
	multi_graph.Add gr
	@graphs.push gr
	legend.AddEntry(gr,handle,'p')
	color += 1
      }      
      return nil if(@graphs.length == 0)
      #
      multi_graph.Draw 'ap' 
      xmax = multi_graph.GetXaxis.GetXmax
      xmin = multi_graph.GetXaxis.GetXmin
      color = 1
      #
      @unbinned_pars.each{|handle,par|	
	line = TLine.new(xmin,par,xmax,par)
	line.SetLineColor color
	legend.AddEntry(line,handle,'l')
	line.Draw 'same'
	color += 1
      }
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
