require 'data_haack'


module DataHaack

  # Generic base class for DataHack mappings between Ruby object and some basic data structure (Hash, Array, atomics).
  #
  class Mapping 
    include Options

    attr_accessor :cls, :name
    attr_accessor :creater
    
    def initialize_after_opts
      super
      @creater ||= :create
    end

    # Subclasses can override.
    def map? mapper, obj, result, cls, path
      $stderr.puts "  ==> map #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_MAP
      true
    end
    
    def unmap? mapper, obj, result, cls, path
      $stderr.puts "  ==> unmap? #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      true
    end

    def map *args
      raise Error::SubclassResponsibility, "#{self} map"
    end

    def unmap! *args
      raise Error::SubclassResponsibility, "#{self} map"
    end


    def create!(value)
      case @creater
      when nil
        nil
      when Symbol
        @cls.send(@creater, value)
      when Proc
        @creater.call(value)
      else
        raise TypeError
      end
    end


    def object_changed! mapper, obj, path = nil
      path ||= mapper.path
      return if mapper.object_created[obj]
      (mapper.object_changed[obj] ||= [ ]) << [ @name, path ]
    end
    
    
    def object_created! mapper, obj, path = nil
      path ||= mapper.path
      (mapper.object_created[obj] ||= [ ]) << [ @name, path ]
    end
    

    # REPLACE ME WITH THE Mapping::Builder.
    def self.create_class_to_mapping hash
      result = { }
      hash.each do | cls, h |
        case cls
        when Class
          m = ClassMapping.new(:cls => cls)
        when ValueMapping
          m = cls
        end
        
        case m
        when ClassMapping
          x = h[:attributes] || [ ]
          x = x.map{|e| AttributeMapping.new(:name => e)}
          m.attributes = x
          
          x = h[:associations] || [ ]
          x = x.map{|e| AssociationMapping.new(:name => e)}
          m.associations = x
        end
        
        result[cls] = m
      end
      result
    end

  end
    
    
  class ValueMapping < Mapping
    include Options

    attr_accessor :mapper, :unmapper
    attr_accessor :enumeration_limit
    
    def initialize_before_opts
      case @opts
      when Symbol
        @opts = { :name => @opts }
      end
      case x = @opts[:name]
      when Array
        @opts = { :cls => x[0], :name => x[1] }
      end
      
      super
    end

    def initialize_after_opts
      super
      @opts[:name] ||= @opts[:cls].name.dup.freeze if @opts[:cls]
    end
    
    # Use the mapper on the obj to get the value.
    def map(mapper, obj, result, cls, path)
      return nil unless map?(mapper, obj, result, cls, path)
      case @mapper
      when nil
        nil
      when Symbol
        obj.send(@mapper)
      when Proc
        @mapper.call(obj)
      else
        raise TypeError
      end
    end
    
    # Use the unmapper on the cls.
    def unmap!(mapper, obj, result, cls, path)
      # $stderr.puts "  ### unmap! #{mapper} #{obj.class} #{result.inspect} #{cls} #{path.inspect}"
      return nil unless unmap?(mapper, obj, result, cls, path)
      case @unmapper
      when nil
        nil
      when Symbol
        (cls || @cls).send(@unmapper, result)
      when Proc
        @unmapper.call(result)
      else
        raise TypeError
      end
    end
    
    
    # Handle enumerated values.
    # FIXME.
    def enumerate mapper, obj, result, cls, path
    end
    
    # Handle unmap! of enumerated values.
    def unmap_enumeration! mapper, obj, result, cls, path
      case result
      when Array
        # prototype: DON'T do it this way
        # get only what we need via the finder/association
        if @enumeration_limit
          result = result[0 .. @enumeration_limit]
        end
        i = -1
        result = result.map{|e| mapper._unmap!(e, nil, cls, "#{path}[#{i += 1}]")}
      else
        result = mapper._unmap!(obj, result, cls, path) 
      end
      $stderr.puts "    <== denumerate! #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      result
    end
    
  end # class
  
end # module

