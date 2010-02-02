require 'data_haack'
require 'pp'

ms = DataHaack::MappingSet.build do 
  value Time do
    map :to_f # calls Time#to_f
    unmap do | val |
      val && Time.at(val)
    end
  end
end

now = Time.now

obj = [ now, now, nil, now ]
data = ms.mapper.map(obj)
pp [ now, :'=>', data ]

unmapped = ms.mapper.unmap!(nil, data, Time)
pp [ data, :'=>', unmapped ]

