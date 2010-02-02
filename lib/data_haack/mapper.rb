require 'data_haack'

module DataHaack
  #
  # Maps arbitrary objects to basic data structures
  # Unmaps basic data structures to arbitrary objects,
  # based on the MappingSet specified.
  #
  # Each Mapping implements a mapping for a:
  # * Class
  # * path
  # * value
  # * attribute in an object.
  # * association on an object.
  #
  # TODO:
  # * Constrain heavy associations (see enumeration_limit below).
  #
  class Mapper
    include Options

    # Attributes:
    
    # The set of Mappings to transform to and from the base structure.
    attr_accessor :mapping_set

    # Traveral State:

    # Hash of objects to the paths that changed them.
    attr_accessor :object_changed
    # Hash of objects to the paths that created them.
    attr_accessor :object_created
    
    # Current path.
    attr_accessor :path
    
    # The root arguments at initial traversal.
    attr_reader :root_obj, :root_cls, :root_data
    
    
    def initialize_before_opts
      super
      @object_changed = { }
      @object_created = { }
      @path = nil
    end

  
    # Subclasses can override.
    def map? obj, data, cls, path
      true
    end

    # Subclasses can override.
    def unmap? obj, data, cls, path
      true
    end


    # Maps object to a basic data structure.
    def map(obj, data = nil, cls = nil, path = nil)
      cls ||= obj.class
      path ||= ''
      @root_obj = obj
      @root_cls = cls
      @root_data = nil
      $stderr.puts "==> map #{obj.class} #{data.class} #{cls} #{path}" if VERBOSE_MAP
      @root_data = _map(obj, data, cls, path)
    rescue Exception => err
      reraise_error err
    end

    # Unmaps basic data structure into a object.
    def unmap!(obj, data, cls = nil, path = nil)
      path ||= ''
      @root_obj = obj
      @root_cls = cls
      @root_data = data
      $stderr.puts "  <== unmap! #{self.class} #{@name.inspect} #{obj.class} #{data.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      _unmap!(obj, data, cls, path)
    rescue Exception => err
      reraise_error err
    end


    # Maps object to a basic data structure.
    def _map(obj, data, cls, path)
      cls ||= obj.class
      @path = path
      $stderr.puts "  ==> _map #{obj.class} #{data.class} #{cls} #{path.inspect}" if VERBOSE_MAP
      return data unless map? obj, data, cls, path
      if mapper = @mapping_set.path_to_mapping[path] || @mapping_set.class_to_mapping[cls]
        mapper.map(self, obj, data, cls, path)
      else
        case obj
        when NilClass, TrueClass, FalseClass, String, Numeric, Symbol
          obj
        when Array
          i = -1
          obj.map{|e| _map(e, nil, e.class, "#{path}[#{i += 1}]")}
        when Hash
          data = { }
          obj.each do | k, v | 
            data[map(k)] = _map(v, nil, v.class, "#{path}[#{k.inspect}]")
          end
          data
        else
          # $stderr.puts "map(#{obj.inspect}, ...)"
          obj.to_s
        end
      end
    end

    # Unmaps basic data structure into a object.
    def _unmap!(obj, data, cls, path)
      # Handle direct collections.
      if obj.nil? && Array === data && cls
        i = -1
        return data.map{|e| _unmap!(obj, e, cls, "#{path}[#{i += 1}]")}
      end

      cls ||= obj.class
      @path = path
      $stderr.puts "  <== _unmap! #{self.class} #{@name.inspect} #{obj.class} #{data.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      return obj unless unmap? obj, data, cls, path


      if mapper = @mapping_set.path_to_mapping[path] || @mapping_set.class_to_mapping[cls]
        # $stderr.puts "unmap! #{obj.class} #{data.class} #{path}"
        mapper.unmap!(self, obj, data, cls, path)
      else
        case data
        when NilClass, TrueClass, FalseClass, String, Numeric, Symbol
          data
        when Array
          i = -1
          data.map{|e| _unmap!(obj, e, cls, "#{path}[#{i += 1}]")}
        when Hash
          h = { }
          data.map do | k, v | 
            h[k] = _unmap!(obj, v, cls, "#{path}[#{k.inspect}]")
          end
          h
        else
          data
        end
      end
    end


    def reraise_error err
      raise err.class, "root_cls #{@root_cls}: path #{@path}: #{err.message}\n  #{err.backtrace * "\n  "}"
    end
  
  end # class
end # module


