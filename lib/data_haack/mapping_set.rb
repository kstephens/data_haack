require 'data_haack'

require 'data_haack/regexp_hash'
require 'data_haack/mapping/builder'


module DataHaack
  #
  # A set of Mappings indexed by Class or path.
  class MappingSet
    include Options

    # Hash of Class objects to Mapping objects.
    attr_accessor :class_to_mapping

    # Hash of path String objects to Mapping objects.
    attr_accessor :path_to_mapping
        
    def initialize_after_opts
      super
      @path_to_mapping ||= { }
      @path_to_mapping = RegexpHash.new(@path_to_mapping)
      @class_to_mapping ||= { }
    end

    # Subclasses may override.
    #
    #   super(opts) { Something.new(opts) }
    #
    def create_class_mapping opts
      if obj = @class_to_mapping[opts[:cls]]
        obj.set_opts! opts
      else
        obj = block_given? ? yield : ClassMapping.new(opts)
        raise ArgumentError unless obj.cls
        @class_to_mapping[obj.cls] = obj
      end
      obj
    end

    # Subclasses may override.
    #
    #   obj = Something.new opts
    #   super(opts) { Something.new(opts) }
    #
    def create_value_mapping opts, obj = nil
      if obj = @class_to_mapping[opts[:cls]]
        obj.set_opts! opts
      else
        obj = block_given? ? yield : ValueMapping.new(opts)
        @class_to_mapping[obj.cls] = obj # if obj.cls
        # pp [ :create_value_mapping=, obj ]
      end
      obj
    end


    # Returns a new Builder for this MappingSet.
    def builder opts = { }
      opts[:_mapping_set] = self
      Mapping::Builder.new(opts)
    end

    # Augments this MappingSet using a Builder.
    def build opts = nil, &blk
      builder.build opts, &blk
    end

    # Shorthand for:
    #
    #   MappingSet.new(...).build { ... }
    def self.build opts = nil, &blk
      self.new(opts).build(&blk)
    end

    # Shorthand for:
    #
    #   Mapper.new(:mapping_set => self).new
    def mapper(opts = { })
      opts[:mapping_set] = self
      Mapper.new(opts)
    end
  end
end


