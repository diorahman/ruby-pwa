#!/usr/bin/env ruby
#  This script add errors to a norm-int file.  Command lines are like this:
# ./AddErrors.rb --errors "{'flux' => '.2', 'inv-num-raw' => '.03'}" norm-int-file.xml
# out_put file has the form new_errors:{old_file_name}.xml
#
# parse command line
#
require 'rexml/document'
include REXML
require 'optparse'
cmdline = OptionParser.new
cmdline.banner = "Usage: AddErors.rb [...optons...] norm-int.xml"
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('--errors "{\'name1\' => err1,\'name2\' => err2,...}"',String,
	   'Scale factors and new (relative) errors'){|opt|
  $errs = eval opt
}
in_file_name = cmdline.parse(ARGV)[0]
file_hash = {}

pwd = "/home/pwa/builds/ruby-pwa/norm-int"

in_file = File.new(in_file_name)
in_doc = Document.new(in_file)

in_doc.elements.each('normalization-integral'){|ni|
  ni.elements.each('scale-factor'){|sf|
    $errs.each_key{|new_sf|
    if sf.attribute('name').to_s == new_sf.to_s
      sf.delete_attribute('relative-error')
      sf.add_attribute('relative-error',$errs[new_sf.to_s])
    end
    }
  }
}
new_file_name = in_file_name.chop.chop.chop.chop + ":new_errs.xml"
out_file = File.new("#{new_file_name}",File::CREAT|File::TRUNC|File::RDWR, 0644)
in_doc.write(out_file,0)


