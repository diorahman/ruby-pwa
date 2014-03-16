require 'optparse'
#
# Initialize Ruby-ROOT
#
def init_ruby_root
  require "#{ENV['ROOTSYS']}/lib/libRuby"
  gROOT.Reset
  gStyle.SetPalette(1,0)
  gStyle.SetOptStat(0)
end
#
# Ignore 'unknown arguments' in _argv_
#
def parse_args(parser,argv)
  args2parse = argv.dup
  args = nil
  loop{
    begin
      args = parser.parse(args2parse)
      break
    rescue OptionParser::InvalidOption => opt
      args = []
      opt.recover(args)
      args2parse.delete_if{|arg| args.include?(arg)}
    end
  }
  args
end
#
# Divide a canvas into _num_ pads.
#
def divide_canvas(canvas,num)
  num_div = Math.sqrt(num).round + 1
  num_div = Math.sqrt(num).to_i if(Math.sqrt(num).round == Math.sqrt(num))
  canvas.Divide(num_div,num_div,0,0)
end
#
# Connects ROOT application to canvases (it will stop if any canvas is killed)
#
def run_app
  gApplication.Connect("TCanvas","Closed()","TApplication",gApplication,
		       "Terminate()")
  gApplication.Run
end
