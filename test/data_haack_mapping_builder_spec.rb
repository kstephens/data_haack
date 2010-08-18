require 'data_haack'

require 'pp'
require 'data_haack/test/base'

describe "DataHaack::Mapping::Builder" do
  $A = DataHaack::Test::A
  $B = DataHaack::Test::B

  def a
    a = $A.new
    a.name = :A
    a.b = [ ]
    a.time = Time.now
    b = $B.new
    b.x = 1
    b.y = 2
    a << b
    b = $B.new
    b.x = 3
    b.sub_b = $B.new
    b.sub_b.y = 4
    a << b
    
    a
  end

  def mapping_set
    ms = DataHaack::MappingSet.build do 
      cls $A do
        attributes :name, :x
        attribute  :y, :setter => nil
        association :b do
          cls $B
          creater do | *args |
            b = super
            b.index = 999
            b
          end
          methods do
            def after_map mapper, obj, result, cls, pathx
              obj.b.each_with_index { | b, i | b.index = i }
            end
            def map? mapper, obj, result, cls, path
              mapper[:security_checker].security_ok?(args)
            end
          end
        end
        attribute :c do
          methods do
            def map? *args
              5
            end
          end
        end
      end
      
      cls $B do
        attributes :x, :y
        association :sub_b
      end

      value Time do
        map :to_f
        unmap :at
      end

    end
    
    # pp [ :mapping_set=, ms ]
    
    ms
    
  end

  it 'should build a MappingSet' do
    ms = mapping_set

    ms.class_to_mapping.size.should == 3
    (a = ms.class_to_mapping[$A]).should be_an_instance_of DataHaack::ClassMapping
    (b = ms.class_to_mapping[$B]).should be_an_instance_of DataHaack::ClassMapping
    a.attributes.map{|x| x.name}.sort_by{|x| x.to_s}.should == [ :c, :name, :x, :y, ]
    a.attributes.named(:name).name.should == :name
    a.attributes.named(:asdkfjasldkf).should == nil
    a.attributes.named(:c).map?.should == 5

    b.attributes.map{|x| x.name}.sort_by{|x| x.to_s}.should == [ :x, :y ]
    
    (tm = ms.class_to_mapping[Time]).should be_an_instance_of DataHaack::ValueMapping
    tm.map(nil, Time.now, nil, nil, "").should be_an_instance_of Float
    tm.unmap!(nil, nil, Time.now.to_f, nil, "").should be_an_instance_of Time
  end

end # describe
