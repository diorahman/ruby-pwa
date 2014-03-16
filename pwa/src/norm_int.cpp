// Author: M. McCracken
/* This code is the compiled part of the new NormInts generator.  The        *
 * function below will read in all amplitudes for a given coherence string   *
 * in an event-by-event fashion, and generate the necessary products and     *
 * sums.                                                                     */
//_____________________________________________________________________________
#include "ruby-complex.h"
#include "pwa-src.h"
#include "cppvector.cpp"
#include <fstream>

VALUE rb_cNormInt;
//_____________________________________________________________________________
/* call-seq: calc_coherent_sums(cuts,ic,a,file) -> self
 *
 *
 *
 */
VALUE calc_coherent_sums(VALUE __self, VALUE __num_files, VALUE __cuts_on,
			 VALUE __cuts_ary, VALUE __num_evts){

  VectorFlt2D *cross_term_ints 
    = get_cpp_ptr(rb_iv_get(__self,"@cross_term_ints"),__VectorFlt2D__);
  int cuts_on = NUM2INT(__cuts_on);
  int num_amps = NUM2INT(__num_files);
  int num_evts = NUM2INT(__num_evts);
  double cut_check;
  int good_events = 0;
  ifstream in_file[num_amps];
  char *amp_names[num_amps];

  // array to hold the sums
  complex<float> cross_terms[num_amps][num_amps];
  // Naming and opening files...
  for(int iter = 0;iter<num_amps;iter++){
    amp_names[iter] = STR2CSTR(rb_ary_entry(rb_iv_get(__self,
						      "@coh_amps"),iter));
    in_file[iter].open(amp_names[iter]);
  }
  bool take_event;
  complex<float> amp[num_amps];
  int event = 0;
  int read_tag = 0;
  while(event<num_evts && read_tag<1){
    for(int j = 1;j<num_amps;j++){
      if(in_file[j].eof())  read_tag++;
    }
    if(cuts_on){
      cut_check = NUM2DBL(rb_ary_entry(__cuts_ary,event));
      if(cut_check >= 0.0){
	take_event = true;
      }
      else take_event = false;
    }
    else if(!cuts_on){
      take_event = true;
    }
    // read the amp vals...
    for(int amp_num = 0;amp_num<num_amps;amp_num++){
      in_file[amp_num].read((char*)&amp[amp_num],sizeof(amp[amp_num]));
    }

    if(take_event){
      good_events++;
      for(int row = 0;row<num_amps;row++){
	for(int col = row;col<num_amps;col++){
	  cross_terms[row][col] = cross_terms[row][col]
	    + amp[row] * conj(amp[col]);
	}
      }
    }
    event++;
  }
  cout << "Events used: " << good_events << "\n";
  // impose symmetry...
  for(int row = 0;row<num_amps;row++){
    for(int col = 0;col<=row;col++){
      cross_terms[row][col] = conj(cross_terms[col][row]);
    }
  }
  // assign values to VectorFlt2D...
  for(int i = 0;i<num_amps;i++){
    for(int j = 0;j<num_amps;j++){
      (*cross_term_ints)[i][j] = cross_terms[i][j];
    }
  }
  return rb_int_new(event);
}


//
// function to count the number of events for which amplitudes were generated.
//
//
VALUE count_amps(VALUE __self, VALUE __file_name){
  char *filename = STR2CSTR(__file_name);
  ifstream in_file;
  in_file.open(filename);
  int event = 0;
  complex<float> amp;

  while(!in_file.eof()){
    event++;
    in_file.read((char*)&amp,sizeof(amp));
  }
  return rb_int_new(event-1);
}



//_____________________________________________________________________________
extern "C" void Init_norm_int(){
  rb_define_global_function("calc_coherent_sums",
			    RUBY_FUNC(calc_coherent_sums),4);
  rb_define_global_function("count_amps",RUBY_FUNC(count_amps),1);
}
