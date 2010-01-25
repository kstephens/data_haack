require 'data_haack'

module DataHaack

  class Mapping 
    attr_accessor :cls, :name
    attr_accessor :creator
    
    def initialize opts = nil
      @creator ||= :create
      if opts
        opts.each do | k, v |
          send(:"#{k}=", v)
        end
      end
      
      raise ArgumentError, "no name" unless @name
    end
  
    def create!(value)
      case @creator
      when Symbol
        @cls.send(@creator, value)
      when Proc
        @creator.call(value)
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
    
    
  class ClassMapping < Mapping
    attr_accessor :attributes, :associations
    
    def initialize opts
      case opts
      when Class
        opts = { :cls => opts }
      end
      if opts
        opts[:name] ||= opts[:cls].name.dup.freeze
      end
      super
      @attributes.extend(NamedArray)
      @associations.extend(NamedArray)
    end
    
    module NamedArray
      def named x
        find { | e | x === e.name }
      end
    end
    
    def map(mapper, obj, result, cls, path)
      $stderr.puts "  ==> map #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_MAP
      return nil unless obj
      result ||= { }
      result[:_class] = @name || obj.class.name
      result[:_id] = obj.id
      attributes.each   { | m | m.map(mapper, obj, result, cls, path) }
      associations.each { | m | m.map(mapper, obj, result, cls, path) }
      result
    end
    
    def unmap!(mapper, obj, result, cls, path)
      $stderr.puts "  <== unmap! #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      return nil unless result
      cls ||= @cls
      unless obj
        obj = create!(result)
        object_created! mapper, obj, path
        $stderr.puts "    <== create! #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      end
      attributes.each   { | m | m.unmap!(mapper, obj, result, cls, path) }
      associations.each { | m | m.unmap!(mapper, obj, result, cls, path) }
      obj
    end
  end
  
  class ValueMapping < Mapping
    attr_accessor :getter, :setter
    attr_accessor :clearer, :appender, :popper
    attr_accessor :enumeration_limit
    
    def initialize opts = nil
      case opts
      when Symbol
        opts = { :name => opts }
      end
      case x = opts[:name]
      when Array
        opts = { :cls => x[0], :name => x[1] }
      end
      if opts
        opts[:name] ||= opts[:cls].name.dup.freeze
      end
      
      super
      
      @getter   ||= :"#{@name}"
      @setter   ||= :"#{@name}="
      @clearer  ||= nil
      @appender ||= :"<<"
      @popper   ||= :"pop"
    end
    
    def get(obj)
      case @getter
      when Symbol
        obj.send(@getter)
      when Proc
        @getter.call(obj)
      else
        raise TypeError
      end
    end
    
    def set!(obj, value)
      case @setter
      when Symbol
        obj.send(@setter, value)
      when Proc
        @setter.call(obj, value)
      else
        raise TypeError
      end
    end 
    
    def clear!(obj)
      case @clearer
      when nil
        set!(obj, [ ])
      when Symbol
        obj.send(@clearer, value)
      when Proc
        @clearer.call(obj, value)
      else
        raise TypeError
      end
    end
    
    def append!(obj, value)
      # Get the container to append to.
      obj = get(obj)
      case @appender
      when Symbol
        obj.send(@appender, value)
      when Proc
        @appender.call(obj, value)
      else
        raise TypeError
      end
    end 
    
    
    def pop!(obj, value)
      # Get the container to pop to.
      obj = get(obj)
      case @popper
      when Symbol
        obj.send(@popper, value)
      when Proc
        @popper.call(obj, value)
      else
        raise TypeError
      end
    end 
    
    
    # Use the getter to get the value.
    def map(mapper, obj, result, cls, path)
      get(obj)
    end
    
    # Use the setter to coerce the value.
    def unmap!(mapper, obj, result, cls, path)
      set!(obj, result)
    end
    
    
    # Handle enumerated values.
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
  
  
  class AttributeMapping < ValueMapping
    # Gets the object's attribute value and saves it in the result Hash using the Mapping's name.
    # A new result is constructed from the mapping of the object's attribute value.
    def map(mapper, obj, result, cls, path)
      mapper.path = path = "#{path}.#{@name}"
      $stderr.puts "  ==> map #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_MAP
      result[name] = mapper._map(get(obj), nil, nil, path)
    end
    
    # Sets the object's value, with the unmapped value from the result Hash index by the Mapping's name.
    def unmap!(mapper, obj, result, cls, path)
      mapper.path = path = "#{path}.#{@name}"
      $stderr.puts "  <== unmap! #{self.class} #{@name.inspect} #{obj.class} #{result.inspect} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      old_value = get(obj)
      new_value = unmap_enumeration!(mapper, nil, result[name], @cls || old_value.class, path)
      if old_value != new_value
        $stderr.puts "  <<=  unmap! old_value=#{old_value.inspect} new_value=#{new_value.inspect} #{path.inspect}" if VERBOSE_MAP
        set!(obj, new_value)
        object_changed! mapper, obj, path
      end
      new_value
    end
  end
  
  class AssociationMapping < ValueMapping
    def map(mapper, obj, result, cls, path)
      mapper.path = path = "#{path}.#{@name}"
      $stderr.puts "  ==> map #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_MAP
      value = get(obj)
      case value
      when Array
        # prototype: DON'T do it this way
        # get only what we need via the finder/association
        if @enumeration_limit
          value = value[0 .. @enumeration_limit]
        end
        i = -1
        value = value.map{|e| mapper._map(e, nil, @cls, "#{path}[#{i += 1}]")}
      else
        value = mapper._map(value, nil, @cls, path)
      end
      result[name] = value
    end
    
    def unmap!(mapper, obj, result, cls, path)
      mapper.path = path = "#{path}.#{@name}"
      $stderr.puts "  <== unmap! #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      
      old_value = get(obj)
      new_value = result[name]
      changed = false
      
      case new_value
      when Array
        i = -1
        values = [ ]
        new_values = [ ]
        
        # obj.name has a container.
        if old_value
          size_delta = new_value.size - old_value.size
          case
            # if new value container is smaller than old container,
            # pop N objects off the container.
          when size_delta < 0
            (0 .. - size_delta).times do 
              pop!(obj)
            end
          end
          
          old_value.zip(new_value).each do | (e, v) | 
            $stderr.puts "    <== unmap! element #{i + 1} : #{e.inspect} <= #{v.inspect} : #{path.inspect}" if VERBOSE_UNMAP
            if v 
              values << mapper._unmap!(e, v, @cls, "#{path}[#{i += 1}]")
            end
          end
        else
          new_value.each do | v |
            new_values << mapper._unmap!(nil, v, @cls, "#{path}[#{i += 1}]")
          end
        end
        
        unless old_value
          $stderr.puts "    <== unmap! clear! #{path.inspect}" if VERBOSE_UNMAP
          clear!(obj)
          changed = true
        end
        new_values.each do | e |
          $stderr.puts "    <== unmap! append! #{e.inspect} #{path.inspect}" if VERBOSE_UNMAP
          append!(obj, e);
          values << e
          changed = true
        end
      else
        new_value = mapper._unmap!(old_value, new_value, @cls, path)
        unless old_value
          set!(obj, new_value)
          changed = true
        end
      end
      
      object_changed! mapper, obj, path if changed
      
      # This might be slower, but it will be correct.
      get(obj)
    end
    
  end # class
   
end # module

