# Author:: Mike Williams
require 'utils.rb'
module Create
  # The Create::Rule class is used while creating a new fit. Each amplitude
  # file that is to be used in the fit must match a defined Rule. The Rule 
  # determines how the amplitude will be used in the fit. When a Rule is 
  # created it is initialized with a regular expression. Any amplitude file
  # whose name matches this expression will be considered to match the Rule.
  # 
  # The _new_ method for Rule accepts a code block that will be executed 
  # yielding each amplitude file that is found to match the Rule. This code 
  # block should define any parameters needed by the amplitude and set the
  # value method (see Create::Amp for details).
  #
  # ==Example Usage
  #
  #  #
  #  # create a rule for 'some_amp'
  #  #
  #  Create::Rule.new(/some_amp/){|amp|
  #    # ...set up the amplitude...
  #  }
  #
  class Rule
    # All rules that have been created
    @@rules = Array.new
    # Regular expression which amplitude files must match to match _self_
    attr_reader :reg_expr
    #
    # Creates a new Rule for amplitudes whose names match regular expression
    # _reg_expr_. The code block _amp_block_ will be used on each amplitude
    # that matches _self_.
    #
    #  #
    #  # create a rule for 'some_amp'
    #  #
    #  Create::Rule.new(/some_amp/){|amp|
    #    # ...set up the amplitude...
    #  }
    #
    def initialize(reg_expr,&amp_block)
      raise "Error! No code block given." unless block_given?
      @reg_expr = reg_expr
      @amp_block = amp_block
      @@rules.push self
    end
    #
    # Iterates over each Rule that has been created.
    #
    def Rule.each; @@rules.each{|rule| yield rule}; end
    #
    # Does _file_ match this Rule's regular expression?
    #
    def matches?(file); matches_exprs?(file,[@reg_expr]); end
    #
    # Use this Rule to create amplitude _file_ for a fit.
    #
    def create_amp(file)    
      amp = Create::Amp.new(file)
      @amp_block.call(amp)
      amp
    end
    #
  end
  #
end
