require 'rubygems'
gem "opentox-ruby-api-wrapper", "= 1.5.6"
require 'opentox-ruby-api-wrapper'

set :lock, true
CACTUS_URI="http://cactus.nci.nih.gov/chemical/structure/"

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
		OpenTox::Compound.new(:inchi => inchi).image
	when "text/plain"
		response['Content-Type'] = "text/plain"
		uri = File.join CACTUS_URI,inchi,"names"
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
