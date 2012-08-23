# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "opentox-compound"
  s.version     = File.read("./VERSION")
  s.authors     = ["Christoph Helma"]
  s.email       = ["helma@in-silico.ch"]
  s.homepage    = "http://github.com/OpenTox/compound"
  s.summary     = %q{Toxbank compound service}
  s.description = %q{Toxbank compound service}
  s.license     = 'GPL-3'

  s.rubyforge_project = "task"

  s.files         = `git ls-files`.split("\n")
  s.required_ruby_version = '>= 1.9.2'

  # specify any dependencies here; for example:
  s.add_runtime_dependency "opentox-server", "#{s.version}"
  s.add_runtime_dependency "rjb"
  s.add_runtime_dependency "openbabel"
  s.post_install_message = "Please configure your service in ~/.opentox/config/compound.rb"
end

