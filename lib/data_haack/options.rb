require 'data_haack'

module DataHaack
  # Support for #initialize using Hash and setter methods.
  #
  #   class Foo
  #     include DataHaack::Options
  #     attr_accessor :foo, :bar
  #
  #     def initialize_before_opts
  #     end
  #     def initialize_after_opts
  #     end
  #   end
  #   f = Foo.new(:bar => 1, :baz => 2, :x => 4)
  #   f[:x] => 4
  #   f.bar => 1
  #
  module Options
    # Calls initialize_before_opts, set_opts!, then initialize_after_opts.
    # Subclass is not required to override.
    def initialize opts = nil
      @opts = opts || { }
      initialize_before_opts
      set_opts! @opts
      initialize_after_opts
    end

    # Subclass can override, but should call super.
    def initialize_before_opts
    end

    # Subclass can override, but should call super.
    def initialize_after_opts
    end

    def set_opts! opts = nil
      opts ||= { }
      (@opts = opts).each do | k, v |
        send("#{k}=", v)
      end
      self
    end

    # Get an option.
    def [] key
      @opts[key]
    end

    # Set an option.
    def []= key, value
      @opts[key] = value
    end
  end
end
