// Author: Mike Williams
//_____________________________________________________________________________
#include "ruby-complex.h"
#include "pwa-src.h"
#include "cppvector.cpp"

/// Returns the total amplitude for @a amps and @a params
complex<double> get_amp_total(const vector<complex<float> > &__amps,
            const vector<complex<double> > &__params){
  complex<double> amp_tot(0,0);
  int num_amps = (int)__amps.size();
  for(int a = 0; a < num_amps; a++) amp_tot += __params[a]*__amps[a];
  return amp_tot;
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

VALUE rb_cDcs;
//_____________________________________________________________________________
/* call-seq: calc_dcs(pars) -> Array
 *
 * Returns the Array of calculated differential cross section points using 
 * amps w/ <tt>amp.use == true</tt>.
 */
VALUE rb_dcs_calc_dcs(VALUE __self,VALUE __pars,VALUE __cov_matrix){
  static ID vars_id = rb_intern("vars");
  VALUE dcs_pts = rb_iv_get(__self,"@dcs_pts");
  double phsp = NUM2DBL(rb_iv_get(__self,"@phsp_factor"));  
  int num_pts = RARRAY(dcs_pts)->len;
  int num_pars = RARRAY(__pars)->len; // length of MINUIT parameter array
  double dIdpar[num_pars];
  VALUE dcs = rb_ary_new2(num_pts);
  VALUE dcs_error = rb_ary_new2(num_pts);
  VectorFlt3D *amp_vals 
    = get_cpp_ptr(rb_iv_get(__self,"@amp_vals"),__VectorFlt3D__);
  VectorDbl2D *params 
    = get_cpp_ptr(rb_iv_get(__self,"@params"),__VectorDbl2D__);
  VectorDbl3D *dparams 
    = get_cpp_ptr(rb_iv_get(__self,"@dparams"),__VectorDbl3D__);
  VALUE rb_cov_ary = rb_funcall(__cov_matrix,rb_intern("to_a"),0);
  double cov_matrix[num_pars][num_pars];
  for(int i = 0; i < num_pars; i++){
    for(int j = 0; j < num_pars; j++){
      cov_matrix[i][j] = NUM2DBL(rb_ary_entry(rb_ary_entry(rb_cov_ary,i),j));
    }
  }
  for(int pt = 0; pt < num_pts; pt++){ // loop over dsigma pts
    VALUE dcs_pt = rb_ary_entry(dcs_pts,pt);
    rb_dataset_set_params(__self,__pars,rb_funcall(dcs_pt,vars_id,0),Qtrue);
    int num_ic = (int)(*amp_vals)[pt].size();
    double intensity = 0.0;
    for(int p = 0; p < num_pars; p++) dIdpar[p] = 0.;
    for(int ic = 0; ic < num_ic; ic++){ // loop over incoherent wavesets
      complex<double> amp_tot 
	= get_amp_total((*amp_vals)[pt][ic],(*params)[ic]);
      intensity += (amp_tot*conj(amp_tot)).real();
      int num_amps = (int)(*amp_vals)[pt][ic].size();
      for(int a = 0; a < num_amps; a++){ // loop over amps in this waveset
	complex<double> amp_prod = (*amp_vals)[pt][ic][a]*conj(amp_tot);
	for(int p = 0; p < num_pars; p++) 
	  dIdpar[p] += 2*((*dparams)[ic][a][p]*amp_prod).real();
      }
    }
    double error2 = 0;
    for(int i = 0; i < num_pars; i++){
      for(int j = 0; j < num_pars; j++){
	error2 += dIdpar[i]*cov_matrix[i][j]*dIdpar[j];
      }
    }
    rb_ary_store(dcs,pt,rb_float_new(phsp*intensity));
    rb_ary_store(dcs_error,pt,rb_float_new(phsp*sqrt(error2)));
  }
  VALUE ret_ary = rb_ary_new2(2);
  rb_ary_store(ret_ary,0,dcs);
  rb_ary_store(ret_ary,1,dcs_error);
  return ret_ary;
}
//_____________________________________________________________________________
/* call-seq: fcn_val(flag,pars,derivs) -> chi2
 *
 * Calculates chi2 given MINUIT parameters _pars_. If _flag_ is 2, derivatives
 * are calculated and set in _derivs_.
 */
static VALUE rb_dcs_fcn_val(VALUE __self,VALUE __flag,VALUE __pars,
			    VALUE __derivs){
  static ID cs_id = rb_intern("cs");
  static ID cs_err_id = rb_intern("cs_err");
  static ID vars_id = rb_intern("vars");  
  int num_pars = RARRAY(__pars)->len; // length of MINUIT parameter array
  double chi2 = 0.0;
  double phsp = NUM2DBL(rb_iv_get(__self,"@phsp_factor"));  
  VALUE dcs_pts = rb_iv_get(__self,"@dcs_pts");
  VALUE do_derivs = (NUM2INT(__flag) == 2) ? Qtrue : Qfalse;
  int num_pts = RARRAY(dcs_pts)->len;
  VectorFlt3D *amp_vals 
    = get_cpp_ptr(rb_iv_get(__self,"@amp_vals"),__VectorFlt3D__);
  VectorDbl2D *params 
    = get_cpp_ptr(rb_iv_get(__self,"@params"),__VectorDbl2D__);
  VectorDbl3D *dparams 
    = get_cpp_ptr(rb_iv_get(__self,"@dparams"),__VectorDbl3D__);
  double dchi2dpar[num_pars];
  for(int p = 0; p < num_pars; p++) dchi2dpar[p] = 0.;
  for(int pt = 0; pt < num_pts; pt++){ // loop over dsigma pts
    VALUE dcs_pt = rb_ary_entry(dcs_pts,pt);
    double cs = NUM2DBL(rb_funcall(dcs_pt,cs_id,0));
    double cs_err = NUM2DBL(rb_funcall(dcs_pt,cs_err_id,0));
    rb_dataset_set_params(__self,__pars,rb_funcall(dcs_pt,vars_id,0),
			  do_derivs);
    int num_ic = (int)(*amp_vals)[pt].size();
    double intensity = 0.0; 
    complex<double> dcsdpar[num_pars];
    for(int p = 0; p < num_pars; p++) dcsdpar[p] = 0.;
    for(int ic = 0; ic < num_ic; ic++){ // loop over incoherent wavesets
      complex<double> amp_tot 
	= get_amp_total((*amp_vals)[pt][ic],(*params)[ic]);
      intensity += (amp_tot*conj(amp_tot)).real();
      if(do_derivs == Qfalse) continue;
      int num_amps = (int)(*amp_vals)[pt][ic].size();
      for(int a = 0; a < num_amps; a++){ // loop over amps in this waveset
	complex<double> amp_prod = (*amp_vals)[pt][ic][a]*conj(amp_tot);
	for(int p = 0; p < num_pars; p++) 
	  dcsdpar[p] += (*dparams)[ic][a][p]*amp_prod;
      }
    }
    double cs_calc = phsp*intensity;
    double diff = cs - cs_calc;
    chi2 += diff*diff/(cs_err*cs_err); // add this pt's chi^2 to total
    if(do_derivs == Qtrue){
      for(int p = 1; p < num_pars; p++){
	complex<double> dsdp = dcsdpar[p]*phsp;
	dchi2dpar[p] += 2*((2/(cs_err*cs_err))*(cs_calc - cs)*dsdp).real();
      }
      for(int p = 1; p < num_pars; p++){ // set the derivatives
	if(rb_ary_entry(__derivs,p) != Qnil){
	  rb_ary_store(__derivs,p,rb_float_new(dchi2dpar[p]));
	}
      }
    }
  }
  return rb_float_new(chi2);
}
//_____________________________________________________________________________

extern "C" void Init_dcs(){
  //-+-RDOC-+- 
  rb_cPWA = rb_define_module("PWA");
  VALUE rb_cDcs = rb_define_module_under(rb_cPWA,"Dcs");
  rb_define_method(rb_cDcs,"fcn_val",RUBY_FUNC(rb_dcs_fcn_val),3);
  rb_define_method(rb_cDcs,"calc_dcs",RUBY_FUNC(rb_dcs_calc_dcs),2);
}
//_____________________________________________________________________________
