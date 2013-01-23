=begin
* Name: pc_keys.rb
* Description: Physico-Chemical descriptors key file location
* Author: Andreas Maunz <andreas@maunz.de>
* Date: 10/2012
=end

$keysfile = File.join(File.dirname(__FILE__),"..","public", "pc_descriptors.yaml")
#$keysfile = File.join(ENV['HOME'], ".opentox", "config", "pc_descriptors.yaml")
