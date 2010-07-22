# Java environment
ENV["JAVA_HOME"] = "/usr/lib/jvm/java-6-sun" unless ENV["JAVA_HOME"]
java_dir = File.join File.expand_path(File.dirname(__FILE__)),"public/java"
cdk = File.join java_dir, "cdk-1.3.5.jar"
jchempaint = File.join java_dir, "cdk-jchempaint-15.jar"
ENV["CLASSPATH"] = "#{ENV["CLASSPATH"]}:#{java_dir}:#{cdk}:#{jchempaint}"

require 'rubygems'
require 'rjb'
gem "opentox-ruby-api-wrapper", "= 1.6.0"
require 'opentox-ruby-api-wrapper'

get %r{/smiles/(.+)/smarts/(.*)} do |smiles,smarts| 
		content_type "image/png"
		attachment "#{smiles}.png"
    #LOGGER.debug "SMILES: #{smiles}, SMARTS: #{smarts}"
    s = Rjb::import('Structure').new(smiles,200)
    s.match(smarts)
    s.show
end


get %r{/smiles/(.+)} do |smiles| 
		content_type "image/png"
		attachment "#{smiles}.png"
    Rjb::import('Structure').new(smiles,200).show
end

get %r{/(.+)/image} do |inchi| # catches all remaining get requests

		smiles = OpenTox::Compound.new(:inchi => inchi).smiles
		content_type "image/png"
		attachment "#{smiles}.png"
    Rjb::import('Structure').new(smiles,200).show

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

	input =	request.env["rack.input"].read
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
