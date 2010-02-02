require 'data_haack/mapping'

module DataHaack

  class ClassMapping < Mapping
    include Options

    attr_accessor :attributes, :associations
    
    def initialize_before_opts
      case @opts
      when Class
        @opts = { :cls => @opts }
      end
      @opts[:name] ||= @opts[:cls].name.dup.freeze
      super
    end

    def initialize_after_opts
      super
      raise ArgumentError, "no name" unless @name
      @attributes ||= [ ]
      @associations ||= [ ]
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
      @attributes.each   { | m | m.map(mapper, obj, result, cls, path) }
      @associations.each { | m | m.map(mapper, obj, result, cls, path) }
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
      $stderr.puts "  <== ### unmap! #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      @attributes.each   { | m | m.unmap!(mapper, obj, result, cls, path) }
      @associations.each { | m | m.unmap!(mapper, obj, result, cls, path) }
      obj
    end

    # Subclasses may override.
    def create_attribute_mapping opts
      if obj = @attributes.named(opts[:name])
        obj.set_opts! opts
      else
        obj = block_given? ? yield : AttributeMapping.new(opts)
        obj.class_mapping = self
        @attributes << obj
      end
      obj
    end

    # Subclasses may override.
    def create_association_mapping opts, obj = nil
      if obj = @associations.named(opts[:name])
        obj.set_opts! opts
      else
        obj = block_given? ? yield : AssociationMapping.new(opts)
        obj.class_mapping = self
        @associations << obj
      end
      obj
    end
  end
  

  # Superclass for AttributeMapping and AssociationMapping.
  class PropertyMapping < ValueMapping
    attr_accessor :class_mapping
    attr_accessor :getter, :setter
    attr_accessor :clearer, :appender, :popper

    def initialize_after_opts
      super
      if @name
        @getter   ||= :"#{@name}"
        @setter   ||= :"#{@name}="
      end
      @clearer  ||= nil
      @appender ||= :"<<"
      @popper   ||= :"pop"
      raise ArgumentError, "no name" unless @name
    end


    def get(obj)
      case @getter
      when nil
        nil
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
      when nil
        nil
      when Symbol
        obj.send(@setter, value)
      when Proc
        @setter.call(obj, value)
      else
        raise TypeError
      end
    end 
    
    # Clears the collection on obj's @name slot.
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
    
    # Appends value to the collection on obj's @name slot.
    def append!(obj, value)
      # Get the container to append to first.
      case @appender
      when nil
        nil
      when Symbol
        obj = get(obj)
        obj.send(@appender, value)
      when Proc
        obj = get(obj)
        @appender.call(obj, value)
      else
        raise TypeError
      end
    end 
    
    # Removes last value on the collection at obj's @name slot.
    def pop!(obj, value)
      # Get the container to pop to first.
      case @popper
      when nil
        nil
      when Symbol
        obj = get(obj)
        obj.send(@popper, value)
      when Proc
        obj = get(obj)
        @popper.call(obj, value)
      else
        raise TypeError
      end
    end 
    
  end


  # Maps attributes in a class.
  # Attribute values are assumed to be value-oriented objects, meaning
  # their equality is not dependent on identity, value attribute's identity is not preserved.
  # Such as Time objects or other non-identity based objects.
  #
  # Objects that are stored based on their "identity", such as ActiveRecord::Base objects should
  # be listed as an AssociationMapping.
  class AttributeMapping < PropertyMapping
    # Gets the object's attribute value and saves it in the result Hash using the Mapping's name.
    # A new result is constructed from the mapping of the object's attribute value.
    def map(mapper, obj, result, cls, path)
      mapper.path = path = "#{path}.#{@name}"
      $stderr.puts "  ==> map #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_MAP
      return nil unless map?(mapper, obj, result, cls, path)
      result[name] = mapper._map(get(obj), nil, nil, path)
    end
    
    # Sets the object's value, with the unmapped value from the result Hash index by the Mapping's name.
    def unmap!(mapper, obj, result, cls, path)
      mapper.path = path = "#{path}.#{@name}"
      $stderr.puts "  <== unmap! #{self.class} #{@name.inspect} #{obj.class} #{result.inspect} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      return nil unless unmap?(mapper, obj, result, cls, path)
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
  

  # Maps associations in a class.
  class AssociationMapping < PropertyMapping
    def map(mapper, obj, result, cls, path)
      mapper.path = path = "#{path}.#{@name}"
      $stderr.puts "  ==> map #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_MAP
      return nil unless map?(mapper, obj, result, cls, path)
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
      return nil unless unmap?(mapper, obj, result, cls, path)
      
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

