// Author: Mike Williams
//_____________________________________________________________________________
#include "ruby-complex.h"
#include "pwa-src.h"
// globals:
VALUE rb_cPWA;
VALUE rb_cCppVectorDbl2D;
VALUE rb_cCppVectorFlt2D;
VALUE rb_cCppVectorDbl3D;
VALUE rb_cCppVectorFlt3D;
VectorDbl2D __VectorDbl2D__;
VectorFlt2D __VectorFlt2D__;
VectorDbl3D __VectorDbl3D__;
VectorFlt3D __VectorFlt3D__;
//_____________________________________________________________________________
/// Tell Ruby to use this function when garbage collecting CppVectorDbl2D
void cppvectdbl2d_free(void *__ptr){
  delete (VectorDbl2D*)__ptr;
  __ptr = 0;
}
/// Tell Ruby to use this function when garbage collecting CppVectorFlt2D
void cppvectflt2d_free(void *__ptr){
  delete (VectorFlt2D*)__ptr;
  __ptr = 0;
}
/// Tell Ruby to use this function when garbage collecting CppVectorDbl3D
void cppvectdbl3d_free(void *__ptr){
  delete (VectorDbl3D*)__ptr;
  __ptr = 0;
}
/// Tell Ruby to use this function when garbage collecting CppVectorFlt3D
void cppvectflt3d_free(void *__ptr){
  delete (VectorFlt3D*)__ptr;
  __ptr = 0;
}
//_____________________________________________________________________________

/// Obtains the C++ pointer from the Ruby object
template <typename _Tp> _Tp* get_cpp_ptr(VALUE __ruby_obj,const _Tp &__dummy){
  _Tp *ptr;
  Data_Get_Struct(__ruby_obj,_Tp,ptr);
  return ptr;
}
//_____________________________________________________________________________
/* Creates an empty vector */
VALUE rb_cppvectdbl2d_new(VALUE __class){
  VectorDbl2D *ptr = new VectorDbl2D();
  return Data_Wrap_Struct(__class,0,cppvectdbl2d_free,ptr);
}
/* Creates an empty vector */
VALUE rb_cppvectflt2d_new(VALUE __class){
  VectorFlt2D *ptr = new VectorFlt2D();
  return Data_Wrap_Struct(__class,0,cppvectflt2d_free,ptr);
}
/* Creates an empty vector */
VALUE rb_cppvectdbl3d_new(VALUE __class){
  VectorDbl3D *ptr = new VectorDbl3D();
  return Data_Wrap_Struct(__class,0,cppvectdbl3d_free,ptr);
}
/* Creates an empty vector */
VALUE rb_cppvectflt3d_new(VALUE __class){
  VectorFlt3D *ptr = new VectorFlt3D();
  return Data_Wrap_Struct(__class,0,cppvectflt3d_free,ptr);
}
//_____________________________________________________________________________
/// Resizes the vector
template <typename _Tp> void cppvect2d_resize(_Tp *__ptr,VALUE __ary){
  int size1 = RARRAY(__ary)->len;
  __ptr->resize(size1);
  for(int i = 0; i < size1; i++) {
    int size2 = RARRAY(rb_ary_entry(__ary,i))->len;
    (*__ptr)[i].resize(size2);
  }
}
/* call-seq: resize(ary2d) -> self
 * 
 * Resize the vector to have same dimensions as 2D Ruby Array <em>ary2d</em>.
 */
VALUE rb_cppvectdbl2d_resize(VALUE __self,VALUE __ary){
  VectorDbl2D *ptr = get_cpp_ptr(__self,__VectorDbl2D__);
  cppvect2d_resize(ptr,__ary);
  return __self;
}
/* call-seq: resize(ary2d) -> self
 * 
 * Resize the vector to have same dimensions as 2D Ruby Array <em>ary2d</em>.
 */
VALUE rb_cppvectflt2d_resize(VALUE __self,VALUE __ary){
  VectorFlt2D *ptr = get_cpp_ptr(__self,__VectorFlt2D__);
  cppvect2d_resize(ptr,__ary);
  return __self;
}
//_____________________________________________________________________________
/// Resizes the vector
template <typename _Tp> void cppvect3d_resize(_Tp *__ptr,VALUE __ary){
  int size1 = RARRAY(__ary)->len;
  __ptr->resize(size1);
  for(int i = 0; i < size1; i++) {
    VALUE ary2 = rb_ary_entry(__ary,i);
    int size2 = RARRAY(ary2)->len;
    (*__ptr)[i].resize(size2);
    for(int j = 0; j < size2; j++){
      int size3 = RARRAY(rb_ary_entry(ary2,j))->len;
      (*__ptr)[i][j].resize(size3);
    }
  }
}
/* call-seq: resize(ary3d) -> self
 * 
 * Resize the vector to have same dimensions as 3D Ruby Array <em>ary3d</em>.
 */
VALUE rb_cppvectdbl3d_resize(VALUE __self,VALUE __ary){
  VectorDbl3D *ptr = get_cpp_ptr(__self,__VectorDbl3D__);
  cppvect3d_resize(ptr,__ary);
  return __self;
}
/* call-seq: resize(ary3d) -> self
 * 
 * Resize the vector to have same dimensions as 3D Ruby Array <em>ary3d</em>.
 */
VALUE rb_cppvectflt3d_resize(VALUE __self,VALUE __ary){
  VectorFlt3D *ptr = get_cpp_ptr(__self,__VectorFlt3D__);
  cppvect3d_resize(ptr,__ary);
  return __self;
}
//_____________________________________________________________________________
/* call-seq: [](i,j) -> Complex
 *
 * Returns the (i,j) entry of the vector. The actual values are stored as C++
 * complex<double>'s. This method converts them to Ruby Complex, thus it is 
 * slow and should only be used for diagnostic purposes.
 *
 */
VALUE rb_cppvectdbl2d_entry(VALUE __self,VALUE __i,VALUE __j){
  int i = NUM2INT(__i),j = NUM2INT(__j);
  VectorDbl2D *ptr = get_cpp_ptr(__self,__VectorDbl2D__);
  return rb_complex_new((*ptr)[i][j]);
}
/* call-seq: [](i,j) -> Complex
 *
 * Returns the (i,j) entry of the vector. The actual values are stored as C++
 * complex<double>'s. This method converts them to Ruby Complex, thus it is 
 * slow and should only be used for diagnostic purposes.
 *
 */
VALUE rb_cppvectflt2d_entry(VALUE __self,VALUE __i,VALUE __j){
  int i = NUM2INT(__i),j = NUM2INT(__j);
  VectorFlt2D *ptr = get_cpp_ptr(__self,__VectorFlt2D__);
  return rb_complex_new((*ptr)[i][j]);
}
//_____________________________________________________________________________
/* call-seq: [](i,j,k) -> Complex
 *
 * Returns the (i,j,k) entry of the vector. The actual values are stored as C++
 * complex<double>'s. This method converts them to Ruby Complex, thus it is 
 * slow and should only be used for diagnostic purposes.
 *
 */
VALUE rb_cppvectdbl3d_entry(VALUE __self,VALUE __i,VALUE __j,VALUE __k){
  int i = NUM2INT(__i),j = NUM2INT(__j),k = NUM2INT(__k);
  VectorDbl3D *ptr = get_cpp_ptr(__self,__VectorDbl3D__);
  return rb_complex_new((*ptr)[i][j][k]);
}
/* call-seq: [](i,j,k) -> Complex
 *
 * Returns the (i,j,k) entry of the vector. The actual values are stored as C++
 * complex<double>'s. This method converts them to Ruby Complex, thus it is 
 * slow and should only be used for diagnostic purposes.
 *
 */
VALUE rb_cppvectflt3d_entry(VALUE __self,VALUE __i,VALUE __j,VALUE __k){
  int i = NUM2INT(__i),j = NUM2INT(__j),k = NUM2INT(__k);
  VectorFlt3D *ptr = get_cpp_ptr(__self,__VectorFlt3D__);
  return rb_complex_new((*ptr)[i][j][k]);
}
//_____________________________________________________________________________
/* call-seq: []=(i,j,c) -> c
 *
 * Set the (i,j) entry of the vector.
 */
VALUE rb_cppvectdbl2d_set_entry(VALUE __self,VALUE __i,VALUE __j,VALUE __c){
  int i = NUM2INT(__i),j = NUM2INT(__j);
  VectorDbl2D *ptr = get_cpp_ptr(__self,__VectorDbl2D__);
  (*ptr)[i][j] = CPP_COMPLEX(double,__c);
  return __c;
}
/* call-seq: []=(i,j,c) -> c
 *
 * Set the (i,j) entry of the vector.
 */
VALUE rb_cppvectflt2d_set_entry(VALUE __self,VALUE __i,VALUE __j,VALUE __c){
  int i = NUM2INT(__i),j = NUM2INT(__j);
  VectorFlt2D *ptr = get_cpp_ptr(__self,__VectorFlt2D__);
  (*ptr)[i][j] = CPP_COMPLEX(float,__c);
  return __c;
}
//_____________________________________________________________________________
/* call-seq: []=(i,j,k,c) -> c
 *
 * Set the (i,j,k) entry of the vector.
 */
VALUE rb_cppvectdbl3d_set_entry(VALUE __self,VALUE __i,VALUE __j,VALUE __k,
				VALUE __c){
  int i = NUM2INT(__i),j = NUM2INT(__j),k = NUM2INT(__k);
  VectorDbl3D *ptr = get_cpp_ptr(__self,__VectorDbl3D__);
  (*ptr)[i][j][k] = CPP_COMPLEX(double,__c);
  return __c;
}
/* call-seq: []=(i,j,k,c) -> c
 *
 * Set the (i,j,k) entry of the vector.
 */
VALUE rb_cppvectflt3d_set_entry(VALUE __self,VALUE __i,VALUE __j,VALUE __k,
				VALUE __c){
  int i = NUM2INT(__i),j = NUM2INT(__j),k = NUM2INT(__k);
  VectorFlt3D *ptr = get_cpp_ptr(__self,__VectorFlt3D__);
  (*ptr)[i][j][k] = CPP_COMPLEX(double,__c);
  return __c;
}
//_____________________________________________________________________________
/// Iterates over all entries in the vector
template <typename _Tp> void cppvect2d_each(_Tp *__ptr){
  int size1 = (int)__ptr->size();
  for(int i = 0; i < size1; i++){
    int size2 = (int)(*__ptr)[i].size();
    for(int j = 0; j < size2; j++){
      VALUE yld_ary = rb_ary_new();
      rb_ary_store(yld_ary,0,INT2FIX(i));
      rb_ary_store(yld_ary,1,INT2FIX(j));
      rb_ary_store(yld_ary,2,rb_complex_new((*__ptr)[i][j]));
      rb_yield(yld_ary);
    }
  }
}
/* Iterates over vector entries */
VALUE rb_cppvectdbl2d_each(VALUE __self){
  VectorDbl2D *ptr = get_cpp_ptr(__self,__VectorDbl2D__);
  cppvect2d_each(ptr);
  return __self;
}
/* Iterates over vector entries */
VALUE rb_cppvectflt2d_each(VALUE __self){
  VectorFlt2D *ptr = get_cpp_ptr(__self,__VectorFlt2D__);
  cppvect2d_each(ptr);
  return __self;
}
//_____________________________________________________________________________
/// Iterates over all entries in the vector
template <typename _Tp> void cppvect3d_each(_Tp *__ptr){
  int size1 = (int)__ptr->size();
  for(int i = 0; i < size1; i++){
    int size2 = (int)(*__ptr)[i].size();
    for(int j = 0; j < size2; j++){
      int size3 = (int)(*__ptr)[i][j].size();
      for(int k = 0; k < size3; k++){	
	VALUE yld_ary = rb_ary_new();
	rb_ary_store(yld_ary,0,INT2FIX(i));
	rb_ary_store(yld_ary,1,INT2FIX(j));
	rb_ary_store(yld_ary,2,INT2FIX(k));
	rb_ary_store(yld_ary,3,rb_complex_new((*__ptr)[i][j][k]));
	rb_yield(yld_ary);
      }
    }
  }
}
/* Iterates over vector entries */
VALUE rb_cppvectdbl3d_each(VALUE __self){
  VectorDbl3D *ptr = get_cpp_ptr(__self,__VectorDbl3D__);
  cppvect3d_each(ptr);
  return __self;
}
/* Iterates over vector entries */
VALUE rb_cppvectflt3d_each(VALUE __self){
  VectorFlt3D *ptr = get_cpp_ptr(__self,__VectorFlt3D__);
  cppvect3d_each(ptr);
  return __self;
}
//_____________________________________________________________________________

/* Clear all entries (free memory) */
VALUE rb_cppvectdbl2d_clear(VALUE __self){
  VectorDbl2D *ptr = get_cpp_ptr(__self,__VectorDbl2D__);
  vector<vector<complex<double> > >().swap(*ptr);
  return __self;
}
/* Clear all entries (free memory) */
VALUE rb_cppvectflt2d_clear(VALUE __self){
  VectorFlt2D *ptr = get_cpp_ptr(__self,__VectorFlt2D__);
  vector<vector<complex<float> > >().swap(*ptr);
  return __self;
}
/* Clear all entries (free memory) */
VALUE rb_cppvectdbl3d_clear(VALUE __self){
  VectorDbl3D *ptr = get_cpp_ptr(__self,__VectorDbl3D__);
  vector<vector<vector<complex<double> > > >().swap(*ptr);
  return __self;
}
/* Clear all entries (free memory) */
VALUE rb_cppvectflt3d_clear(VALUE __self){
  VectorFlt3D *ptr = get_cpp_ptr(__self,__VectorFlt3D__);
  vector<vector<vector<complex<float> > > >().swap(*ptr);
  return __self;
}
//_____________________________________________________________________________

extern "C" void Init_cppvector(){
  rb_cPWA = rb_define_module("PWA");
  /* CppVectorDbl2D */
  rb_cCppVectorDbl2D = rb_define_class_under(rb_cPWA,"CppVectorDbl2D",
					     rb_cObject);
  rb_define_singleton_method(rb_cCppVectorDbl2D,"new",
			     RUBY_FUNC(rb_cppvectdbl2d_new),0);
  rb_define_method(rb_cCppVectorDbl2D,"resize",
		   RUBY_FUNC(rb_cppvectdbl2d_resize),1);  
  rb_define_method(rb_cCppVectorDbl2D,"[]",RUBY_FUNC(rb_cppvectdbl2d_entry),
		   2);
  rb_define_method(rb_cCppVectorDbl2D,"[]=",
		   RUBY_FUNC(rb_cppvectdbl2d_set_entry),3);
  rb_define_method(rb_cCppVectorDbl2D,"each",RUBY_FUNC(rb_cppvectdbl2d_each),
		   0);
  rb_define_method(rb_cCppVectorDbl2D,"clear",RUBY_FUNC(rb_cppvectdbl2d_clear),
		   0);
  /* CppVectorFlt2D */
  rb_cCppVectorFlt2D = rb_define_class_under(rb_cPWA,"CppVectorFlt2D",
					     rb_cObject);
  rb_define_singleton_method(rb_cCppVectorFlt2D,"new",
			     RUBY_FUNC(rb_cppvectflt2d_new),0);
  rb_define_method(rb_cCppVectorFlt2D,"resize",
		   RUBY_FUNC(rb_cppvectflt2d_resize),1);  
  rb_define_method(rb_cCppVectorFlt2D,"[]",RUBY_FUNC(rb_cppvectflt2d_entry),
		   2);
  rb_define_method(rb_cCppVectorFlt2D,"[]=",
		   RUBY_FUNC(rb_cppvectflt2d_set_entry),3);
  rb_define_method(rb_cCppVectorFlt2D,"each",RUBY_FUNC(rb_cppvectflt2d_each),
		   0);
  rb_define_method(rb_cCppVectorFlt2D,"clear",RUBY_FUNC(rb_cppvectflt2d_clear),
		   0);
  /* CppVectorDbl3D */
  rb_cCppVectorDbl3D = rb_define_class_under(rb_cPWA,"CppVectorDbl3D",
					     rb_cObject);
  rb_define_singleton_method(rb_cCppVectorDbl3D,"new",
			     RUBY_FUNC(rb_cppvectdbl3d_new),0);
  rb_define_method(rb_cCppVectorDbl3D,"resize",
		   RUBY_FUNC(rb_cppvectdbl3d_resize),1);  
  rb_define_method(rb_cCppVectorDbl3D,"[]",RUBY_FUNC(rb_cppvectdbl3d_entry),
		   3);
  rb_define_method(rb_cCppVectorDbl3D,"[]=",
		   RUBY_FUNC(rb_cppvectdbl3d_set_entry),4);
  rb_define_method(rb_cCppVectorDbl3D,"each",RUBY_FUNC(rb_cppvectdbl3d_each),
		   0);
  rb_define_method(rb_cCppVectorDbl3D,"clear",RUBY_FUNC(rb_cppvectdbl3d_clear),
		   0);
  /* CppVectorFlt3D */
  rb_cCppVectorFlt3D = rb_define_class_under(rb_cPWA,"CppVectorFlt3D",
					     rb_cObject);
  rb_define_singleton_method(rb_cCppVectorFlt3D,"new",
			     RUBY_FUNC(rb_cppvectflt3d_new),0);
  rb_define_method(rb_cCppVectorFlt3D,"resize",
		   RUBY_FUNC(rb_cppvectflt3d_resize),1);  
  rb_define_method(rb_cCppVectorFlt3D,"[]",RUBY_FUNC(rb_cppvectflt3d_entry),
		   3);
  rb_define_method(rb_cCppVectorFlt3D,"[]=",
		   RUBY_FUNC(rb_cppvectflt3d_set_entry),4);
  rb_define_method(rb_cCppVectorFlt3D,"each",RUBY_FUNC(rb_cppvectflt3d_each),
		   0);
  rb_define_method(rb_cCppVectorFlt3D,"clear",RUBY_FUNC(rb_cppvectflt3d_clear),
		   0);
}
//_____________________________________________________________________________
