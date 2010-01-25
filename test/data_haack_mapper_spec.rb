require 'data_haack'

require 'pp'

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
    end

    class B < Base
      # Attributes:
      attr_accessor :x, :y

      # Associations:
      attr_accessor :sub_b
    end
  end
end


describe "DataHaack::Mapper" do
  A = DataHaack::Test::A
  B = DataHaack::Test::B

  def a
    a = A.new
    a.name = :A
    a.b = [ ]
    a.time = Time.now
    b = B.new
    b.x = 1
    b.y = 2
    a.b << b
    b = B.new
    b.x = 3
    b.sub_b = B.new
    b.sub_b.y = 4
    a.b << b

    # pp [ 'Data structure to map', a ]

    a
  end

  def cls_maps
    cls_maps = { 
      A => {
        :attributes => [ :name, :time ],
        :associations => [ [ B, :b ] ],
      },
      B => {
        :attributes => [ :x, :y ],
        :associations => [ [ B, :sub_b ] ],
      },
    }
    cls_maps = DataHaack::Mapping.create_class_to_mapping(cls_maps)
    # pp cls_maps
    cls_maps
  end

  def cls_maps_Time_to_f
    cls_maps = self.cls_maps

    # Map Time using to_f.
    cls_maps[Time] = 
      DataHaack::ValueMapping.new(:cls => Time, 
                                  :getter => lambda { | val |      val.to_f }, 
                                  :setter => lambda { | obj, val | Time.at(val) }
                                  )
    # pp cls_maps
    cls_maps
  end
  
  def dhm cls_maps = nil
    cls_maps ||= self.cls_maps
    # Map Time using to_s (default behavior)
    dhm = DataHaack::Mapper.new(:class_to_mapping => cls_maps)
    dhm
  end


  def do_basic_map
    a = self.a
    cls_maps = self.cls_maps_Time_to_f

    dhm = self.dhm cls_maps
    d = dhm.map(a)

    [ cls_maps, a, d ]
  end


  it 'should map Time using #to_s default behavior.' do 
    a = self.a

    # Map Time using to_s (default behavior)
    dhm = self.dhm
    d = dhm.map(a)
    
    # pp [ 'Map Time using to_s (default behavior)', d ]

    d[:_class].should              == a.class.name
    d[:_id].should                 == a.id
    d[:name].should                == :A
    d[:time].should                == a.time.to_s
    d[:b][1][:sub_b][:x].should    == nil

    # Kernel.exit! 0
  end

  it 'should map Time using #to_f.' do
    cls_maps, a, d = do_basic_map

    # pp [ 'Map A#time using to_f', d ]

    expected = 
      {:_class=>"DataHaack::Test::A",
      :_id=>a.id,  # 70123522370260,
      :b=>
      [{:_class=>"DataHaack::Test::B",
         :sub_b=>nil,
      :_id=>a.b[0].id, # 70123522370180,
         :x=>1,
         :y=>2},
       {:_class=>"DataHaack::Test::B",
         :sub_b=>
         {:_class=>"DataHaack::Test::B",
           :sub_b=>nil,
           :_id=> a.b[1].sub_b.id, # 70123522370100,
           :x=>nil,
           :y=>4},
         :_id=> a.b[1].id, # 70123522370120,
         :x=> 3,
         :y=>nil}],
      :name=>:A,
      :time=> a.time.to_f, # 1264451673.70999
    }
    d.should == expected
  end

  it 'should map paths using Time#to_i' do
    a = self.a
    cls_maps = self.cls_maps_Time_to_f

    path_maps = { }
    path_maps['.b[1].x'] = 
      DataHaack::ValueMapping.new(:cls => Integer, 
                                  :getter => lambda { | val |      val.to_s }, 
                                  :setter => lambda { | obj, val | val.to_i }
                                  )
    
    dhm = DataHaack::Mapper.new(:class_to_mapping => cls_maps,
                                :path_to_mapping => path_maps)

    d = dhm.map(a)
    # pp [ 'Map .b[1].x using to_s', d ]

    expected = 
      {:_class=>"DataHaack::Test::A",
      :_id=>a.id,  # 70123522370260,
      :b=>
      [{:_class=>"DataHaack::Test::B",
         :sub_b=>nil,
      :_id=>a.b[0].id, # 70123522370180,
         :x=>1,
         :y=>2},
       {:_class=>"DataHaack::Test::B",
         :sub_b=>
         {:_class=>"DataHaack::Test::B",
           :sub_b=>nil,
           :_id=> a.b[1].sub_b.id, # 70123522370100,
           :x=>nil,
           :y=>4},
         :_id=> a.b[1].id, # 70123522370120,
         :x=> a.b[1].x.to_s, # "3",
         :y=>nil}],
      :name=>:A,
      :time=> a.time.to_f, # 1264451673.70999
    }
    d.should == expected
  end

  it 'should unmap! isometric data' do
    cls_maps, a, d = do_basic_map

    d[:name] = :AChanged
    d[:b][1][:sub_b][:x] = 5

    dhm = self.dhm cls_maps
    dhm.unmap!(a, d)

    # pp [ 'Data structure after unmap!', a ]
    # pp [ 'Objects changed:', dhm.object_changed.map{|k, v| "#{k.class}:#{'0x%x' % (k.object_id << 1)} => #{v.inspect}"} ]
    # pp [ 'Objects created:', dhm.object_created.map{|k, v| "#{k.class}:#{'0x%x' % (k.object_id << 1)} => #{v.inspect}"} ]

    dhm.object_changed.keys.size == -1
    dhm.object_created.keys.size == -1

    a.id.should               == d[:_id]
    a.name.should             == :AChanged
    a.b.size.should           == 2
    a.b[0].sub_b.should       == nil
    a.b[1].sub_b.x.should     == 5
    a.b[1].sub_b.x.should_not == nil
  end

  it 'should unmap! new objects through empty associations and attributes' do
    cls_maps, a, d = do_basic_map

    a.b = nil
    a.time = nil
    # pp [ 'Data structure after a.b = nil and a.time = nil', a ]

    dhm = self.dhm cls_maps
    dhm.unmap!(a, d)

    # pp [ 'Data structure after unmap!', a ]
    # pp [ 'Objects changed:', dhm.object_changed.map{|k, v| "#{k.class}:#{'0x%x' % (k.object_id << 1)} => #{v.inspect}"} ]
    # pp [ 'Objects created:', dhm.object_created.map{|k, v| "#{k.class}:#{'0x%x' % (k.object_id << 1)} => #{v.inspect}"} ]

    dhm.object_changed.keys.size == -1
    dhm.object_created.keys.size == -1

    a.id.should               == d[:_id]
    a.name.should             == :A
    a.b.size.should           == 2
    a.b[0].sub_b.should       == nil
    a.b[1].sub_b.should_not   == nil
    a.b[1].sub_b.x.should     == nil
    a.b[1].sub_b.y.should     == 4
  end
end


