# application.rb
# Author: Christoph Helma, Andreas Maunz
require 'openbabel'

$logger.debug "Compound booting: #{$compound.collect{|k,v| "#{k}: '#{v}'"} }"

module OpenTox
  class Application < Service

    FORMATS = {
      "chemical/x-daylight-smiles" => "smi",
      "chemical/x-inchi" => "inchi",
      #"chemical/x-inchikey" => "inchikey",
      # OpenBabel segfaults randomly during inchikey calculation
      "chemical/x-mdl-sdfile" => "sdf",
      "chemical/x-mdl-molfile" => "sdf",
      "image/png" => '_png2',
    }

    helpers do
      # Convert identifier from OpenBabel input_format to OpenBabel output_format
      def obconversion(identifier,input_format,output_format,option=nil)
        obconversion = OpenBabel::OBConversion.new
        obconversion.set_options(option, OpenBabel::OBConversion::OUTOPTIONS) if option
        obmol = OpenBabel::OBMol.new
        obconversion.set_in_and_out_formats input_format, output_format
        obconversion.read_string obmol, identifier
        case output_format
        when /smi|can|inchi/
          obconversion.write_string(obmol).gsub(/\s/,'').chomp
        else
          obconversion.write_string(obmol)
        end
      end
    end

    before do
      @inchi = URI.unescape request.env['REQUEST_URI'].sub(/^\//,'').sub(/.*compound\//,'').sub(/\/smarts.*$/,'').sub(/\/image/,'').sub(/\?.*$/,'') # hack to avoid sinatra's URI/CGI unescaping, splitting, ..."
    end
    
    # for service check
    head "/compound/?" do
    end

    get "/compound/?" do
      #"Object listing not implemented, because compounds are not stored at the server.".to_html
      not_implemented_error "Object listing not implemented, because compounds are not stored at the server.", to("/compound")
    end

    get %r{/compound/(.+)/image} do |inchi| # catches all remaining get requests
      response['Content-Type'] = 'image/png'
      obconversion @inchi, "inchi", "_png2", (params["size"] ? 'p"'+params["size"]+'"' : nil)
    end

    # Get compound representation
    # @method get_compound_inchi
    # @overload get /compound/:id
    # @param header [Hash] header values
    #   * Accept [String] <chemical/x-daylight-smiles, chemical/x-inchi, chemical/x-mdl-sdfile, chemical/x-mdl-molfile, image/png, text/html> 
    # @return [String] <chemical/x-daylight-smiles, chemical/x-inchi, chemical/x-mdl-sdfile, chemical/x-mdl-molfile, image/png, text/html> Compound representation
    # @example Get smiles
    #   curl http://webservices.in-silico.ch/compound/InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H
    # @example Get all known names 
    #   curl -H "Accept:text/plain" http://webservices.in-silico.ch/compound/InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H
    get %r{/compound/(?!api)(.+)} do |inchi| # catches all remaining get requests
      pass if inchi =~ /.*\/pc/ # AM: pass on to PC descriptor calculation
      if @accept=~/html/
        text = "URI:\t#{uri}\n"
        text << "Inchi:\t#{@inchi}\n"
        text << "SMILES:\t#{obconversion(@inchi, "inchi", "can")}\n"
        text << "sdf:\t#{obconversion(@inchi, "inchi", "sdf")}\n"
        text.to_html(nil,nil,obconversion(@inchi,"inchi","_png2"))
      else
        bad_request_error "Unsupported MIME type '#{@accept}.", uri unless FORMATS.keys.include? @accept
        return @inchi if @accept == "chemical/x-inchi"
        obconversion @inchi, "inchi", FORMATS[@accept], (params["size"] ? 'p"'+params["size"]+'"' : nil)
      end
    end

    
    # Create a new compound URI (compounds are not saved at the compound service)
    # @method post_compound
    # @overload post /compound
    # @param header [Hash] header values
    #   * Content-Type [String] one of <chemical/x-daylight-smiles, chemical/x-inchi, chemical/x-mdl-sdfile, chemical/x-mdl-molfile>
    # @example Create compound from Smiles string
    #   curl -X POST -H "Content-type:chemical/x-daylight-smiles" --data "c1ccccc1" http://webservices.in-silico.ch/compound
    # @example Create compound from name, uses an external lookup service and should work also with trade names, CAS numbers, ...
    #   curl -X POST -H "Content-type:text/plain" --data "Benzene" http://webservices.in-silico.ch/compound
    # @param [BODY] - string with identifier/data in selected Content-type
    # @return [String] <text/uri-list> compound URI
    post '/compound/?' do 
      response['Content-Type'] = 'text/uri-list'
      bad_request_error "Unsupported MIME type '#{@content_type}.", uri unless FORMATS.keys.include? @content_type
      return to(File.join("/compound",@body)) if @content_type == "chemical/x-inchi"
      to(File.join("compound",obconversion(@body, FORMATS[@content_type], "inchi")))
    end

  end
end
