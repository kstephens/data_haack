require 'data_haack'
require 'pp'

ms = DataHaack::MappingSet.build do 
  value Time do
    map :to_f # calls Time#to_f
    unmap :at # calls Time.at
  end
end

now = Time.now

data = ms.mapper.map(now)
pp [ now, :'=>', data ]

obj = ms.mapper.unmap!(nil, data, Time)
pp [ data, :'=>', obj ]

