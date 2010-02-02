
#
# Maps arbitrary Ruby objects to basic structures
# Unmaps basic structures to arbitrary objects,
# based on Mapping specifed at particular.
#
# Each Mapping implements a mapping for a:
# * Class
# * path
# * value
# * attribute in an object.
# * association on an object.
#
# Name inspired by "famous" German cartographer Hermann Haack (1872 - 1966).
#
module DataHaack
  EMPTY_STRING = ''.freeze
  EMPTY_ARRAY = [ ].freeze
  EMPTY_HASH = { }.freeze

  # Debugging support.
  VERBOSE_MAP = false
  VERBOSE_UNMAP = false
  
  # UNIQUE OBJECTS
  IGNORED = Object.new
  def IGNORED.inspect; '#<IGNORED>'; end
  IGNORED.freeze
  
  FILTERED = Object.new
  def FILTERED.inspect; '#<FILTERED>'; end
  FILTERED.freeze
  
  # Generate DataHaack error.
  class Error < Exception
    # Method called that should have been implemented by a subclass or a singleton method.
    class SubclassResponsibility < self; end
  end
end

require 'data_haack/options'
require 'data_haack/mapper'
require 'data_haack/mapping'
require 'data_haack/mapping_set'
require 'data_haack/class_mapping'
require 'data_haack/mapping/builder'

