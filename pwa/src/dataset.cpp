// Author: Mike Williams
//_____________________________________________________________________________
#include "ruby-complex.h"
#include "pwa-src.h"
#include "cppvector.cpp"


VALUE rb_cDataset;
//_____________________________________________________________________________
/// Returns the total amplitude for @a amps and @a params
complex<double> get_amp_total(const vector<complex<float> > &__amps,
			      const vector<complex<double> > &__params){
  complex<double> amp_tot(0,0);
  int num_amps = (int)__amps.size();
  for(int a = 0; a < num_amps; a++) amp_tot += __params[a]*__amps[a];
  return amp_tot;
}
//_____________________________________________________________________________
/* call-seq: _resize(num_events,max_par_id)
 *
 * Resize all C++ vectors to accomodate the Dataset's amplitudes for 
 * _num_events_ events and _max_par_id_ MINUIT parameters.
 */
VALUE rb_dataset_resize(VALUE __self,VALUE __num_events,VALUE __max_par_id){

  int num_events = NUM2INT(__num_events),max_par_id = NUM2INT(__max_par_id);
  VALUE amps = rb_iv_get(__self,"@amps"); // 2-d array of amps(#ic X #amps)
  VectorFlt3D *amp_vals 
    = get_cpp_ptr(rb_iv_get(__self,"@amp_vals"),__VectorFlt3D__);
  VectorDbl2D *params 
    = get_cpp_ptr(rb_iv_get(__self,"@params"),__VectorDbl2D__);
  VectorDbl3D *dparams 
    = get_cpp_ptr(rb_iv_get(__self,"@dparams"),__VectorDbl3D__);
  VectorFlt3D *norm_vals = 0;
  if(rb_iv_get(__self,"@norm_vals") != Qnil){
    norm_vals = get_cpp_ptr(rb_iv_get(__self,"@norm_vals"),__VectorFlt3D__);
  }
  amp_vals->resize(num_events);
  int num_ic = RARRAY(amps)->len; 
  params->resize(num_ic);
  dparams->resize(num_ic);
  if(norm_vals != 0) norm_vals->resize(num_ic);
  for(int n = 0; n < num_events; n++){ // loop over events
    (*amp_vals)[n].resize(num_ic);
    for(int ic = 0; ic < num_ic; ic++){ // loop over incoherent wavesets
      int num_amps = RARRAY(rb_ary_entry(amps,ic))->len;
      (*amp_vals)[n][ic].resize(num_amps);
      if(n == 0){ // only do these once
	(*params)[ic].resize(num_amps);
	(*dparams)[ic].resize(num_amps);
	if(norm_vals != 0) (*norm_vals)[ic].resize(num_amps);
	for(int a = 0; a < num_amps; a++){ // loop over amps in this waveset
	  (*dparams)[ic][a].resize(max_par_id + 1);
	  if(norm_vals != 0) (*norm_vals)[ic][a].resize(num_amps);
	}
      }
    }
  }
  return __self;
}
//_____________________________________________________________________________
/* call-seq: _set_params(pars,vars,set_derivs)
 *
 * Sets <tt>@params</tt> using MINUIT parameters _pars_ and kinematic
 * variables _vars_ (if <tt>:dcs</tt>). If _set_derivs_ is <tt>true</tt>, then
 * <tt>@dparams</tt> is set also.
 */
VALUE rb_dataset_set_params(VALUE __self,VALUE __pars,VALUE __vars,
			    VALUE __set_derivs){
  static ID set_pars_id = rb_intern("set_pars");
  static ID value_id = rb_intern("value");
  static ID deriv_id = rb_intern("deriv");
  VALUE amps = rb_iv_get(__self,"@amps"); 
  VectorDbl2D *params 
    = get_cpp_ptr(rb_iv_get(__self,"@params"),__VectorDbl2D__);
  VectorDbl3D *dparams 
    = get_cpp_ptr(rb_iv_get(__self,"@dparams"),__VectorDbl3D__);
  int num_ic = RARRAY(amps)->len,num_pars = RARRAY(__pars)->len;
  for(int ic = 0; ic < num_ic; ic++){ // loop over incoherent wavesets
    VALUE ic_amps = rb_ary_entry(amps,ic);
    int num_amps = RARRAY(ic_amps)->len;
    for(int a = 0; a < num_amps; a++){ // loop over amps in this waveset
      VALUE amp = rb_ary_entry(ic_amps,a); // current amp
      if(rb_iv_get(amp,"@use") == Qfalse){
	(*params)[ic][a] = 0.0;
	for(int par = 0; par < num_pars; par++) (*dparams)[ic][a][par] = 0.;
	continue;
      }
      rb_funcall(amp,set_pars_id,1,__pars); // call Amp#set_pars on it
      (*params)[ic][a] = CPP_COMPLEX(float,rb_funcall(amp,value_id,1,__vars));
      if(__set_derivs == Qfalse) continue;
      for(int par = 0; par < num_pars; par++){ // loop over parameters
	if(rb_ary_entry(__pars,par) == Qnil) continue; // amp doesn't use par
	(*dparams)[ic][a][par] 
	  = CPP_COMPLEX(double,rb_funcall(amp,deriv_id,2,INT2NUM(par),__vars));
      }
    }
  }
  return __self;
}
//_____________________________________________________________________________
/* call-seq: intensity(event) -> Complex
 *
 * Returns the intensity for _event_ using current <tt>@params</tt> 
 */
VALUE rb_dataset_intensity(VALUE __self,VALUE __event){
  VectorFlt3D *amp_vals 
    = get_cpp_ptr(rb_iv_get(__self,"@amp_vals"),__VectorFlt3D__);
  VectorDbl2D *params 
    = get_cpp_ptr(rb_iv_get(__self,"@params"),__VectorDbl2D__);
  int num_ic = (int)(*params).size(),event = NUM2INT(__event);
  double intensity = 0.;
  complex<double> amp_tot;
  
  for(int ic = 0; ic < num_ic; ic++){
    amp_tot = get_amp_total((*amp_vals)[event][ic],(*params)[ic]);
    intensity += (amp_tot*conj(amp_tot)).real();
  }
  return rb_float_new(intensity);
}
//_____________________________________________________________________________
/** call-seq: amp_total(ic,event) -> Complex
 *
 * Returns the total amplitude for incoherent term _ic_ for _event_.
 */
VALUE rb_dataset_amp_total(VALUE __self,VALUE __ic,VALUE __event){
  VectorFlt3D *amp_vals 
    = get_cpp_ptr(rb_iv_get(__self,"@amp_vals"),__VectorFlt3D__);
  VectorDbl2D *params 
    = get_cpp_ptr(rb_iv_get(__self,"@params"),__VectorDbl2D__);
  int ic = NUM2INT(__ic),event = NUM2INT(__event);
  complex<double> amp = get_amp_total((*amp_vals)[event][ic],(*params)[ic]);
  return rb_complex_new(amp);
}
//_____________________________________________________________________________

extern "C" void Init_dataset(){
  //-+-RDOC-+- 
  rb_cPWA = rb_define_module("PWA");
  rb_cDataset = rb_define_class_under(rb_cPWA,"Dataset",rb_cObject);  
  rb_define_method(rb_cDataset,"_resize",RUBY_FUNC(rb_dataset_resize),2);
  rb_define_method(rb_cDataset,"_set_params",
		   RUBY_FUNC(rb_dataset_set_params),3);
  rb_define_method(rb_cDataset,"intensity",RUBY_FUNC(rb_dataset_intensity),1);
  rb_define_method(rb_cDataset,"amp_total",RUBY_FUNC(rb_dataset_amp_total),2);
}
//_____________________________________________________________________________
