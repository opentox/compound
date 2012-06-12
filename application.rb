# Java environment
ENV["JAVA_HOME"] = "/usr/lib/jvm/java-6-sun" unless ENV["JAVA_HOME"]
java_dir = File.join File.expand_path(File.dirname(__FILE__)),"java"
cdk = File.join java_dir, "cdk-1.3.5.jar"
jchempaint = File.join java_dir, "cdk-jchempaint-15.jar"
ENV["CLASSPATH"] = "#{ENV["CLASSPATH"]}:#{java_dir}:#{cdk}:#{jchempaint}"

require 'rubygems'
require 'rjb'
gem "opentox-ruby", "~> 3"
require 'opentox-ruby'

before do
  @inchi = URI.unescape request.env['REQUEST_URI'].sub(/^\//,'').sub(/.*compound\//,'').sub(/\/smarts.*$/,'').sub(/\/image/,'').sub(/\?.*$/,'') # hack to avoid sinatra's URI/CGI unescaping, splitting, ..."
  #puts @inchi
end

# Display activating (red) and deactivating (green) substructures. Overlaps betwen activating and deactivating structures are marked in yellow.
# @example
#   curl http://webservices.in-silico.ch/compound/compound/InChI=1S/C6H5NO2/c8-7(9)6-4-2-1-3-5-6/h1-5H/smarts/activating/cN/ccN/deactivating/cc" > img.png
# @return [image/png] Image with highlighted substructures
get %r{/(.+)/smarts/activating/(.*)/deactivating/(.*)$} do |inchi,activating,deactivating| 
  smiles = OpenTox::Compound.from_inchi(@inchi).to_smiles
  activating = activating.to_s.split(/\//).collect{|s| s.gsub(/"/,'')}
  deactivating = deactivating.to_s.split(/\//).collect{|s| s.gsub(/"/,'')}
  content_type "image/png"
  attachment "#{smiles}.png"
  begin
    Rjb.load(nil,["-Xmx64m"])# avoid JVM memory allocation problems
    s = Rjb::import('Structure').new(smiles,150)
    s.match_deactivating(deactivating)
    s.match_activating(activating)
    s.show
  rescue => e
    LOGGER.warn e.message
  end
end

def png_from_smiles(smiles)
  begin
    Rjb.load(nil,["-Xmx64m","-Djava.awt.headless=true"])# avoid JVM memory allocation problems
    Rjb::import('Structure').new(smiles,150).show
  rescue
    LOGGER.warn e.message
  end
end

# Get png image
# @return [image/png] Image data
get %r{/(.+)/image} do |inchi| # catches all remaining get requests
  smiles = OpenTox::Compound.from_inchi(@inchi).to_smiles
  content_type "image/png"
  attachment "#{smiles}.png"
  png_from_smiles(smiles)
end

# Get compound representation
# @param [optinal, HEADER] Accept one of `chemical/x-daylight-smiles, chemical/x-inchi, chemical/x-mdl-sdfile, chemical/x-mdl-molfile, text/plain, image/gif, image/png`, defaults to chemical/x-daylight-smiles
# @example Get smiles
#   curl http://webservices.in-silico.ch/compound/InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H
# @example Get all known names 
#   curl -H "Accept:text/plain" http://webservices.in-silico.ch/compound/InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H
# @return [chemical/x-daylight-smiles, chemical/x-inchi, chemical/x-mdl-sdfile, chemical/x-mdl-molfile, text/plain, image/gif, image/png] Compound representation
get %r{/(.+)} do |inchi| # catches all remaining get requests
  #inchi = URI.unescape request.env['REQUEST_URI'].sub(/^\//,'').sub(/.*compound\//,'') # hack to avoid sinatra's URI/CGI unescaping, splitting, ..."
  case request.env['HTTP_ACCEPT']
  when "*/*"
    response['Content-Type'] = "chemical/x-daylight-smiles"
    OpenTox::Compound.from_inchi(@inchi).to_smiles
  when "chemical/x-daylight-smiles"
    response['Content-Type'] = "chemical/x-daylight-smiles"
    OpenTox::Compound.from_inchi(@inchi).to_smiles
  when "chemical/x-inchi"
    response['Content-Type'] = "chemical/x-inchi"
    @inchi 
  when "chemical/x-mdl-sdfile"
    response['Content-Type'] = "chemical/x-mdl-sdfile"
    OpenTox::Compound.from_inchi(@inchi).to_sdf
  when "image/gif"
    response['Content-Type'] = "image/gif"
    OpenTox::Compound.from_inchi(@inchi).to_gif
  when "image/png"
    response['Content-Type'] = "image/png"
    png_from_smiles(OpenTox::Compound.from_inchi(@inchi).to_smiles)
  when "text/plain"
    response['Content-Type'] = "text/plain"
    uri = File.join @@cactus_uri,@inchi,"names"
    RestClient.get(uri).body
  else
    raise OpenTox::BadRequestError.new "Unsupported MIME type '#{request.env['HTTP_ACCEPT']}'"
  end
end

# Create a new compound URI (compounds are not saved at the compound service)
# @param [HEADER] Content-type one of `chemical/x-daylight-smiles, chemical/x-inchi, chemical/x-mdl-sdfile, chemical/x-mdl-molfile, text/plain`
# @example Create compound from Smiles string
#   curl -X POST -H "Content-type:chemical/x-daylight-smiles" --data "c1ccccc1" http://webservices.in-silico.ch/compound
# @example Create compound from name, uses an external lookup service and should work also with trade names, CAS numbers, ...
#   curl -X POST -H "Content-type:text/plain" --data "Benzene" http://webservices.in-silico.ch/compound
# @param [BODY] - string with identifier/data in selected Content-type
# @return [text/uri-list] compound URI
post '/?' do 

  input = request.env["rack.input"].read
  response['Content-Type'] = 'text/uri-list'
  begin
    case request.content_type
    when /chemical\/x-daylight-smiles/
      OpenTox::Compound.from_smiles(input).uri + "\n"
    when /chemical\/x-inchi/
      OpenTox::Compound.from_inchi(input).uri + "\n"
    when /chemical\/x-mdl-sdfile|chemical\/x-mdl-molfile/
      OpenTox::Compound.from_sdf(input).uri + "\n"
    when /text\/plain/
      OpenTox::Compound.from_name(input).uri + "\n"
    else
      status 400
      "Unsupported MIME type '#{request.content_type}'"
    end
  rescue
    status 400
    "Cannot process request '#{input}' for content type '#{request.content_type}'"
  end
end
