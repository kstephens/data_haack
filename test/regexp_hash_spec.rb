require 'data_haack'

require 'pp'
require 'data_haack/regexp_hash'

describe "DataHaack::RegexpHash" do
  it 'should match Strings' do
    rh = Hash.new { | h, k | :default }
    rh[/a/] = 1
    rh[/aa/] = 2
    rh[/aaa+/] = 3
    rh['abcd'] = 4
    rh = DataHaack::RegexpHash.new rh

    rh[""].should == :default
    rh["b"].should == :default
    rh["a"].should == 1
    rh["aa"].should == 2
    rh["aaa"].should == 3
    rh["abcd"].should == 4
    rh["kajsdfkaakasjdf"].should == 2
    rh["aabcd"].should == 2
  end
end 

