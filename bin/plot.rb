#!/usr/bin/env ruby
# Author:: Mike Williams
#
# Plots fit results (plot.rb -h for options or plot.rb -h -m ModuleName to
# also see module options).
#
require 'optparse'
require 'pwa/dataset'
require 'utils'
require 'plot/utils'
require 'plot/iteration'
require 'plot/dyields'
require 'plot/dyields2d'
require 'plot/compare'
require 'plot/params'
require 'plot/compare2d'
require 'plot/dsigma'
require 'plot/yields'
require 'plot/phase_diffs'
require 'plot/accept'
#
# The Plot module handles plotting fit results. See the list of classes 
# below for details.
#
module Plot ; end
include Plot
#
# parse command line
#
options = {}
cmdline = OptionParser.new
cmdline.banner = 'Usage: plot.rb [...options...] file1.xml file2.xml ...'
cmdline.separator 'Modules: Compare,DYields,DYields2D,Params'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('-x','--load file',String,'EXTRA load file'){|opt| 
  require opt
}
cmdline.on('-c','--ctrl file',String,'Fit control file'){|opt| options[:c]=opt}
cmdline.on('-b min-max,min-max,...',Array,'Only use bins in range'){ |opt| 
  $bin_ranges = []
  opt.each{|range|  
    min = range.split('-')[0].to_i
    max = range.split('-')[1].to_i
    $bin_ranges.push [min,max]
  }
  $bin_ranges.sort!
  options[:b] = $bin_ranges
}
cmdline.on('--batch',String,'Run in (charlie) batch mode'){
  options[:batch] = true
}
cmdline.on('-m Module',String,'Plot module'){|opt| options[:m] = opt}
cmdline.on('-o file',String,'Output ROOT file name'){|opt| options[:o] = opt}
cmdline.on('-i #',String,'Plot specific iteration (default is best)'){|opt|
  options[:i] = opt.to_i
}
cmdline.on('--all','Plot all iterations'){|opt| options[:all] = true}
cmdline.on('--sort-iterations','Sort the iterations likelihood (best=0)'){|opt|
  options[:sort_iterations] = true
}
extra_ind = ARGV.index('-x')
require "#{ARGV[extra_ind+1]}" unless extra_ind.nil?
mod_ind = ARGV.index('-m')
eval "#{ARGV[mod_ind+1]}.add_args(cmdline,options)" unless mod_ind.nil?
xml_files = parse_args(cmdline,ARGV).sort
require_options(cmdline,options,[:c])
init_ruby_root
plot_module = nil
plot_module = eval "Plot::#{options[:m]}.new(options)" unless options[:m].nil?
out_file = TFile.new(options[:o],'recreate') unless options[:o].nil?
#
# These arrays will hold the log likelihood info
#
xaxis = Array.new
yaxis = Array.new
#
# process XML files
#
print_line(':')
xml_files.each{|file|  
  m,wlo,whi = *(file.match(/(\d+)-(\d+).xml/))
  wval = (wlo.to_f + whi.to_f)/2.0
  print "processing #{file}..."; STDOUT.flush
  Iteration.set(file)
  if ( options[:sort_iterations] )
    Iteration.sort!
  end
  iter = Iteration.best
  iter = Iteration[options[:i]] unless(options[:i].nil?)
  $bin_ranges = iter.bin_ranges if(options[:b].nil?)
  PWA::ParIDs.set(iter.names2ids)
  load options[:c]
  if(options[:all].nil?)
    iter.set_angles
    xaxis.push(wval) # Grab this for the logL graph
    yaxis.push(iter.fcn_min)
    plot_module.make_plots(iter.pars,iter.cov_matrix) unless plot_module.nil?
  else
    Iteration.each{|iter|
      iter.set_angles
      xaxis.push(wval) # Grab this for the logL graph
      yaxis.push(iter.fcn_min)
      plot_module.make_plots(iter.pars,iter.cov_matrix) unless plot_module.nil?
    }
  end
  PWA::Dataset.clear
  puts 'done'
}
gr_logL = TGraph.new(xaxis.length, xaxis, yaxis)
gr_logL.SetName("gr_logL")
unless plot_module.nil?
  plot_module.plot 
else
  # if no module is plotted, display the -ln(L) plot
  canvas = ::TCanvas.new("yields_canvas",'',25,25,500,500)
  gr_logL.SetTitle 'fcn-min'
  gr_logL.SetMarkerStyle 20
  gr_logL.Draw('ap')
end
print_line(':')
## Write both
#plot_module.write unless options[:o].nil?
if(!options[:o].nil?) 
  gr_logL.Write
  plot_module.write unless plot_module.nil?
end
#
if options[:batch].nil?
  if plot_module.nil?
    run_app
  else
    run_app if plot_module.run_app?
  end
end
