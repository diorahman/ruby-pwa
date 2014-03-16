# Author:: Mike Williams
require 'ftools'
require 'create/parameter'
require 'create/amp'
require 'create/dataset'
require 'create/rule'
#
# The Create module is used to create a new fit. Once any necessary datasets
# are set up (eg. amplitude files have been generated, any utility files such
# as dcs.xml files or cuts/norm-int/kinvar files are properly placed), a fit
# can be built.
#
# ==Creating a Fit
# Examples given below will be for a generic fit w/ 4 amplitude files:
# * tag1=a:tag2=+:.amps(.xml)
# * tag1=a:tag2=-:.amps(.xml)
# * tag1=b:tag2=+:.amps(.xml)
# * tag1=b:tag2=-:.amps(.xml)
# The .xml extension will be present in the differential cross section case 
# only. 
#
# The differential cross section amplitudes will be located in 
# <tt>/test/dcs/WbinXXXX-YYYY/</tt>. Each of these directories will also 
# contain a file <tt>dcs.xml</tt> containing the measured differential cross 
# section values/errors to be fit to.
#
# The event dependent fit will have top directory <tt>/test/evt/</tt> w/ 
# subdirectories <tt>data,acc,raw</tt> each of which has subdirectories
# <tt>WbinXXXX-YYYY</tt> which contain the amplitude files. Each of these
# directories also contains a kinematic variables file <tt>kinvar.xml</tt>. The
# <tt>data,acc</tt> bins each contain a _cuts_ file. The names of which are 
# stored in the Ruby global Hash <tt>$data_cuts_file</tt> 
# (<tt>$acc_cuts_file</tt>) located in the file 
# <tt>/test/evt/data_cuts_files.rb</tt> (<tt>/test/evt/acc_cuts_files.rb</tt>).
# The <tt>acc,raw</tt> bins each contain a _normint_ file. All the <tt>raw</tt>
# _normint_ files are called <tt>coherence=tag1:.norm-int.xml</tt> while the
# <tt>acc</tt> _normint_ file names are stored in the global Hash 
# <tt>$acc_norm_file</tt> also defined in <tt>/test/evt/acc_cuts_files.rb</tt>.
#
# ===Amplitude Rules
# For each amplitude file that is to be used in the fit, the user must supply
# a Create::Rule that determines how the amplitude is to be used at fit time.
# These are generally stored in any number of _rules_ files.
#
# For code documentation for classes used for rules see:
# * Create::Rule
# * Create::Amp
# * Create::Parameter
#
# ====Example
# For our simple example, we'll assume a single rule can be used for all of our
# amplitudes (if not we just need to supply more rules).
#
#  # file /test/rules.rb
#  # rule for all files
#  Create::Rule.new(/./){|amp|
#    amp.parameter(:mod){|par|
#      par.tags = ['tag1']
#      par.start_value = [-1,1]
#      par.limits = :no_limits
#      par.step_size = :variable
#    }
#    amp.parameter(:phase){|par|
#      par.tags = ['tag1','tag2']
#      par.start_value = [0,2*Math::PI]
#      par.limits = :no_limits
#      par.step_size = :variable
#    }
#    amp.value_method = :val_meth
#  }
#
# So, for each file we're telling the fitter that we need 2 MINUIT parameters
# w/ handles <tt>:mod,:phase</tt>. In <tt>val_meth</tt>, we can simply refer to
# the parameters by these handles (instead of their full names). If we use all
# 4 of the amplitudes specified above, we'd obtain the following MINUIT 
# parameters:
# * <tt>mod:tag1=a</tt> used by:
#   * <tt>tag1=a:tag2=+:.amps</tt>
#   * <tt>tag1=a:tag2=-:.amps</tt>
# * <tt>mod:tag1=b</tt> used by:
#   * <tt>tag1=b:tag2=+:.amps</tt>
#   * <tt>tag1=b:tag2=-:.amps</tt>
# * <tt>phase:tag1=a:tag2=+</tt> used by:
#   * <tt>tag1=a:tag2=+:.amps</tt>
# * <tt>phase:tag1=a:tag2=-</tt> used by:
#   * <tt>tag1=a:tag2=-:.amps</tt>
# * <tt>phase:tag1=b:tag2=+</tt> used by:
#   * <tt>tag1=b:tag2=+:.amps</tt>
# * <tt>phase:tag1=b:tag2=-</tt> used by:
#   * <tt>tag1=b:tag2=-:.amps</tt>
#
# Notice that the <tt>tags</tt> attribute of Create::Parameter can be used to 
# determine which amplitudes share parameters. See section below for 
# discussion on <tt>val_meth</tt>
#
# ===Fit Methods
#
# The method <tt>val_meth</tt> must be available at fit run-time. It must be of
# the type <em>val_meth(pars,vars)->Complex</em>. This method tells the fitter
# how to use each amplitude's MINUIT parameters (and possibly kinematic 
# variables for the differential cross section case) to form the complex number
# which is to be multiplied by the amplitude value when calculating the 
# intensity.
#
# Derivative methods, in this case <tt>dval_meth_dmod,dval_meth_dphase</tt>,
# must also be supplied at run-time. They must calculate the derivative of 
# <tt>val_meth</tt> w/r to the MINUIT parameters.
#
# ===Ruby Example
#  # file methods.rb
#  # value method
#  def val_meth(pars,vars)
#    Complex.polar(pars[:mod],pars[:phase])
#  end
#  # dval/dmod
#  def dval_meth_dmod(pars,vars)
#    Math.exp(Complex::I*pars[:phase])
#  end
#  # dval/dphase
#  def dval_meth_dphase(pars,vars)
#    Complex::I*Complex.polar(pars[:mod],pars[:phase])
#  end
#
# If this is the differential cross section case, kinematic variables can be
# used like <tt>vars[:x]</tt> to access variable _x_.
#
# We then just need to make sure that <tt>methods.rb</tt> is loaded at run 
# time (see below).
# 
# What if we want to make our fit run faster by compiling our methods as c/c++
# code? You can always do this in Ruby by hand, but and easier way is provided
# via Create::CppMethods.
#
# ====C++ Example
#  # file compile_methods.rb
#  require 'create/cppmethods'
#  include Create
#  #
#  CppMethods.define_global  'complex<double> i(0,1)'
#  #
#  CppMethods[:val_meth] = "#{par(:mod)}*exp(i*#{par(:phase)})"
#  CppMethods[:dval_meth_dmod] = "exp(i*#{par(:phase)})"
#  CppMethods[:dval_meth_dphase] = "i*#{par(:mod)}*exp(i*#{par(:phase)})"
#  #
#  CppMethods.write 'methods'
# 
# This writes the file <tt>methods.cpp</tt> which we then need to compile into
# a shared object which can be loaded at run-time. Once this is done, the only
# difference b/t the 2 methods is speed.
#
# ===Setting Up Datasets
#
# Each fit can have any number of datsets. These can be different bins from a 
# single dataset, or completely different datasets...it doesn't matter.  To set
# these up for a fit, the user must write a _build_ file. See Create::Dataset
# for info specific to setting datasets.
#
# ====Example Build File
#  # file /test/fit/build.rb
#  require 'create'
#  require '/test/rules.rb'
#  #
#  Create.require_file '/test/evt/data_cuts_files.rb'
#  Create.require_file '/test/evt/acc_cuts_files.rb'
#  Create.methods_file 'methods'
#  #
#  type = ... :evt or :dcs...
#  #
#  Create.dataset('test',type){|dataset|
#    dataset.coherence_tags = ['tag1']
#    dataset.use_amps_matching '.' # use 'em all
#    if(dataset.type == :dcs)
#      dataset.dcs_file = 'dcs.xml'
#      dataset.read_amps_from '/test/dcs/Wbin2000-2010/'
#    else
#      dataset.read_amps_from '/test/evt/data/Wbin2000-2010/'
#      dataset.norm[:raw] = 'coherence=tag1:.norm-int.xml'
#      dataset.norm[:acc] = :$acc_norm_files
#      dataset.cuts[:data] = :$data_cuts_files
#      dataset.cuts[:acc] = :$acc_cuts_files
#      [:data,:acc,:raw].each{|dtype| dataset.kinvar[dtype] = 'kinvar.xml'}
#    end
#  }
#  #
#  Create.fit Dir.pwd # build it in currrent directory
#
# We would then just run <tt>ruby build.rb</tt> from <tt>/test/fit/</tt> to 
# _build_ the fit. Notice that by setting <tt>dataset.coherence_tags</tt> to be
# <tt>['tag1']</tt>, we're allowing 
# <tt>tag1=a:tag2=+:.amps,tag1=a:tag2=-:.amps</tt> and 
# <tt>tag1=b:tag2=+:.amps,tag1=b:tag2=-:.amps</tt> to interfere but not 
# <tt>tag1=a:tag2=+:.amps,tag1=b:tag2=+:.amps</tt>, etc...
#
# <b>The fit is now ready to run.</b>
module Create
  #
  # Array of Ruby methods files 
  #
  @@methods_file = []
  #
  # Array of Ruby files to require
  #
  @@require_file = []
  #
  # Copy this methods file to fit directory and require it at run-time.
  #
  def Create.methods_file(file) @@methods_file.push file; end
  #
  # Require this file at fit-time
  #
  def Create.require_file(file) @@require_file.push file; end
  #
  # Create a new dataset of _type_ w/ _name_ (see Dataset.new)
  #
  #  Create.dataset('name',type){|dataset|
  #    #...set dataset's attributes...
  #  }
  def Create.dataset(name,type); yield(Create::Dataset.new(name,type)); end
  #
  # Create a fit in directory _dir_. Should be called once all Dataset's, 
  # etc...have been set.
  #
  #  Create.fit Dir.pwd # create it in the current directory
  #
  def Create.fit(dir)
    Dir.mkdir(dir) unless File.exists?(dir)
    files,bins_dirs = [],[]
    Create::Dataset.each{|dset| 
      files.push dset.print(dir)
      bins_dirs.push dset.bins_dir
    }
    bins_dirs = bins_dirs.collect{|d| "'#{d}'"}.join(',')
    Create::Parameter.print(dir)
    ctrl_file = File.new("#{dir}/fit.ctrl.rb",'w')
    ctrl_file.print "#\n# Add the fit directory to the load path\n#\n"
    ctrl_file.print "$LOAD_PATH << File.expand_path(File.dirname(__FILE__))\n"
    ctrl_file.print "get_bin_limits(#{bins_dirs})\n"    
    ctrl_file.print "if(fit_mode? or plot_mode?)\n"
    @@methods_file.each{|mfile|
      methods_file = mfile.split('/').last
      mfile_wpath = dir + '/' + methods_file
      system "rm -f #{mfile_wpath}" if File.exists?(mfile_wpath)
      File.copy(mfile,"#{dir}/.") 
      ctrl_file.print "  require '#{methods_file}' # methods file\n"
    }
    @@require_file.each{|rfile| ctrl_file.print "  require '#{rfile}'\n"}
    ctrl_file.print "  require 'params.rb' if fit_mode?\n"
    files.each{|f| ctrl_file.print "  load '#{f}'\n"}
    ctrl_file.print "end\n"
    ctrl_file.print "if fit_mode? \n"
    ctrl_file.print "  PWA::Fcn.instance.minimization_proc{\n"
    ctrl_file.print "    begin\n      "
    ctrl_file.print "Minuit.migrad #add (max_calls,tolerance) if needed\n"
    ctrl_file.print "    rescue Minuit::CommandError\n"
    ctrl_file.print "      $!.print\n"
    ctrl_file.print "    ensure\n"
    ctrl_file.print "      Minuit.hesse\n"
    ctrl_file.print "    end\n  }\nend\n"
  end
end
