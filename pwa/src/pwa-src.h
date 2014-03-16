// -*- C++ -*-
// Author: Mike Williams
//_____________________________________________________________________________
#ifndef _pwa_src_H
#define _pwa_src_H

#include <vector>
#include <complex>
#include "ruby-complex.h"

using namespace std;

//_____________________________________________________________________________
typedef vector<vector<complex<double> > > VectorDbl2D;
typedef vector<vector<complex<float> > >  VectorFlt2D;
typedef vector<vector<vector<complex<double> > > > VectorDbl3D;
typedef vector<vector<vector<complex<float> > > > VectorFlt3D;
/* defined in cppvector.cpp */
extern VALUE rb_cPWA;
extern VALUE rb_cCppVectorDbl2D;
extern VALUE rb_cCppVectorFlt2D;
extern VALUE rb_cCppVectorDbl3D;
extern VALUE rb_cCppVectorFlt3D;
extern VectorDbl2D __VectorDbl2D__;
extern VectorFlt2D __VectorFlt2D__;
extern VectorDbl3D __VectorDbl3D__;
extern VectorFlt3D __VectorFlt3D__;
//_____________________________________________________________________________

template <typename _Tp> _Tp* get_cpp_ptr(VALUE __ruby_obj,const _Tp &__dummy);

complex<double> get_amp_total(const vector<complex<float> > &__amps,
			      const vector<complex<double> > &__params);

VALUE rb_dataset_set_params(VALUE __self,VALUE __pars,VALUE __vars,
			    VALUE __set_derivs);
//_____________________________________________________________________________

#endif /* _pwa_src_H */
