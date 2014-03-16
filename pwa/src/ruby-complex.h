// -*- C++ -*-
// Author: Mike Williams
//_____________________________________________________________________________
#ifndef _ruby_complex_H
#define _ruby_complex_H
//_____________________________________________________________________________
#include <iostream>
#include <complex>
#include "ruby.h"

#define RUBY_FUNC(f) ((VALUE (*)(...)) f)

using namespace std;
//_____________________________________________________________________________
/// Provide multiplication b/t complex<float> and complex<double>.
template <typename __U,typename __V> 
complex<double> operator*(const complex<__U> &__c1,const complex<__V> &__c2){
  double x1 = __c1.real(),x2 = __c2.real(),y1 = __c1.imag(),y2 = __c2.imag();
  return complex<double>(x1*x2-y1*y2,x1*y2+y1*x2);
}
//_____________________________________________________________________________
/// Create a Ruby Complex object from a C++ complex object.
template<typename __Tp>
VALUE rb_complex_new(const complex<__Tp> &__c){
  static VALUE rb_cComplex = rb_class_of(rb_eval_string("Complex.new(0,0)"));
  static ID rb_id_new = rb_intern("new");
  return rb_funcall(rb_cComplex,rb_id_new,2,rb_float_new(__c.real()),
		    rb_float_new(__c.imag()));
}
//_____________________________________________________________________________
/// Returns the real part of @a c
VALUE rb_complex_real(VALUE __c){
  static ID rb_id_real = rb_intern("real");  
  return rb_funcall(__c,rb_id_real,0);
}
//_____________________________________________________________________________
/// Returns the imaginary part of @a c
VALUE rb_complex_imag(VALUE __c){
  static ID rb_id_imag = rb_intern("imag");
  return rb_funcall(__c,rb_id_imag,0);
}  
//_____________________________________________________________________________
/// Convert Ruby Complex to complex<type>
#define CPP_COMPLEX(type,c) \
    complex<type>(NUM2DBL(rb_complex_real(c)),NUM2DBL(rb_complex_imag(c)))
//_____________________________________________________________________________

#endif /* _ruby_complex_H */
