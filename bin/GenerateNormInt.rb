#!/usr/bin/env ruby

# Author:: M. McCracken
# Normalization integral generator

require 'complex.rb'
require 'optparse'
require 'rexml/document'
include REXML

require "pwa/lib/#{ENV['OS_NAME']}/norm_int.so"
require "utils.rb"
require "pwa/lib/#{ENV['OS_NAME']}/cppvector"
require "norm-int/norm_int_utils.rb"
include PWA
#
# global vars
#
$cmdline = OptionParser.new
$bins_list

#
# global methods
#
def init_norm_file()
  yield if block_given?
  $cmdline.parse(ARGV)
  if($top_dir == nil)
    printf "Error! Top directory must be specified (-t,--top-dir)!\n"
    puts $cmdline; exit
  end
  if($type == nil)
    printf "Error! Data type (acc or raw) must be specified (--type)!\n"
    puts $cmdline; exit
  end
  bin_list("#{$top_dir}/#{$type}/",$bin_ranges)
  if ($bin_ranges.length < 1)  
    printf "Error! No bins in specified dir"
    exit
  end
end

#
# The method below is called by the norm control file for each bin.
# The code below then calls a compiled C function (see norm_int.cpp and 
# norm_int_utils.rb).
#
def gen_norm_int_file(bin_name,coherence,total_events,cuts_file_name,
                      scale_factors,max_events,amp_str = "")
  current_dir = Dir.new("#{$top_dir}/#{$type}/#{bin_name}/")
  print ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"
  print ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"
  print "#{$type}/#{bin_name} \n"
  amp_match = amp_str
  coh_strs = get_coh_strs_from_dir(coherence,current_dir,amp_match)
  if coh_strs.length == 0
    print "No amps files match string \"#{amp_match}\"...\n"
    print "Please try another string.\n"
    exit
  end

  xml_norm_int = Document.new("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n\n")
  xml_norm_int.add_text("\n")
  norm_int_key = Element.new("normalization-integral")

  test_file = String.new
  current_dir.each{|ampl|
    if ampl.to_s =~ /.+\.amps/ && ampl.include?(amp_match)
      test_file = current_dir.path.to_s + "/" + ampl.to_s 
    end
  }
  num_amps = count_amps(test_file)
  print "Using amplitude files containing: " + amp_match + "\n"
  print "Number of points being used: " + num_amps.to_s + "\n"

  cuts_on = 0
  cuts_on = 1 unless cuts_file_name.nil?
  cuts = []
  if cuts_on != 0
    cuts_file = File.new(current_dir.path.to_s + "/" + cuts_file_name,"r")
    event_no = 0
    test_event_no = 0
    while !cuts_file.eof()
      cuts[event_no] = (cuts_file.gets).chop.to_f
      test_event_no += 1 if cuts[event_no] >= 0.0
      event_no += 1
    end
  else event_no = num_amps
  end

  elem = Element.new('cuts-info')
  elem.add_attribute('cuts-file-name',cuts_file_name)
  norm_int_key.add_element(elem)

  errsq = 0.0
  elem = Element.new("scale-factor")
  title = Attribute.new("name","total-events-to-amps-ratio")
  ratio = total_events.to_f / num_amps.to_f
  value = Attribute.new("value",ratio)
  error = Attribute.new("relative-error",'0')
  elem.add_attribute(title)
  elem.add_attribute(value)
  elem.add_attribute(error)
  norm_int_key.add_text("\n  ");
  norm_int_key.add_element(elem)
  total_factor = ratio
  scale_factors.each{|n,v|
    elem = Element.new("scale-factor")
    title = Attribute.new("name",n)
    value = Attribute.new("value",v[0])
    total_factor = total_factor * v[0]
    errsq += v[1] * v[1]
    error = Attribute.new("relative-error",v[1])
    elem.add_attribute(title)
    elem.add_attribute(value)
    elem.add_attribute(error)
    norm_int_key.add_text("\n  ");
    norm_int_key.add_element(elem);
  }

  elem = Element.new("scale-factor")
  title = Attribute.new("name","total-scale-factor")
  value = Attribute.new("value",total_factor)
  relerror = Attribute.new("relative-error",errsq**0.5)
  error = Attribute.new("error",errsq**0.5 * total_factor)
  elem.add_attribute(title)
  elem.add_attribute(value)
  elem.add_attribute(relerror)
  elem.add_attribute(error)
  norm_int_key.add_text("\n  ")
  norm_int_key.add_element(elem)
  print "Total scale factor = " + total_factor.to_s 
  print ", relative error = " + (errsq**0.5).to_s + "\n"
  print "cuts file = #{cuts_file_name}\n"

  coh_strs.each{|str|
    @coh_amps = get_coh_amps_for_string(current_dir,str,bin_name,amp_match)
    num_coh_amps = @coh_amps.length
    print ".....................................................\n"
    print "Computing coherence: \t" + str + "\n"
    print "Number of waves: \t" + num_coh_amps.to_s + "\n"

    @cross_term_ints = PWA::CppVectorFlt2D.new
    empty_ary = Array.new(num_coh_amps)
    empty_ary.each_index{|i|
      empty_ary[i] = @coh_amps
    }
    @cross_term_ints.resize(empty_ary)

    waveset = Element.new("incoherent-waveset")
    string_coh = Attribute.new("coherence-string",str)
    waveset.add_attribute(string_coh)
    @coh_amps.each{|amp|
      wave = Element.new("wave")
      amp.split('/').last.split('.amps').first
      file = Attribute.new("file",amp.split('/').last)
      wave.add_attribute(file)
      waveset.add_text("\n    ")
      waveset.add_element(wave)
    }
    num_amps = calc_coherent_sums(num_coh_amps,cuts_on,cuts,event_no)

    norm_elements = Element.new("normint-elements")
    num_coh_amps.times do|i|
      row = Element.new("row")
      sum_string = ""
      num_coh_amps.times do |j|
	if @cross_term_ints[i,j].real.to_s == "0.0" || @cross_term_ints[i,j].real.to_s == "-0.0"
	  term_real = "0"
	else term_real = (@cross_term_ints[i,j].real * total_factor).to_s
	end
	if @cross_term_ints[i,j].imag.to_s == "0.0" || @cross_term_ints[i,j].imag.to_s == "-0.0"
	  term_imag = "0"
	else term_imag = (@cross_term_ints[i,j].imag * total_factor).to_s
	end
	sum_string += sprintf("\(%g\,%g\)\|",term_real.to_f,term_imag.to_f)
#	sum_string += "(" + term_real + "\," + term_imag + ")\|"
      end
      sum_string.chop
      row.add_text(sum_string)
      norm_elements.add_text("\n      ")
      norm_elements.add_element(row)
    end
    waveset.add_text("\n    ")
    waveset.add_element(norm_elements)
    norm_int_key.add_text("\n\n  ");
    norm_int_key.add_element(waveset)
  }

  filename = "#{$top_dir}/#{$type}/#{bin_name}/"
  filename += "coherence=" + coherence + ":"
  filename += "amp_match=" + amp_match + ":" if amp_match != ""
  filename += "cuts_file=#{cuts_file_name}:.norm-int.xml" if cuts_on != 0
  filename += ".norm-int.xml" if cuts_on == 0
  file = File.open(filename,"w")
  xml_norm_int.add_element(norm_int_key)
  xml_norm_int.write(file,-1,false)
  print ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"
  print "Computed sums for " + coh_strs.size.to_s + " incoherent wavesets.\n"
  print "File name : " + filename + "\n"
end

#
# parse the command line
#
$cmdline.banner = "Usage: GenNormIntegrals [...options...] norm.ctrl.rb"
$cmdline.separator 'Note: Control file must come last'
$cmdline.on('-h','--help','Prints help to the screen'){puts $cmdline; exit}
$cmdline.on('-b min-max',String,'Only use bins in range'){|opt| 
  $bin_ranges = []
    min = opt.split('-')[0].to_i
    max = opt.split('-')[1].to_i
    $bin_ranges.push [min,max]
}
$cmdline.on('-t','--top-dir [dir]',String,'Top directory'){|f| $top_dir = f}
$cmdline.on('--type [type]',[:raw,:acc],'Data type (raw/acc)'){
  |f| $type = f.to_s
}
ctrl_file = ARGV.last
if(!File.exists?(ctrl_file))
  if(!ARGV.include?('-h') and !ARGV.include?('--help'))
    print "Error! Control file #{ctrl_file} does not exist! \n"; exit
  else 
    puts $cmdline; exit
  end
end
require ctrl_file

