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
out_file_name = nil
kinvar_file_name = 'kinvar.xml'
reg_exprs = ['MATCH_NOTHING']
wtd = :unwtd
options = {}
cmdline.banner = 'Usage: checkamps.rb [...options...] top_dir'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('--batch',String,'Run in (charlie) batch mode'){
  options[:batch] = true
}
cmdline.on('--coherence tag1,tag2,...',Array,'Coherence tags'){|opt|
  coh_tags = opt
}
cmdline.on('-k KV',String,'Kinvar to plot vs'){|opt| kinvar = opt}
cmdline.on('-c FILE',String,'Cuts file name'){|opt| cuts_file_name = opt}
cmdline.on('-r REGEX1,REGEX2,...',Array,'Use .amps files matcning these'){
  |opt| reg_exprs = opt
  wtd = '.'
}
cmdline.on('-o FILE',String,'Output ROOT file'){|opt| out_file_name = opt}
top_dir = parse_args(cmdline,ARGV)[0]
type = :data
type = :acc if(top_dir.include?('/acc/'))
type = :raw if(top_dir.include?('/raw/'))
#
# build fake fit
#

h = nil
h = Array(104)
out_file = TFile.new(out_file_name,'recreate') unless(out_file_name.nil?)


min = nil
max = nil
dir = nil


init_ruby_root
canvas = TCanvas.new('c','',25,25,500,500)
canvas.Divide(11,10)

104.times{|i|
min = 1800 + 10*i
max = 1810 + 10*i

dir = "#{top_dir}/Wbin#{min}-#{max}/"

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
#init_ruby_root
$bin_ranges = [[min,max]]
require 'view/dummy_methods.rb'
require './dataset=dummy.rb'

PWA::Dataset.each{|dataset|
  dataset.read_in_amps(0,type) unless(wtd == :unwtd)
  title,num_bins,min,max,bins = dataset.histo_bins(kinvar,[],wtd,type)
  h[i] = TH1F.new("h#{i}",title,num_bins,min,max)
  bins.each_index{|b| h[i].SetBinContent(b+1,bins[b])}
}
canvas.cd(i+1)

h[i].SetMarkerColor 2
h[i].SetMarkerStyle 20
h[i].SetMinimum 0
h[i].Draw 'p'
puts "Processing #{dir}..."
}

#out_file.Write unless(out_file_name.nil?)
#
# remove the files
#
system 'rm -f dataset=dummy.rb fit.ctrl.rb  params.rb' 
#run_app
run_app if(options[:batch].nil?)
