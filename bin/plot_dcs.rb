#!/usr/bin/env ruby
# Author:: Mike Williams
#
# Plots differential cross sections from XML files.
#
require 'optparse'
require 'pwa/dataset'
require 'utils'
require 'plot/utils'
#
# parse command line
#
options = {:x => 'dcs.xml',:b => []}
cmdline = OptionParser.new
cmdline.banner = 'Usage: plot_dcs.rb [...options...] top_dir'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('-x dcs-file',String,'Dcs XML file (default = dcs.xml)'){|opt|
  options[:x] = opt
}
cmdline.on('-k KV',String,'Kinvar to plot against'){|opt| 
  options[:k] = opt.to_sym
}
cmdline.on('--log','Plot on log scale'){options[:log] = true}
cmdline.on('-b min-max,min-max,...',Array,'Only use bins in range'){|opt| 
  bin_ranges = []
  opt.each{|range|  
    min = range.split('-')[0].to_i
    max = range.split('-')[1].to_i
    bin_ranges.push [min,max]
  }
  bin_ranges.sort!
  options[:b] = bin_ranges
}
top_dir = cmdline.parse(ARGV)[0]
init_ruby_root
#
# Build Array's of points to plot
#
dataset = PWA::Dataset.new('',:dcs)
dataset.dcs_file = options[:x]
w_ary,kv_ary,dcs_ary,gr_ary = [],[],[],[]
min,max = 1e30,0
bin_list(top_dir,options[:b]).each{|bin|
  dataset.top_dir = "#{top_dir}/#{bin}"
  dataset.read_in_dcs
  x_ary,y_ary = [],[]
  dataset.dcs_pts.each{|pt|
    w_ary.push(bin_info(bin)[1]/1000.0)
    kv_ary.push pt.vars[options[:k]]
    x_ary.push kv_ary.last
    dcs_ary.push pt.cs
    y_ary.push dcs_ary.last
    max = pt.cs if(pt.cs > max)
    min = pt.cs if(pt.cs < min)
  }
  gr_ary.push TGraph.new(x_ary.length,x_ary,y_ary)
  gr_ary.last.SetTitle ''
  gr_ary.last.SetMarkerStyle(20)
  gr_ary.last.SetMinimum 0 unless options[:log]
}
#
# Plot stuff
#
c = TCanvas.new('canvas1','',25,25,500,500)
divide_canvas(c,gr_ary.length)
c.cd
gr_ary.each_index{|i| c.cd(i+1); gPad.SetLogy if options[:log]; gr_ary[i].Draw('ap')}
#
TCanvas.new('canvas2','',50,50,500,500).cd
gPad.SetRightMargin 0.15
gPad.SetLeftMargin 0.15
gPad.SetLogz if options[:log]
gr = TGraph2D.new(dcs_ary.length,w_ary,kv_ary,dcs_ary)
gr.SetTitle ''
gr.GetYaxis.SetTitle "#frac{d#sigma}{d#{options[:k]}}"
gr.GetYaxis.SetTitleOffset 1.5
gr.GetXaxis.SetTitle options[:k]
gr.Draw 'cont4z'
#
run_app
