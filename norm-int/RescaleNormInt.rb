#!/usr/bin/env ruby

# Author:: Mike McCracken
# Normalization integral rescaler
# example command line :
# ./RescaleNormInt.rb -n norm_file.xml -t acc -b 2000-2010 -N NEW_SF,0.2,0.8 -O flux,4.1,0.1 /home/pwa/klam
require 'optparse'
require 'utils'
require 'rexml/document'
include REXML

options = Hash.new
new_sf = Hash.new
old_sf = Hash.new
type = ""
max = 4000
min = 0
#
# parse command line
#
cmdline = OptionParser.new
cmdline.banner = 'Usage: RescaleNormInt [...options...] top_dir'
cmdline.on('-h','--help','Prints help to screen'){puts cmdline; exit}
cmdline.on('-n --name',String,'Name of norm int files'){|n| 
  options[:n] = n.to_s
}
cmdline.on('-t --type',String,'acc or raw'){|type| 
  options[:t] = type
}
cmdline.on('-o --out-file',String,'Outfile name (defaults to overwrite)'){|f| 
  options[:o] = f
}
cmdline.on('-b min-max',String,'bin range'){|d|
  max = d.split("-")[1].to_i 
  min = d.split("-")[0].to_i
}
cmdline.on('-N name,value,err:...',String,'NEW scale factors'){|s|
  s.split(":").each{|sf|
    new_sf[sf.split(",")[0].to_s] = [sf.split(",")[1].to_f,sf.split(",")[2].to_f]
  }
}
cmdline.on('-O name,value,err:...',String,'OLD scale factors that will change'){|s|
  s.split(":").each{|sf|
    old_sf[sf.split(",")[0].to_s] = [sf.split(",")[1].to_f,sf.split(",")[2].to_f]
  }
}
top_dir = cmdline.parse(ARGV).last
require_options(cmdline,options,[:n,:t])

direc = Dir.new("#{top_dir}/#{options[:t]}")
direc.entries.each{|bin|
  if bin.include?("Wbin") && bin.split("-").last.to_i > min && bin.split("-").last.to_i <= max
    print "::::::::::::::::::::::::::\n"
    puts bin
    numer = 1.0
    recip = 1.0
    ni_file = File.new("#{top_dir}/#{options[:t]}/#{bin}/#{options[:n]}")
    doc = Document.new(ni_file)
    out_doc = Document.new("<?xml version='1.0' encoding='UTF-8' standalone='no'?>")
    doc.elements.each("normalization-integral"){|main_lmnt|
      out_main = Element.new('normalization-integral')
      #add scale-factors that stay to the output element...
      main_lmnt.elements.each('scale-factor'){|in_sf|
	match_old,match_new = false,false
	old_sf.each{|old_name,old_arr|
	  match_old = true if old_name.to_s == in_sf.attribute('name').value.to_s
	}
	new_sf.each{|new_name,new_arr|
	  match_new = true if new_name.to_s == in_sf.attribute('name').value.to_s
	}
	if !match_old && !match_new
	  if in_sf.attribute('name').value.to_s != 'total-scale-factor'
	    out_main.add_element(in_sf) 
	    puts in_sf.attribute('name').value.to_s
	  end
	end

	#redo old scale factors
	old_sf.each{|name,arr|
	  if in_sf.attribute('name').value.to_s == name
	    recip = recip / in_sf.attribute('value').value.to_f
	    elem = Element.new('scale-factor')
	    elem.add_attribute('name',name)
	    elem.add_attribute('value',arr[0])
	    numer = numer * arr[0]
	    elem.add_attribute('relative-error',arr[1])
	    out_main.add_element(elem)	  
	    puts "Updated scale factor #{name}..."
	  end
	}
      }
      #copy cuts info
      main_lmnt.elements.each('cuts-info'){|cut|
	out_main.add_element(cut)
      }
      #add new scale factors
      new_sf.each{|name,arr|
	elem = Element.new("scale-factor")
	elem.add_attribute('name',name)
	elem.add_attribute('value',arr[0])
	numer = numer * arr[0]
	elem.add_attribute('relative-error',arr[1])
	out_main.add_element(elem)
	puts "Added scale factor #{name}..."
      }

      #the rescaling value is...
      rescale = numer * recip

      #recalculate total error
      puts "Recalculating errors..."
      total_err2 = 0.0
      out_main.elements.each('scale-factor'){|sf|
	total_err2 += (sf.attribute('relative-error').value.to_f)**2
      }

      print "Rescale factor = " + rescale.to_s + "\n"

      #rewrite the total scale factor...
      main_lmnt.each_element_with_attribute('name','total-scale-factor'){|total_sf|
	val = total_sf.attribute('value').value.to_f
	main_lmnt.delete_element(total_sf)
	elem = Element.new('scale-factor')
	elem.add_attribute('name','total-scale-factor')
	elem.add_attribute('value',val * rescale)
	print "New total scale factor = " + (val*rescale).to_s
	print ", error = " + Math::sqrt(total_err2).to_s + "\n"
	elem.add_attribute('relative-error',Math::sqrt(total_err2))
	elem.add_attribute('error',val * rescale * Math::sqrt(total_err2))
	out_main.add_element(elem)
      }

      main_lmnt.elements.each('incoherent-waveset'){|inc|
	out_ic = Element.new('incoherent-waveset')
	out_ic.add_attribute(inc.attribute('coherence-string'))
	inc.elements.each{|ni|
	  if ni.name == 'wave'
	    out_ic.add_element(ni)
	  elsif ni.name == 'normint-elements'
	    out_ni_elem = Element.new('normint-elements')
	    ni.elements.each('row'){|row|
	      #out_ni_elem.add_element(row)
	      str = ""
	      row.text.split("\|").each{|comp|
		real = comp.delete("\(\)").split(",")[0].to_f * rescale
		imag = comp.delete("\(\)").split(",")[1].to_f * rescale
		str += sprintf("\(%g\,%g\)\|",real.to_f,imag.to_f)
	      }
	      str = str.chop
	      new_row = Element.new('row')
	      new_row.add_text(str)
	      out_ni_elem.add_element(new_row)
	    }
	    out_ic.add_element(out_ni_elem)
	  end
	}
	out_main.add_element(out_ic)
      }
      out_doc.add_element(out_main)
    }
    ni_file.close
    if options[:o] != nil
      out_file = File.open("#{top_dir}/#{options[:t]}/#{bin}/#{options[:o]}","w")
    else
      out_file = File.open("#{top_dir}/#{options[:t]}/#{bin}/#{options[:n]}","w")
    end
    out_doc.write(out_file,0)
  end
}


