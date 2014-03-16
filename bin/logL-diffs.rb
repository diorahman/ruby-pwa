#!/usr/bin/env ruby
require 'optparse'
require 'utils'
require 'plot/utils'
require 'plot/iteration'
#
# parse command line
#
out_file_name = nil
batch_mode = false
cmdline = OptionParser.new
cmdline.banner = 'Usage: logL-diffs.rb [...options...] fit_dir1 fit_dir2'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('-o FILE',String,'Output ROOT File'){|opt| out_file_name = opt}
cmdline.on('-b','Run in (Charlie) batch mode'){batch_mode = true}
dirs = cmdline.parse(ARGV)
logL_diffs = []
x = []
Dir.entries(dirs[0]).each{|xml_file|
  next unless(xml_file.include?('.xml'))
  next unless(Dir.entries(dirs[1]).include?(xml_file))
  match,min,max = *(xml_file.match(/(\d+)-(\d+)/))
  next if(match.nil? or match == false)
  x.push((min.to_f + max.to_f)/2.0)
  Plot::Iteration.set("#{dirs[0]}/#{xml_file}")
  min0 = Plot::Iteration.best.fcn_min
  Plot::Iteration.set("#{dirs[1]}/#{xml_file}")
  min1 = Plot::Iteration.best.fcn_min
  logL_diffs.push(min0 - min1)
}
init_ruby_root
canvas = TCanvas.new('c','',25,25,600,500).cd
canvas.SetBorderMode 0
canvas.SetFillColor 10
canvas.SetLeftMargin 0.15
out_file = TFile.new(out_file_name,'recreate') unless(out_file_name.nil?)
gr = TGraph.new(x.length,x,logL_diffs)
gr.SetName 'dlogL'
gr.SetMarkerStyle 20
gr.SetTitle ''
gr.Write unless(out_file_name.nil?)
gr.Draw 'ap'
#
run_app unless(batch_mode)
