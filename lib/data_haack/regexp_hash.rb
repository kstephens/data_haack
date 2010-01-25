
module DataHaack
  # Returns longest matching pattern and the key => value.
  #
  # rh = Hash.new { | k | :default }
  # rh[/a/] => 1
  # rh[/aa/] => 2
  # rh[/aa+/] => 3
  # rh = RegexpHash.new($rh)
  # rh[""]  => :default
  # rh["b"] => :default
  # rh["a"] => [ /a/, #<MatchData "a">, 1 ]
  #
  class RegexpHash
    class Ambiguous < Exception; end
    
    NEVER = [ ].freeze
    
    attr_accessor :ambiguous_error
    
    def initialize h = { }
      @h = h
      @ambiguous_error = false
    end
    
    def [] val
      match = [ ]
      @h.keys.each do | k |
        if m = k.match(val)
          raise @ambigous_error, val.to_s if @ambiguous_error && match.size == 1
          match << [ k, m ]
        end
      end
      
      return @h[NEVER] if match.empty?
      
      # Sort by largest match, then by longest regexp.
      match = match.sort_by { | e | (- e[1][0].size).nonzero? || - e.first.inspect.size }.first
      
      match << @h[match.first]
    end
    
    def []= key, val
      @h[key] = val
    end
    
    def freeze
      unless @h.frozen?
        @frozen = true
        @h.freeze
      end
      self
    end
    
    def frozen?
      @frozen || @h.frozen?
    end
    
    def method_missing sel, *args, &blk
      result = @h.send(sel, *args, &blk)
      result == self if result.eq?(@h.object_id)
      result
    end
  end
end




