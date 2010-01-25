require 'data_haack'

module DataHaack
  #
  # Maps arbitrary objects to basic structures
  # Unmaps basic structures to arbitrary objects,
  # based on the Mappings specified.
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
    
    # Hash of path String objects to Mapping objects.
    attr_accessor :path_to_mapping
    
    # Hash of Class objects to Mapping objects.
    attr_accessor :class_to_mapping
    
    # Hash of objects to the paths that changed them.
    attr_accessor :object_changed
    # Hash of objects to the paths that created them.
    attr_accessor :object_created
    
    # Current path.
    attr_accessor :path
    
    # The root settings at initial traversal.
    attr_reader :root_obj, :root_cls, :root_result
    
    
    def initialize opts = nil
      @object_changed = { }
      @object_created = { }
      @path = nil
      if opts
        opts.each do | k, v |
          send(:"#{k}=", v)
        end
      end
      @path_to_mapping  ||= EMPTY_HASH
      @class_to_mapping ||= EMPTY_HASH
    end

    # Subclasses can override.
    def map? obj, result, cls, path
      true
    end

    # Subclasses can override.
    def unmap? obj, result, cls, path
      true
    end


    # Maps object to a primitive data structure.
    def map(obj, result = nil, cls = nil, path = nil)
      cls ||= obj.class
      path ||= ''
      @root_obj = obj
      @root_cls = cls
      @root_result = nil
      $stderr.puts "==> map #{obj.class} #{result.class} #{cls} #{path}" if VERBOSE_MAP
      @root_result = _map(obj, result, cls, path)
    rescue Exception => err
      reraise_error err
    end

    # Unmaps primitive data structure into a object.
    def unmap!(obj, result, cls = nil, path = nil)
      path ||= ''
      @root_obj = obj
      @root_cls = cls
      @root_result = result
      $stderr.puts "  <== unmap! #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      _unmap!(obj, result, cls, path)
    rescue Exception => err
      reraise_error err
    end


    # Maps object to a primitive data structure.
    def _map(obj, result, cls, path)
      cls ||= obj.class
      @path = path
      $stderr.puts "  ==> _map #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_MAP
      return result unless map? obj, result, cls, path
      if mapper = @path_to_mapping[path] || @class_to_mapping[cls]
        mapper.map(self, obj, result, cls, path)
      else
        case obj
        when NilClass, TrueClass, FalseClass, String, Numeric, Symbol
          obj
        when Array
          i = -1
          obj.map{|e| _map(e, nil, cls, "#{path}[#{i += 1}]")}
        when Hash
          result = { }
          obj.each do | k, v | 
            result[map(k)] = _map(v, nil, cls, "#{path}[#{k.inspect}]")
          end
          result
        else
          # $stderr.puts "map(#{obj.inspect}, ...)"
          obj.to_s
        end
      end
    end

    # Unmaps primitive data structure into a object.
    def _unmap!(obj, result, cls, path)
      cls ||= obj.class
      @path = path
      $stderr.puts "  <== _unmap! #{self.class} #{@name.inspect} #{obj.class} #{result.class} #{cls} #{path.inspect}" if VERBOSE_UNMAP
      return obj unless unmap? obj, result, cls, path
      if mapper = @path_to_mapping[path] || @class_to_mapping[cls]
        # $stderr.puts "unmap! #{obj.class} #{result.class} #{path}"
        mapper.unmap!(self, obj, result, cls, path)
      else
        case result
        when NilClass, TrueClass, FalseClass, String, Numeric, Symbol
          result
        when Array
          i = -1
          result.each{|e| _unmap!(obj, e, cls, "#{path}[#{i += 1}]")}
        when Hash
          result.each do | k, v | 
            _unmap!(obj, v, cls, "#{path}[#{k.inspect}]")
          end
        else
          result
        end
      end
    end


    def reraise_error err
      raise err.class, "root_cls #{@root_cls}: path #{@path}: #{err.message}\n  #{err.backtrace * "\n  "}"
    end
  
  end # class
end # module


