require 'data_haack/mapping'

module DataHaack
  class Mapping
    # Builds a MappingSet using a simple block-oriented DSL.
    class Builder
      include Options

      # The generated MappingSet
      attr_accessor :_mapping_set
      
      # The object currently being built.
      attr_reader :_context, :_context_stack
      
      def initialize_before_opts
        super
        @_context = nil
        @_context_stack = [ ]
      end

      def build opts = { }, &blk
        @_context = @_mapping_set or raise ArgumentError
        instance_eval &blk
        @_mapping_set
      end

      def cls cls, opts = { }, &blk
        raise ArgumentError unless cls
        case
        when @_context.respond_to?(:create_class_mapping)
          opts[:cls] = cls
          obj = @_context.create_class_mapping opts
          _with_context obj, &blk
        when @_context.respond_to?(:cls=)
          @_context.cls = cls
        else
          raise ArgumentError
        end
      end

      def path path, opts = { }, &blk
        raise ArgumentError unless path
        case
        when @_context.respond_to?(:create_value_mapping)
          obj = @_context.create_value_mapping opts
          _with_context obj, &blk
          @_context.path_to_mapping[path] = obj
        when @_context.respond_to?(:value=)
          @_context.value = name
        else
          raise ArgumentError
        end
      end

      def value cls, opts = { }, &blk
        raise ArgumentError unless cls
        case 
        when @_context.respond_to?(:create_value_mapping)
          opts[:cls] = cls
          obj = @_context.create_value_mapping opts
          _with_context obj, &blk
        when @_context.respond_to?(:value=)
          @_context.value = cls
        else
          raise ArgumentError
        end
      end

      begin
        template = [ <<'END', __FILE__, __LINE__ ]
        def attribute name, opts = { }, &blk
          raise ArgumentError unless name
          raise ArgumentError unless Hash === opts
          opts[:name] = name
          obj = @_context.create_attribute_mapping(opts)
          _with_context obj, &blk
        end
        
        def attributes *names, &blk
          raise ArgumentError if names.empty?
          opts = Hash === names[-1] ? names.pop : { } 
          names.each do | x |
            raise ArgumentError unless x
            obj = @_context.create_attribute_mapping(opts.dup.update(:name => x))
            _with_context obj, &blk
          end
        end
END
        [ :attribute, :association ].each do | n |
          class_eval template[0].gsub('attribute', n.to_s), template[1], template[2];
        end
      end
      
      alias :attr :attribute
      alias :attrs :attributes
      alias :assoc :association
      alias :assocs :associations
      
      begin
        template = [ <<'END', __FILE__, __LINE__ ]
        def getter opts = { }, &blk
          raise ArgumentError unless @_context.respond_to?(:getter)
          opts = { :name => opts } unless Hash === opts
          opts[:proc] = blk if block_given?
          @_context.getter = opts[:name] || opts[:proc]
        end
END
        [ :mapper, :unmapper, :getter, :setter, :creater, :clearer, :appender, :deleter ].each do | n |
          class_eval template[0].gsub('getter', n.to_s), template[1], template[2]
        end
      end
      alias :map :mapper
      alias :unmap :unmapper
      alias :get :getter
      alias :set :setter
      alias :create :creater
      alias :clear :clearer
      alias :append :appender
      alias :delete :deleter

      # Define singleton methods within a mapping.
      #
      def methods &blk
        raise ArgumentError unless block_given?
        @_context.instance_eval &blk
      end

      def _with_context obj, &blk
        @_context_stack.push @_context
        @_context = obj
        # pp [ :_with_context_caller, caller ]
        # pp [ :_with_context, @_context ] # , @_context_stack ]
        instance_eval &blk if block_given?
        @_context
      ensure
        @_context = @_context_stack.pop
      end
    end # class
  end # class
end # module


=begin

ms = DataHaack::MappingSet.build do 
  cls :A do
    attributes :name, :x
    attribute :y, :setter => nil
    association :b do
      cls :B
      create! do | *args |
        b = super
        b.foobar = 
        b
      end
      map? do | *args |
        mapper[:security_checker].security_ok?(args)
      end
    end
    attribute :c do
      map? do | *args |
        Time.now.dayofweek == 5
      end
    end
  end

  cls :B do
    attribute :x, :y
    association :sub_b
  end

  path /.*\.loans?$/ do
    def map *args
      x = super
      x = Enumerable === x ? x.map{|obj| obj.id} : x.id
      x
    end
    def unmap! *args
      # NOTHING
    end
  end
end


mapper = Mapper.new(:mapping_set => mapping_set, :security_checker => someobject)


#####################################
# Controller example
#

class DataController < ActionController::Base

  def work_item
    case http_action
    when :get
      get(WorkItem, params[:id]).to_json
    when :post
      post(WorkItem, params[:id]).to_json
    else
      raise Error
    end
  end

private

  def get cls, id
    @entity = cls.find(id)
    mapping = get_mapping cls
    data = mapping.mapper.map(@entity)
    data
  rescue Exception => err
    mapping.mapper.map(err)
  end
  def post
    @entity = cls.find(id)
    mapping = get_mapping cls
    :OK
  rescue Exception => err
    mapping.mapper.map([:ERROR, err])
  end
  
  # Returns the MappingSet for the root cls.
  def get_mapping cls_name
    @@mappings[cls_name] ||=
      send("mapping_#{cls_name}")
  end

  def mapping_WorkItem
    DataHaack::MappingSet.build do 
      cls WorkItem do
        attributes *args
        associations *args
      end
      cls Customer do
      end
      cls Loan do
      end
    end
  end

end

=end

