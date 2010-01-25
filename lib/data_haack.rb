
#
# Maps arbitrary objects to basic structures
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
#
module DataHaack
  EMPTY_STRING = ''.freeze
  EMPTY_ARRAY = [ ].freeze
  EMPTY_HASH = { }.freeze

  # Debugging support.
  VERBOSE_MAP = false
  VERBOSE_UNMAP = false
end

require 'data_haack/mapper'
require 'data_haack/mapping'

