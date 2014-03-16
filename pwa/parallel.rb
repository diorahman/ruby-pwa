# Author:: Mike Williams
module PWA
  #
  # This module encapsulates all needed calls to Ruby's MPI module.
  #
  module Parallel    
    # 2-D Array mapping process number to Datasets it needs to process
    @@div_procs = nil
    # Set to MPI::Comm::WORLD.size
    @@size = nil
    #
    # Maps Symbols to tags (Fixnum's).
    #
    def Parallel.sym_to_tag(sym)
      tag = nil
      case sym
      when :terminate
	tag = 0
      when :fcn_flag
	tag = 1
      when :params
	tag = 2
      when :fcn_val
	tag = 3
      when :derivs
	tag = 4
      when :message
	tag = 5
      when :max_par
	tag = 6
      end
      tag
    end
    #
    # Is current processor the master processor?
    #
    def Parallel.master?; (MPI::Comm::WORLD.rank == 0); end
    #
    # Which node are we on?
    #
    def Parallel.node; MPI::Comm::WORLD.rank; end
    #
    # Divides up Datasets among available processes.
    #
    def Parallel.divide
      procs = MPI::Comm::WORLD.size
      dsets = PWA::Dataset.length
      procs_div = Array.new(procs,dsets/procs)
      (dsets-(dsets/procs)*procs).times{|i| procs_div[i] += 1}
      dind = 0
      @@div_procs = []      
      procs_div.each_index{|proc| 
	@@div_procs[proc] = []
	procs_div[proc].times{|p| @@div_procs[proc].push dind; dind+=1}
      }
      @@size = procs
    end
    #
    # Print to screen Dataset divisions
    #
    def Parallel.show_divide      
      @@div_procs.each_index{|node| 
	datasets = @@div_procs[node].collect{|d| d}.join(',')
	puts "node: #{node} datasets: #{datasets}"
      }
    end
    #
    # Returns Array of Dataset indicies to be processed on processor that calls
    # it.
    #
    def Parallel.each_dataset_on_node(&block)
      @@div_procs[MPI::Comm::WORLD.rank].each{|d| yield(Dataset[d])}
    end
    #
    # Sends _var_ w/ _tag_ to all child processes.
    #
    def Parallel.send_to_children(var,tag)
      tag = Parallel.sym_to_tag(tag) if(tag.instance_of?(Symbol))
      1.upto(@@size-1){|rank| MPI::Comm::WORLD.send(var,rank,tag)}
    end
    #
    # Recieves _tag_ from all child processes.
    #
    def Parallel.recv_from_children(tag)
      tag = Parallel.sym_to_tag(tag) if(tag.instance_of?(Symbol))
      vars = []
      1.upto(@@size-1){|rank| vars.push(MPI::Comm::WORLD.recv(rank,tag)[0])}
      vars
    end
    #
    # Returns _tag_ which is recieved from the master processor.
    #
    def Parallel.recv_from_master(tag) 
      tag = Parallel.sym_to_tag(tag) if(tag.instance_of?(Symbol))
      MPI::Comm::WORLD.recv(0,tag)[0] 
    end
    #
    # Sends _var_ w/ _tag_ to the master processor.
    #
    def Parallel.send_to_master(var,tag) 
      tag = Parallel.sym_to_tag(tag) if(tag.instance_of?(Symbol))
      MPI::Comm::WORLD.send(var,0,tag) 
    end
    #
  end
end
