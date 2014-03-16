# Control file for GenNormIntegrals
#
init_norm_file()
#
require "#{$top_dir}/files/g11a_scale_factors.rb"
require "#{$top_dir}/files/acc_cuts_files.rb"
require "#{$top_dir}/files/data_event_count.rb"
require "#{$top_dir}/files/acc_event_count.rb"
require "#{$top_dir}/files/raw_event_count.rb"
#
coherence  = 'mz_g.mz_i.mz_f.final_state'
max_events = 10e6 # we want to use all amps generated in each bin
#
# loop over necessary w-bins
#

#while(get_next_bin)
bin_list("#{$top_dir}/#{$type}/",$bin_ranges).each{|bin_name|

  data_events = $data_event_count[bin_name]

  if($type == 'acc')
    cuts_file = $acc_cuts_file[bin_name]
    scale_factors = $g11a_scale_factors[bin_name]
    total_events = $acc_event_count[bin_name]    
  else
    cuts_file = nil
    scale_factors = {}
    total_events = $raw_event_count[bin_name]    
  end

  #print $raw_event_count[bin_name]
  scale_factors['inv-num-raw'] = 1.0/$raw_event_count[bin_name]

  # get 2-body photo-production phase space factor
  s = (bin_info(bin_name)[1]/1000.0)**2 # 2nd retrun value of bin_info is W
  mp,m1,m2 = 0.93827,1.115,0.493
  phspfact = Math.sqrt((s-(m1+m2)**2)*(s-(m1-m2)**2))/(64*Math::PI*s*(s-mp**2))
  scale_factors['phase-space-factor'] = phspfact

  # fill scale factor array --> ALL ERRORS ARE RELATIVE (%'s)!!!

  bin_scale_facs = {}
  scale_factors.each{|n,v|
    # second element of array is the error (%)
    bin_scale_facs[n] = [v,0.0]
  }

  # to specify an error on any of the scale factors, set
  # EX::::  bin_scale_facs['name-of-scale-factor'][1] = error

  ## Set the amp_match string to be a regular old string that 
  ## amps must match to be used in norm int.
  ## This is optional; if no fianl argument is supplied to gen_norm_int_file,
  ## the string defaults to "".
  amp_match = "\:"

  gen_norm_int_file(bin_name,coherence,total_events,cuts_file,
                    bin_scale_facs,max_events,amp_match)
}
