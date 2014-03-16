#!/usr/bin/env ruby
# Author:: Mike Williams
#
# Run a PWA fit (fit.rb -h for options).
#
require 'optparse'
require 'pwa/dataset'
require 'pwa/fcn'
require 'utils'
require 'minuit'
#
# If we're running in parallel mode, only initialize MINUIT on the master node.
#
node = 0
node = PWA::Parallel.node if(parallel?)
Minuit.init(5,1,7) if(node == 0)
fcn = PWA::Fcn.instance
#
# parse the command line
#
test_derivs = false
cmdline = OptionParser.new
cmdline.banner = 'Usage: fit.rb [...options...] fit-ctrl.rb'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('-b [min-max,min-max,...]',Array,'Only use bins in range'){ |r| 
  $bin_ranges = []
  r.each{|range|  
    min = range.split('-')[0].to_i
    max = range.split('-')[1].to_i
    $bin_ranges.push [min,max]
  }
  $bin_ranges.sort!
}
cmdline.on('-i [#]',String,'Number of iterations'){|i| fcn.num_iters = i.to_i}
cmdline.on('--test-derivs','Test derivatives then exit'){test_derivs = true}
ctrl_file = cmdline.parse(ARGV)[0]
require ctrl_file
PWA::Parallel.divide if(parallel?) # divide up datasets amongst available nodes
if(node == 0) 
  #
  # Running on the master (or only if not parallel) node
  #
  PWA::Dataset.each{|dset| print_line(':'); dset.print_set_up}
  print_line(':')
  puts 'reading in amplitudes...'
  if(parallel?)
    PWA::Parallel.send_to_children(Minuit::Parameter.max_id,:max_par)
    PWA::Parallel.each_dataset_on_node{|dataset| 
      puts dataset.init_for_fit(Minuit::Parameter.max_id)
    }
    PWA::Parallel.recv_from_children(:message).each{|m| puts m}
  else 
    PWA::Dataset.each{|dataset| 
      puts dataset.init_for_fit(Minuit::Parameter.max_id)
    }
  end
  print_line(':')
  #
  # Test user-supplied derivatives (if wanted)
  #
  if(test_derivs)
    derivs = Minuit.test_derivs
    Minuit::Parameter.each{|par| 
      next if(derivs[par.id].nil?)
      numeric,analytic = *(derivs[par.id])
      name = PWA::ParIDs.name(par.id)
      puts "#{name} => numeric: #{numeric} analytic: #{analytic}"
    }
    PWA::Parallel.send_to_children(true,:terminate) if(parallel?)
    exit
  end
  #
  # Minimize fcn
  #
  fcn.out_path = File.dirname(ctrl_file)
  fcn.minimize
  PWA::Parallel.send_to_children(true,:terminate) if(parallel?)
else 
  #
  # Running on (one of) the child node(s)
  #
  max_par_id = PWA::Parallel.recv_from_master(:max_par)
  msg = ''
  PWA::Parallel.each_dataset_on_node{|dataset| 
    msg += dataset.init_for_fit(max_par_id) + "\n"
  }
  PWA::Parallel.send_to_master(msg,:message)
  loop{
    break if(PWA::Parallel.recv_from_master(:terminate))
    flag = PWA::Parallel.recv_from_master(:fcn_flag)
    pars = PWA::Parallel.recv_from_master(:params)
    fcn_val,derivs = [],[]
    PWA::Parallel.each_dataset_on_node{|dataset|
      dset_derivs = Array.new(pars.length,0)
      fcn_val.push(dataset.fcn_val(flag,pars,dset_derivs))
      derivs.push dset_derivs
    }
    PWA::Parallel.send_to_master(fcn_val,:fcn_val)
    PWA::Parallel.send_to_master(derivs,:derivs) if(flag == 2)
  }
end
