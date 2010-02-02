require 'data_haack'

require 'pp'
require 'data_haack/test/base'

describe "DataHaack::Mapper" do
  A = DataHaack::Test::A
  B = DataHaack::Test::B

  it 'should map simple values.' do
    ms = DataHaack::MappingSet.build do
      value Time do
        map :to_f
        unmap :at
      end
    end
    now = Time.now
    data = ms.mapper.map(now)
    data.should be_an_instance_of Float
    data.should == now.to_f

    obj = ms.mapper.unmap!(nil, data, Time)
    obj.should be_an_instance_of Time
    obj.to_f.should == now.to_f
  end

  it 'should map Array values.' do
    ms = DataHaack::MappingSet.build do
      value Time do
        map :to_f
        unmap do | val |
          val && Time.at(val)
        end
      end
    end
    now = Time.now
    data = ms.mapper.map( [ now, now, nil, now ])
    data.should be_an_instance_of Array
    data.should == [ now.to_f, now.to_f, nil, now.to_f ]

    obj = ms.mapper.unmap!(nil, data, Time)
    obj.should be_an_instance_of Array
    obj.each { | x | x && (x.should be_an_instance_of(Time)) }
    obj.should == [ now, now, nil, now ]
  end


  def a
    a = A.new
    a.name = :A
    a.b = [ ]
    a.time = Time.now
    b = B.new
    b.x = 1
    b.y = 2
    a << b
    b = B.new
    b.x = 3
    b.sub_b = B.new
    b.sub_b.y = 4
    a << b

    # pp [ 'Data structure to map', a ]

    a
  end

  def mapping_set
    mapping_set = DataHaack::MappingSet.build do
      cls A do
        attributes :name, :time
        association :b do
          cls B
        end
      end
      cls B do
        attributes :x, :y
        association :sub_b do
          cls B
        end
      end
    end
    
    # pp mapping_set

    mapping_set
  end

  def mapping_set_Time_to_f
    mapping_set = self.mapping_set

    # Map Time using to_f.
    mapping_set.build do
      value Time do
        map :to_f # Time#to_f
        unmap :at # Time.at
      end
    end

    # pp mapping_set
    mapping_set
  end
  
  def dhm mapping_set = nil
    mapping_set ||= self.mapping_set
    # Map Time using to_s (default behavior)
    dhm = DataHaack::Mapper.new(:mapping_set => mapping_set)
    dhm
  end


  def do_basic_map
    a = self.a
    mapping_set = self.mapping_set_Time_to_f

    dhm = self.dhm mapping_set
    d = dhm.map(a)

    [ mapping_set, a, d ]
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
    mapping_set, a, d = do_basic_map

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
    mapping_set = self.mapping_set_Time_to_f

    mapping_set.build do
      path '.b[1].x' do
        # cls Integer
        map do | val |
          val.to_s
        end
        unmap do | val |
          val.to_i
        end
      end
    end

    dhm = DataHaack::Mapper.new(:mapping_set => mapping_set)

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
    mapping_set, a, d = do_basic_map

    d[:name] = :AChanged
    d[:b][1][:sub_b][:x] = 5

    # pp [ 'Before unmap!', a ]

    dhm = self.dhm mapping_set
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
    mapping_set, a, d = do_basic_map

    a.b = nil
    a.time = nil
    # pp [ 'Data structure after a.b = nil and a.time = nil', a ]

    dhm = self.dhm mapping_set
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


