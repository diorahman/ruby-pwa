#! /usr/bin/env ruby

require 'optparse'
cmdline = OptionParser.new
cmdline.banner = "Usage: run_AddErrors.rb [...optons...] norm-int.xml"
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('--errors "{\'name1\' => err1,\'name2\' => err2,...}"',String,
	   'Scale factors and new errors'){|opt|
  $errs = opt
}
cmdline.on('-t top dir',String,'top directory ex: /raid12/pwa/klam/'){|opt|
  $top_dir = opt
}
cmdline.on('--type',String,'raw or acc'){|opt|
  $ype = opt
}

require '/home/pwa/builds/pwa++/utils/Utils.rb'
get_bins_list("#{$top_dir}/")
norm_file = ARGV.last.to_s
while(get_next_bin)
  bin_name,mean,min,max,x_axis_title = bin_info($bin)
  if min>=ARGV[0].to_i && min<=ARGV[1].to_i
    puts bin_name
    cmdstr="/home/pwa/builds/ruby-pwa/norm-int/AddErrors.rb --errors #{$errs}"
    cmdstr += "#{$top_dir}/#{$type}/#{bin_name}/#{norm_file}"
    puts cmdstr
#    system cmdstr
  end
end
