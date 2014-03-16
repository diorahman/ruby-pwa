#!/usr/bin/env ruby
# Author:: Mike Williams
#
# Runs fit.rb. Why? Mainly to make parallel running same command line as 
# regular running. But also makes it easier to switch from multi to single bin
# modes.
#
require 'optparse'
require 'utils'
#
# parse command line
#
options = Hash.new
cmdline = OptionParser.new
cmdline.banner = 'Usage: pwa_fit.rb [...options...] fit-ctrl.rb'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('-b min-max,min-max,...',Array,'Only use bins in range'){|r| 
  $bin_ranges = []
  r.each{|range|    
    min = range.split('-')[0].to_i
    max = range.split('-')[1].to_i
    $bin_ranges.push [min,max]
  }
  options[:b] = r.join(',')
} 
cmdline.on('-p #',String,'Number of processors'){|p| options[:p] = p}
cmdline.on('-i #',String,'Number of iterations'){|i| options[:i] = i}
cmdline.on('--test-derivs','Test derivatives then exit'){
  options[:test_derivs] = true
}
cmdline.on('-s','--single-bin','Run in single bin mode'){options[:s] = true}
ctrl_file = cmdline.parse(ARGV)[0]
cmd = nil
path2fit = "#{File.expand_path(File.dirname(__FILE__))}/"
if(options[:p].nil?)
  #
  # standard running
  #
  cmd = "#{path2fit}/fit.rb "  
else
  #
  # parallel running
  #
  cmd = "mpirun -np #{options[:p]} mpi_ruby #{path2fit}/fit.rb  "
end
cmd += ' --test-derivs' unless options[:test_derivs].nil?
cmd += " -b #{options[:b]}" unless options[:b].nil?
cmd += " -i #{options[:i]}" unless options[:i].nil?
cmd += " #{ctrl_file}"
if(options[:s]) # single-bin mode
  require ctrl_file
  $bin_limits.each{|limits| system "#{cmd} -b #{limits[0]}-#{limits[1]}"}
else system cmd
end
