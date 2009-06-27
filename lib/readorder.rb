#--
# Copyright (c) 2009 Jeremy Hinegardner
# All rights reserved.  See LICENSE and/or COPYING for details.
#++

module Readorder
  class Error < StandardError; end
end

require 'rubygems'
require 'logging'
require 'readorder/version'
require 'readorder/paths'
require 'readorder/cli'
require 'readorder/filelist'
require 'readorder/datum'
require 'readorder/analyzer'
