#!/usr/bin/env ruby

# Author:: Mike McCracken
# utils for Normalization integral generator

require 'optparse'
require "utils.rb"

#
# Short fcn that hashes a coherence string
#
def coh_hash(coh_str)
  chash = Hash.new
  coh_str = coh_str.chop
  coh_str = coh_str.reverse
  coh_str = coh_str.chop
  coh_str = coh_str.reverse
  coh_str.split(':').each{|x| eqpos = x.index('=') 
    chash[x.slice(0...eqpos)] = x.slice(eqpos+1..x.length-1)
  }
  chash
end
#
# This next block is a function that will read all the amps in a dir
# and get the necessary coherence combinations...
#
def get_coh_strs_from_dir(coherence,current_dir,amp_match)
  num_coh_tags = (coherence.count "\.") + 1
  coh_strs = []
  coh_tags = []

  while num_coh_tags >= 1
    coh_tags[num_coh_tags - 1] = coherence.split("\.")[num_coh_tags - 1].to_s
    num_coh_tags -= 1
  end

  current_dir.each{|file|    
    qualify = true
    coh_tags.each{|tag|
      qualify = false if !file.to_s.include?(tag.to_s)
    }
    if file.include?(".amps") && file.include?(amp_match) && qualify
      fhash = file_hash(file)
      coh_str = "\:"
      coh_tags.each_index{|tag|
	coh_str += coh_tags[tag] + "\=" + fhash[coh_tags[tag]] + "\:"
      }
      counter = 0
      coh_strs.each{|str|
	counter += 1 if str == coh_str
      }
      coh_strs = coh_strs + [coh_str] if counter < 1
    end
  }
  coh_strs
end
#
# The next block is a function that gets the amplitude names for a
# specific coherence string from a specific directory.
#
def get_coh_amps_for_string(direc,coh_str,bin_name,amp_match)
  coh_amps = []
  chash = coh_hash(coh_str)
  direc.each{|amp_file|
    if amp_file =~ /\.amp/ && amp_file.include?(amp_match)
      counter = 0
      fhash = file_hash(amp_file)
      chash.each_key{|key|
	counter += 1 if fhash[key] != chash[key]
      }
      amp_file = "#{$top_dir}/#{$type}/#{bin_name}/" + amp_file
      coh_amps = coh_amps + [amp_file] if counter < 1 
    end
  }
  coh_amps
end
#
# Below is a write output function similar to ~pwa/builds/ruby-pwa/pwa/fcn.rb
#
def write_output(file)
  doc = nil
  if(File.exists?(file))
    doc = REXML::Document.new(File.new(file))
  else
    doc = REXML::Document.new 
    doc << REXML::XMLDecl.new
#    doc.add_element 'pwa-fit'
  end
  self._add_iteration(doc)
  out = File.new(file,'w')
  doc.write(out,0)
  out.close
end
