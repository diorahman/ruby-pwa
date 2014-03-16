#!/usr/bin/env ruby
# Author:: Mike Williams
require 'optparse'
require 'pwa/dataset'
require 'utils'
require 'plot/utils'
#
# parse command line
#
cmdline = OptionParser.new
coh_tags,cuts_file_name = [],nil
kinvar = nil
logoption = nil
out_file_name = nil
kinvar_file_name = 'kinvar.xml'
reg_exprs = ['MATCH_NOTHING']
wtd = :unwtd
options = {}
cmdline.banner = 'Usage: view.rb [...options...] dir'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('--batch',String,'Run in (charlie) batch mode'){
  options[:batch] = true
}
cmdline.on('--coherence tag1,tag2,...',Array,'Coherence tags'){|opt|
  coh_tags = opt
}
#cmdline.on('-k KV',String,'Kinvar to plot vs'){|opt| kinvar = opt}
cmdline.on('-k KV',Array,'Kinvars to plot against'){|kv| 
  if(kv.length != 2)
    raise "Wrong number of kinvars: #{kv.length} instead of 2"
  end
  options[:k] = kv.collect{|k| k.to_sym}
}
cmdline.on('-c FILE',String,'Cuts file name'){|opt| cuts_file_name = opt}
cmdline.on('-r REGEX1,REGEX2,...',Array,'Use .amps files matcning these'){
  |opt| reg_exprs = opt
  wtd = '.'
}
cmdline.on('-o FILE',String,'Output ROOT file'){|opt| out_file_name = opt}
cmdline.on('--log','Plot on log scale'){logoption = true}

dir = Dir.pwd
dir_passed = parse_args(cmdline,ARGV)[0]
dir = dir_passed unless(dir_passed.nil?)
type = :data
type = :acc if(dir.include?('/acc/'))
type = :raw if(dir.include?('/raw/'))

#
# build fake fit
#
require 'create.rb'
require 'view/dummy_rules'
Create.dataset('dummy',:evt){|dataset|
  dataset.coherence_tags = coh_tags
  dataset.read_amps_from dir
  dataset.use_amps_matching reg_exprs
  dataset.cuts[type] = cuts_file_name
  dataset.kinvar[type] = kinvar_file_name
}
Create.fit Dir.pwd
#
# get the fake dataset
# 
init_ruby_root
out_file = TFile.new(out_file_name,'recreate') unless(out_file_name.nil?)
match,min,max = *(dir.match(/Wbin(\d+)-(\d+)/))
$bin_ranges = [[min.to_i,max.to_i]]
require 'view/dummy_methods.rb'
require './dataset=dummy.rb'
h = nil
title = nil
PWA::Dataset.each{|dataset|
  dataset.read_in_amps(0,type) unless(wtd == :unwtd)
  title,num_bins,min,max,bins = dataset.histo_bins(options[:k],[],wtd,type)
  h = TH2F.new('h','',num_bins[0],min[0],max[0],num_bins[1],min[1],max[1])
  bins.each_index{|i|
    bins[i].each_index{|j| h.SetBinContent(i+1,j+1,bins[i][j])}
  }
}
#
# draw it
#
canvas = TCanvas.new('c','',25,25,500,500)
gPad.SetLogz if (logoption == true)
canvas.cd
h.GetXaxis.SetTitle title[0]
h.GetYaxis.SetTitle title[1]            
h.SetMarkerColor 2
h.SetMarkerStyle 20
h.SetMinimum 0
h.Draw 'colz'
out_file.Write unless(out_file_name.nil?)
#
# remove the files
#
system 'rm -f dataset=dummy.rb fit.ctrl.rb  params.rb' 
#run_app
run_app if(options[:batch].nil?)
