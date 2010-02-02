module DataHaack
  module Test
    class Base
      # Avoid warnings.
      alias :id :object_id

      # See #creater.
      def self.create *args
        new
      end
    end

    class A < Base
      # Attributes:
      attr_accessor :name, :time

      # Associations:
      attr_accessor :b

      def << b
        b.index = @b.size
        @b << b
        self
      end

    end

    class B < Base
      # Attributes:
      attr_accessor :x, :y, :index

      # Associations:
      attr_accessor :sub_b
    end
  end
end

