# Author:: Mike Williams
module Create
  # The Create::CppMethods module can be used to compile c++ code into a shared
  # object file which implements the c++ functions as Ruby functions. 
  #
  # ==Example Usage
  # File <tt>some_methods.rb</tt>,
  #
  #  require 'create/cppmethods'
  #  include Create
  #
  #  CppMethods.define_global  'complex<double> i(0,1)'
  #  CppMethods.include_header 'some_header.h'
  #
  #  # turn real parameters :mod,:phase into a complex number
  #  CppMethods[:foo_val] = "#{par(:mod)}*exp(i*#{par(:phase)})"
  #  CppMethods[:dfoo_val_dmod] = "exp(i*#{par(:phase)})"
  #  CppMethods[:dfoo_val_dphase] = "i*#{par(:mod)}*exp(i*#{par(:phase)})"
  #
  #  # for dcs case, we can also use kinematic variables
  #  # here we show usage of C++ function defined in 'some_header' (some_c_foo)
  #  CppMethods[:dcs_val] = "#{par(:g)}*some_c_foo(#{var(:t)})"
  #  CppMethods[:ddcs_val_dg] = "some_c_foo(#{var(:t)})"
  #
  #  CppMethods.write 'some_methods'
  #
  # Then run,
  #  [thedude@bigL]$ ruby some_methods.rb
  #
  # to write the file <tt>some_methods.cpp</tt>. This will then need compiled,
  #  [thedude@bigL]$ make -C ..path..ruby-pwa/pwa/src/ ..path../some_methods.so
  #
  # Note: The make command w/ paths is written to screen when runing _ruby_ on
  # your methods file.
  #
  module CppMethods
    @@globals = []
    @@pars = {}
    @@vars = {}
    @@methods = {}
    @@headers = []
    #
    # Register a parameter handle (used by _par_, should not be used by user)
    #
    def CppMethods.define_parameter(sym); @@pars[sym] = :defined; end
    #
    # Register a variable handle (used by _var_, should not be used by user)
    #
    def CppMethods.define_variable(sym); @@vars[sym] = :defined; end
    #
    # Define a global (C++) variable
    #
    #  CppMethods.define_global 'complex<double> i(0,1)'
    #
    def CppMethods.define_global(gl); @@globals.push gl; end
    #
    # Include this header file
    #
    #  CppMethods.include_header 'some_header.h'
    #
    def CppMethods.include_header(file); @@headers.push file; end
    #
    # Define Ruby method _meth_ using C++ code string _code_str_
    #
    #  CppMethods[:foo_val] = "#{par(:mod)}*exp(i*#{par(:phase)})"
    #  CppMethods[:dfoo_val_dmod] = "exp(i*#{par(:phase)})"
    #  CppMethods[:dfoo_val_dphase] = "i*#{par(:mod)}*exp(i*#{par(:phase)})"
    #
    def CppMethods.[]=(meth,code_str); @@methods[meth] = code_str; end
    #
    # Write the ouput file (_file_name_.cpp)
    #
    def CppMethods.write(file_name)      
      file_name += '.cpp' unless file_name.include?('.cpp')
      file = File.new(file_name,'w')
      file.print "#include \"ruby-complex.h\"\n"
      @@headers.each{|h| file.print "#include \"#{h}\"\n"}
      file.print "//"; 77.times{ file.print '_'}; file.print "\n"
      file.print "// parameter symbols: \n"
      @@pars.each{|key,val| 
        file.print "static VALUE rb_sym_#{key} = "
	file.print "ID2SYM(rb_intern(\"#{key}\"));\n"
      }
      file.print "// variable symbols: \n"
      @@vars.each{|key,val| 
        file.print "static VALUE rb_sym_#{key} = "
	file.print "ID2SYM(rb_intern(\"#{key}\"));\n"
      }
      file.print "//"; 77.times{ file.print '_'}; file.print "\n"
      file.print "// globals: \n"
      @@globals.each{|gl| file.print "#{gl};\n"}
      file.print "//"; 77.times{ file.print '_'}; file.print "\n"
      file.print "// c++ methods: \n"
      @@methods.each{|key,val|
        file.print "VALUE rb_#{key}(VALUE self,VALUE pars,VALUE vars){\n"
	file.print "  complex<double> val = #{val};\n"
        file.print "  return rb_complex_new(val);\n"
        file.print "}\n"
      }
      file.print "//"; 77.times{ file.print '_'}; file.print "\n\n"
      file.print "extern \"C\" void Init_#{file_name.sub('.cpp','')}(){\n"
      @@methods.each{|key,val|
        file.print "  rb_define_global_function(\"#{key}\","
	file.print "RUBY_FUNC(rb_#{key}),2);\n"
      }
      file.print "}\n"
      file.print "//"; 77.times{ file.print '_'}; file.print "\n\n"
    end
    #
  end
end
#
# Use this w/in C++ code strings for MINUIT parameters
#
#  CppMethods[:foo_val] = "#{par(:mod)}*exp(i*#{par(:phase)})"
#
def par(sym) 
  Create::CppMethods.define_parameter sym
  "NUM2DBL(rb_hash_aref(pars,rb_sym_#{sym}))"
end
#
# Use this w/in C++ code strings for variables
#
#  CppMethods[:foo_val] = "1/(#{var(:t)} - 0.135*0.135)"
#
def var(sym)
  Create::CppMethods.define_variable sym
  "NUM2DBL(rb_hash_aref(vars,rb_sym_#{sym}))"
end
