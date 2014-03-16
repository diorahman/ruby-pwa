// Author: Mike Williams
//_____________________________________________________________________________
#include "ruby-complex.h"
#include "pwa-src.h"
#include "cppvector.cpp"
#include <fstream>

/// Returns the total amplitude for @a amps and @a params
complex<double> get_amp_total(const vector<complex<float> > &__amps,
            const vector<complex<double> > &__params){
  complex<double> amp_tot(0,0);
  int num_amps = (int)__amps.size();
  for(int a = 0; a < num_amps; a++) amp_tot += __params[a]*__amps[a];
  return amp_tot;
}

VALUE rb_cEvt;
//_____________________________________________________________________________
/* call-seq: read_in_amps_for_file(cuts,ic,a,file) -> self
 *
 * Reads in all amplitudes for _file_ w/ incoherent index _ic_, amplitude 
 * index _a_ and using _cuts_ (<tt>nil</tt> for no cuts).
 */
VALUE rb_evt_read_in_amps_for_file(VALUE __self,VALUE __cuts,VALUE __ic,
				   VALUE __a,VALUE __file){  
  VectorFlt3D *amp_vals 
    = get_cpp_ptr(rb_iv_get(__self,"@amp_vals"),__VectorFlt3D__);
  int num_events = (int)(*amp_vals).size();  
  int ic = NUM2INT(__ic),a = NUM2INT(__a);
  // open the file
  ifstream in_file(STR2CSTR(__file));
  complex<float> amp;
  int event = 0,event_index = 0;
  double cut = 1;
  while(in_file.read((char*)&amp,sizeof(amp))){
    if(__cuts != Qnil) cut = NUM2DBL(rb_ary_entry(__cuts,event));    
    event++;
    if(cut > 0){
      (*amp_vals)[event_index][ic][a] = amp;      
      event_index++;
    }
  }
  if(event_index != num_events){
    char error[100];
    sprintf(error,"Read incorrect number of events (%d instead of %d)\n",
	    event_index,num_events);
    rb_fatal(error);
  }
  return __self;
}
//_____________________________________________________________________________
/* call-seq: calc_log_liklihood(flag,pars,derivs) -> -log(L)
 *
 * Returns the <tt>-log(L)</tt> given MINUIT parameters _pars_. If _flag_ is 2,
 * derivatives are calculated and set in _derivs_.
 */
VALUE rb_evt_calc_log_liklihood(VALUE __self,VALUE __flag,VALUE __pars,
				VALUE __derivs){
  VectorFlt3D *amp_vals 
    = get_cpp_ptr(rb_iv_get(__self,"@amp_vals"),__VectorFlt3D__);
  VectorDbl2D *params 
    = get_cpp_ptr(rb_iv_get(__self,"@params"),__VectorDbl2D__);
  VectorDbl3D *dparams 
    = get_cpp_ptr(rb_iv_get(__self,"@dparams"),__VectorDbl3D__);
  VALUE wts_ary = rb_iv_get(__self,"@wts");
  int num_events = (int)(*amp_vals).size();
  int num_ic = (int)(*params).size();
  double log_l = 0;
  complex<double> amp_tot;
  bool do_derivs = NUM2INT(__flag) == 2 ? true : false;
  int num_pars = RARRAY(__pars)->len; // length of MINUIT parameter array
  vector<vector<complex<double> > > dl_dpar(num_ic);
  vector<int> num_amps(num_ic);
  for(int ic = 0; ic < num_ic; ic++){
    num_amps[ic] = (int)(*params)[ic].size();
    dl_dpar[ic].assign(num_amps[ic],0.);
  }
  for(int ev = 0; ev < num_events; ev++){ // loop over events
    double intensity = 0.;
    double wt = NUM2DBL(rb_ary_entry(wts_ary,ev));
    for(int ic = 0; ic < num_ic; ic++){
      amp_tot = get_amp_total((*amp_vals)[ev][ic],(*params)[ic]);
      intensity += (amp_tot*conj(amp_tot)).real();
    }
    log_l -= wt*log(intensity);
    if(do_derivs){
      for(int ic = 0; ic < num_ic; ic++){
	amp_tot = get_amp_total((*amp_vals)[ev][ic],(*params)[ic]);
	for(int a = 0; a < num_amps[ic]; a++){
	  complex<double> dl = -(*amp_vals)[ev][ic][a]*conj(amp_tot)/intensity;
	  dl_dpar[ic][a] += wt*dl;
	}
      }
    }
  }
  if(do_derivs){
    for(int p = 0; p < num_pars; p++){
      complex<double> dl_dp = 0.;
      for(int ic = 0; ic < num_ic; ic++){
	for(int a = 0; a < num_amps[ic]; a++)
	  dl_dp += (*dparams)[ic][a][p]*dl_dpar[ic][a];
      }
      rb_ary_store(__derivs,p,rb_float_new(2*dl_dp.real()));  
    }
  }
  return rb_float_new(log_l);
}
//_____________________________________________________________________________
/* call-seq: calc_norm(flag,pars,derivs) -> norm_int
 *
 * Returns the normalization integral value given MINUIT parameters _pars_. 
 * If _flag_ is 2, derivatives are calculated and set in _derivs_.
 */
static VALUE rb_evt_calc_norm(VALUE __self,VALUE __flag,VALUE __pars,
			      VALUE __derivs){  
  VectorFlt3D *norm_vals
    = get_cpp_ptr(rb_iv_get(__self,"@norm_vals"),__VectorFlt3D__);
  VectorDbl2D *params 
    = get_cpp_ptr(rb_iv_get(__self,"@params"),__VectorDbl2D__);
  VectorDbl3D *dparams 
    = get_cpp_ptr(rb_iv_get(__self,"@dparams"),__VectorDbl3D__);
  int num_ic = (int)(*params).size();
  complex<double> norm = 0.0;
  bool do_derivs = NUM2INT(__flag) == 2 ? true : false;
  int num_pars = RARRAY(__pars)->len; // length of MINUIT parameter array
  complex<double> dnorm_dpar[num_pars];
  for(int p = 0; p < num_pars; p++) dnorm_dpar[p] = 0.;

  for(int ic = 0; ic < num_ic; ic++){
    int num_amps = (int)(*norm_vals)[ic].size();
    for(int a1 = 0; a1 < num_amps; a1++){
      complex<double> conj_par_norm,norm_deriv_sum = 0.;
      for(int a2 = 0; a2 < num_amps; a2++){
	conj_par_norm = conj((*params)[ic][a2])*(*norm_vals)[ic][a1][a2];
	norm += (*params)[ic][a1]*conj_par_norm;
	norm_deriv_sum += conj_par_norm;
      }
      if(do_derivs){
	for(int p = 0; p < num_pars; p++)
	  dnorm_dpar[p] += (*dparams)[ic][a1][p]*norm_deriv_sum;
      }
    }
  }
  if(do_derivs){
    for(int p = 0; p < num_pars; p++)
      rb_ary_store(__derivs,p,rb_float_new(2*dnorm_dpar[p].real()));
  }
  return rb_float_new(norm.real());
}
//_____________________________________________________________________________

extern "C" void Init_evt(){
  //-+-RDOC-+- 
  rb_cPWA = rb_define_module("PWA");
  VALUE rb_cEvt = rb_define_module_under(rb_cPWA,"Evt");
  rb_define_method(rb_cEvt,"read_in_amps_for_file",
		   RUBY_FUNC(rb_evt_read_in_amps_for_file),4);
  rb_define_method(rb_cEvt,"calc_log_liklihood",
		   RUBY_FUNC(rb_evt_calc_log_liklihood),3);
  rb_define_method(rb_cEvt,"calc_norm",RUBY_FUNC(rb_evt_calc_norm),3);
}
//_____________________________________________________________________________
