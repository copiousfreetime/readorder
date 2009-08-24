#--
# Copyright (c) 2009 Jeremy Hinegardner
# All rights reserved.  See LICENSE and/or COPYING for details.
#++

#
# Take a look in the README and the Analyzer and Datum classes.  That is where
# all the real work is done.
#
module Readorder
  #
  # root Error class for Readorder
  # 
  class Error < StandardError; end 
end

require 'rubygems'
require 'logging'

# require amalgalite explicitly  before hitimes explicitly because of 
# using flat namespace on OSX
# http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/344658
require 'amalgalite'
require 'hitimes'

require 'readorder/version'
require 'readorder/paths'
require 'readorder/cli'
require 'readorder/filelist'
require 'readorder/datum'
require 'readorder/analyzer'
