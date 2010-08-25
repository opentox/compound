# Java environment
ENV["JAVA_HOME"] = "/usr/lib/jvm/java-6-sun" unless ENV["JAVA_HOME"]
java_dir = File.join File.expand_path(File.dirname(__FILE__)),"java"
cdk = File.join java_dir, "cdk-1.3.5.jar"
jchempaint = File.join java_dir, "cdk-jchempaint-15.jar"
ENV["CLASSPATH"] = "#{ENV["CLASSPATH"]}:#{java_dir}:#{cdk}:#{jchempaint}"

require 'rubygems'
require 'rjb'
gem "opentox-ruby-api-wrapper", "= 1.6.6"
require 'opentox-ruby-api-wrapper'

#set :lock, true # avoid JVM memory allocation problems
# -Xmx64m

get "/display/activating/(.+)$" do
  content_type "image/png"
  attachment "#{params["smiles"]}.png"
  Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
  s = Rjb::import('Structure').new(params["smiles"],150)
  s.match_activating(params["smarts"])
  s.show
end

post "/display/deactivating" do
  content_type "image/png"
  attachment "#{params["smiles"]}.png"
  Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
  s = Rjb::import('Structure').new(params["smiles"],150)
  s.match_deactivating(params["smarts"])
  s.show
end

get %r{/smiles/(.+)/smarts/activating/(.*)/deactivating/(.*)/highlight/(.*)$} do |smiles,activating,deactivating,smarts| 
  activating = activating.to_s.split(/\//).collect{|s| s.gsub(/"/,'')}
  deactivating = deactivating.to_s.split(/\//).collect{|s| s.gsub(/"/,'')}
  content_type "image/png"
  attachment "#{smiles}.png"
  Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
  s = Rjb::import('Structure').new(smiles,150)
  s.match_deactivating(deactivating) unless deactivating.empty?
  s.match_activating(activating) unless activating.empty?
  s.match(smarts)
  s.show
  #s = nil
end

get %r{/smiles/(.+)/smarts/activating/(.*)/deactivating/(.*)$} do |smiles,activating,deactivating| 
  activating = activating.to_s.split(/\//).collect{|s| s.gsub(/"/,'')}
  deactivating = deactivating.to_s.split(/\//).collect{|s| s.gsub(/"/,'')}
  content_type "image/png"
  attachment "#{smiles}.png"
  Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
  s = Rjb::import('Structure').new(smiles,150)
  s.match_deactivating(deactivating)
  s.match_activating(activating)
  s.show
  #s = nil
end

get %r{/smiles/(.+)/smarts/(.*)/(.*activating)$} do |smiles,allsmarts,effect| 
  LOGGER.debug "String:"
  LOGGER.debug allsmarts
  smarts = allsmarts.to_s.split(/\//)
  smarts.collect!{|s| s.gsub(/"/,'')}
  LOGGER.debug "Smarts:"
  LOGGER.debug smarts.to_yaml
  content_type "image/png"
  attachment "#{smiles}.png"
  Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
  s = Rjb::import('Structure').new(smiles,150)
  if effect == "activating"
    s.match_activating(smarts)
  elsif effect == "deactivating"
    s.match_deactivating(smarts)
  end
  s.show
end

get %r{/smiles/(.+)/smarts/(.*)$} do |smiles,smarts| 
  content_type "image/png"
  attachment "#{smiles}.png"
  Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
  s = Rjb::import('Structure').new(smiles,150)
  s.match(smarts)
  s.show
end

get %r{/smiles/(.+)} do |smiles| 
  content_type "image/png"
  attachment "#{smiles}.png"
  Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
  Rjb::import('Structure').new(smiles,150).show
end

get %r{/(.+)/image} do |inchi| # catches all remaining get requests
   smiles = OpenTox::Compound.new(:inchi => inchi).smiles
   content_type "image/png"
   attachment "#{smiles}.png"
   Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
   Rjb::import('Structure').new(smiles,150).show
end

get %r{/(.+)} do |inchi| # catches all remaining get requests
  inchi = URI.unescape request.env['REQUEST_URI'].sub(/^\//,'').sub(/.*compound\//,'') # hack to avoid sinatra's URI/CGI unescaping, splitting, ..."
  case request.env['HTTP_ACCEPT']
  when "*/*"
    response['Content-Type'] = "chemical/x-daylight-smiles"
    OpenTox::Compound.new(:inchi => inchi).smiles
  when "chemical/x-daylight-smiles"
    response['Content-Type'] = "chemical/x-daylight-smiles"
    OpenTox::Compound.new(:inchi => inchi).smiles
  when "chemical/x-inchi"
    response['Content-Type'] = "chemical/x-inchi"
    inchi 
  when "chemical/x-mdl-sdfile"
    response['Content-Type'] = "chemical/x-mdl-sdfile"
    OpenTox::Compound.new(:inchi => inchi).sdf
  when "image/gif"
    response['Content-Type'] = "image/gif"
    OpenTox::Compound.new(:inchi => inchi).gif
  when "image/png"
    response['Content-Type'] = "image/png"
    OpenTox::Compound.new(:inchi => inchi).png
  when "text/plain"
    response['Content-Type'] = "text/plain"
    uri = File.join @@cactus_uri,inchi,"names"
    RestClient.get(uri).body
  else
    halt 400, "Unsupported MIME type '#{request.env['HTTP_ACCEPT']}'"
  end
end

post '/?' do 

  input = request.env["rack.input"].read
  response['Content-Type'] = 'text/uri-list'
  begin
    case request.content_type
    when /chemical\/x-daylight-smiles/
      OpenTox::Compound.new(:smiles => input).uri + "\n"
    when /chemical\/x-inchi/
      OpenTox::Compound.new(:inchi => input).uri + "\n"
    when /chemical\/x-mdl-sdfile|chemical\/x-mdl-molfile/
      OpenTox::Compound.new(:sdf => input).uri + "\n"
    when /text\/plain/
      OpenTox::Compound.new(:name => input).uri + "\n"
    else
      status 400
      "Unsupported MIME type '#{request.content_type}'"
    end
  rescue
    status 400
    "Cannot process request '#{input}' for content type '#{request.content_type}'"
  end
end
