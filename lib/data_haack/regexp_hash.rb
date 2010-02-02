
module DataHaack
  # Returns longest matching pattern, preferring String keys over Regexp keys.
  #
  #   rh = Hash.new { | h, k | :default }
  #   rh[/a/] = 1
  #   rh[/aa/] = 2
  #   rh[/aa+/] = 3
  #   rh['abcd'] = 4
  #   rh = RegexpHash.new($rh)
  #
  #   rh[""].should == :default
  #   rh["b"].should == :default
  #   rh["a"].should == 1
  #   rh["aa"].should == 2
  #   rh["aaa"].should == 3
  #   rh["abcd"].should == 4
  #   rh["kajsdfkaakasjdf"].should == 2
  #   rh["aabcd"].should == 2
  #
  class RegexpHash
    class Ambiguous < Exception; end
    
    NEVER = [ ].freeze
    EMPTY_ARRAY = [ ].freeze

    attr_accessor :ambiguous_error
    
    def initialize h = { }
      @h = h
      @ambiguous_error = false
    end
    
    def match val
      match = nil
      @h.each do | k, v |
        m = case k
        when Regexp
          k.match(val)
        else
          k === val ? [ k ] : nil
        end
        if m 
          raise @ambigous_error, val.to_s if @ambiguous_error && match && match.size >= 1
          (match ||= [ ]) << [ k, v, m ]
        end
      end
      match || EMPTY_ARRAY
    end

    def [] val
      match = self.match val
      # $stderr.puts "match = #{match.inspect}"
      return @h[NEVER] if match.empty?
      
      # Sort by match type, then largest match, then by longest regexp.
      match = match.sort do | a, b |
        (_match_metric(a)     <=> _match_metric(b)).nonzero? ||
        (b[2][0].size         <=> a[2][0].size).nonzero? ||
        (b.first.inspect.size <=> a.first.inspect.size ) 
      end.first
      
      match[1]
    end
    
    # Literal String matches better than Regexp.
    def _match_metric m
      case m[2]
      when MatchData
        1
      else
        0
      end
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
      result = self if result.equal?(@h)
      result
    end
  end
end

