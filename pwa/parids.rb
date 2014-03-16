# Author:: Mike Williams

module PWA
  #
  # Module used to map parameter names to ids (Fixnum's).
  #
  module ParIDs
    #
    # key = name, value = id
    #
    @@name2id = Hash.new
    #    
    # Add parameter _name_
    #
    def ParIDs.push(name); 
      @@name2id[name] = @@name2id.length() + 1 if(@@name2id[name].nil?)
    end
    #
    # Returns _name_'s id
    #
    def ParIDs.[](name) 
      raise "Unknown parameter: #{name}" if(@@name2id[name].nil?)
      @@name2id[name]
    end
    #
    # Returns _id_'s name
    #
    def ParIDs.name(id) 
      @@name2id.each{|name,this_id| return name if(id == this_id)}
      nil
    end
    #
    # Set Hash to _name2id_.
    #
    def ParIDs.set(name2id); @@name2id = name2id; end
    #
    # Returns the highest parameter id
    #
    def ParIDs.max_id
      max = 0
      @@name2id.each{|name,id| max = id if(id > max)}
      max
    end
    #
  end
end
