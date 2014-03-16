#!/usr/bin/env ruby
# Author:: Mike Williams
#
# Dumps event weights to screen 
#
require 'optparse'
require 'pwa/dataset'
require 'utils'
require 'plot/utils'
require 'plot/iteration'
#
# parse command line
#
#options = {:type => :acc}
options = {}
cmdline = OptionParser.new
cmdline.banner = 'Usage: plot.rb [...options...] file.xml'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('-c','--ctrl FILE',String,'Fit control file'){|opt| options[:c]=opt}
cmdline.on('-d DATASET',String,'Dataset (defaults to 1st found)'){|opt|
  options[:d] = opt
}
cmdline.on('-i #',String,'Plot specific iteration (default is best)'){|opt|
  options[:i] = opt.to_i
}
cmdline.on('-t','--type (acc,raw)',String,'type (acc,raw)'){|opt| 
  options[:type] = :acc if opt == "acc"
  options[:type] = :raw if opt == "raw"
}
xml_file = cmdline.parse(ARGV)[0]
#
# get weights
#
Plot::Iteration.set(xml_file)
Plot::Iteration.sort!
iter = Plot::Iteration.best
iter = Iteration[options[:i]] unless(options[:i].nil?)
$bin_ranges = iter.bin_ranges
PWA::ParIDs.set(iter.names2ids)
load options[:c]
PWA::Dataset.each{|dataset|
  next unless(dataset.type == :evt)
  next if(!options[:d].nil? and dataset.name != options[:d])
  dataset.read_in_amps(PWA::ParIDs.max_id,options[:type])
  if options[:type] == :acc
    cuts = dataset.get_cuts(options[:type]) 
  elsif options[:type] == :raw
    cuts = []
    100000.times{|i|; cuts[i] = 1.0 }
  end
  num_events = dataset.get_num_events(options[:type],cuts)
  dataset.set_for_intensities(iter.pars,'.')
  intensities = []
  event = 0
  sum = 0
  cuts.each_index{|ev_index|
    if(cuts[ev_index] > 0)
      int = dataset.intensity(event)
      intensities.push int
      sum += int
      event += 1
    else
      intensities.push 0
    end
  }  

  dataset.read_in_norm(options[:type])
  y = dataset.calc_yield(iter.pars,'.',options[:type])
#  scale = y/sum
#  intensities.each{|int| puts int*scale}
  intensities.each{|int| puts int}
  break
}

