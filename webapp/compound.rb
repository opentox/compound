# compound.rb
# OpenTox Compound
# Author: Andreas Maunz

module OpenTox

  class Application < Service

    # Calculate PC descriptors
    # Single descriptors or sets of descriptors can be selected
    # Sets are selected via lib and/or pc_type, and take precedence, when also a descriptor is submitted
    # If none of descriptor, lib, and pc_type is submitted, all descriptors are calculated
    # Set composition is induced by intersecting lib and pc_type sets, if appropriate
    # @param [optional, HEADER] accept Accept one of 'application/rdf+xml', 'text/csv', defaults to 'application/rdf+xml'
    # @param [optional, String] descriptor A single descriptor to calculate values for.
    # @param [optional, String] lib One or more descriptor libraries out of [cdk,joelib,openbabel], for whose descriptors to calculate values.
    # @param [optional, String] pc_type One or more descriptor types out of [constitutional,topological,geometrical,electronic,cpsa,hybrid], for whose descriptors to calculate values
    # @return [application/rdf+xml,text/csv] Compound descriptors and values
    post %r{/compound/(.*)/pc} do
      inchi=params["captures"][0]
      smiles=obconversion inchi, "inchi", "smi"
      params.delete('splat')
      params.delete('captures')
      params_array = params.collect{ |k,v| [k.to_sym, v]}
      params = Hash[params_array]
      params[:inchi] = inchi
      params[:smiles] = smiles
      params[:compound] = File.join($compound[:uri], inchi) 
      descriptor = params[:descriptor].nil? ? "" : params[:descriptor]
      lib = params[:lib].nil? ? "" : params[:lib]
      pc_type = params[:pc_type].nil? ? "" : params[:pc_type]
      pcdf = OpenTox::Compound::PcDescriptorFactory.new(params)
      master, cdk_ids, ob_ids, jl_ids, cdk_single_ids = pcdf.calculate
      begin 
        if master
          feature_dataset = OpenTox::Dataset.new(nil, @subjectid)
          feature_dataset.metadata = {
            RDF::DC.title => "Physico-chemical descriptors",
            RDF::DC.creator => url_for("/compound/#{inchi}/pc",:full),
            RDF::OT.hasSource => url_for("/compound/#{inchi}/pc", :full),
          }
          feature_dataset.parameters = [
              { RDF::DC.title => "compound_uri", RDF::OT.paramValue => params[:compound] },
              { RDF::DC.title => "descriptor", RDF::OT.paramValue => descriptor },
              { RDF::DC.title => "lib", RDF::OT.paramValue => lib },
              { RDF::DC.title => "pc_type", RDF::OT.paramValue => pc_type},
          ]
          features = []
          master[0].each_with_index { |f,idx|
            if (idx != 0)
              feature = OpenTox::Feature.new nil, @subjectid
              feature.title = f.to_s
              feature.metadata = {
                RDF.type => [RDF::OT.Feature],
              }
              features << feature
            end
          }
          feature_dataset.features = features
          master[1][0] = OpenTox::Compound.new(params[:compound], @subjectid) 
          feature_dataset << master[1].to_a
          format_output(feature_dataset)
        end
      rescue => e
        $logger.debug "#{e.class}: #{e.message}"
        $logger.debug "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
      end

        #begin 
        #  tf = Tempfile.open(['compound-','.csv'])
        #  tf.puts master.collect { |row| row.join(",") }.join("\n")
        #  tf.flush
        #  ds = OpenTox::Dataset.new nil, nil
        #  # Does not work here:
        #  #ds.upload tf.path 
        #  uri = RestClientWrapper.put(ds.uri, {:file => File.new(tf.path)}, {:subjectid => @subjectid})
        #  $logger.debug "Waiting for upload (single CSV row): #{uri}"
        #  OpenTox::Task.new(uri).wait if URI.task?(uri)
        #  $logger.debug "Waiting finished"
        #  ds.get
        #  $logger.debug "AM: #{ds.uri}"
        #rescue => e
        #  $logger.debug "#{e.class}: #{e.message}"
        #  $logger.debug "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        #end



        ## # # add feature metadata
        #pc_descriptors = YAML::load_file($keysfile)
        #cdk_single_ids && cdk_single_ids.each_with_index { |id,idx|
        #  raise "Feature not found" if ! ds.features[File.join(ds.uri, "feature", id.to_s)]
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::DC.description => "#{pc_descriptors[cdk_ids[idx]][:name]} [#{pc_descriptors[cdk_ids[idx]][:pc_type]}, #{pc_descriptors[cdk_ids[idx]][:lib]}]"})
        #  creator_uri = ds.uri.gsub(/\/dataset\/.*/, "/algorithm/pc")
        #  creator_uri += "/#{cdk_ids[idx]}" if params[:add_uri]
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::DC.creator => creator_uri})
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::OT.hasSource => params[:dataset_uri]})
        #}
        #ob_ids && ob_ids.each { |id|
        #  raise "Feature not found" if ! ds.features[File.join(ds.uri, "feature", id.to_s)]
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::DC.description => "#{pc_descriptors[id][:name]} [#{pc_descriptors[id][:pc_type]}, #{pc_descriptors[id][:lib]}]"})
        #  creator_uri = ds.uri.gsub(/\/dataset\/.*/, "/algorithm/pc")
        #  creator_uri += "/#{id}" if params[:add_uri]
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::DC.creator => creator_uri})
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::OT.hasSource => params[:dataset_uri]})
        #}
        #jl_ids && jl_ids.each { |id|
        #  raise "Feature not found" if ! ds.features[File.join(ds.uri, "feature", id.to_s)]
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::DC.description => "#{pc_descriptors[id][:name]} [#{pc_descriptors[id][:pc_type]}, #{pc_descriptors[id][:lib]}]"})
        #  creator_uri = ds.uri.gsub(/\/dataset\/.*/, "/algorithm/pc")
        #  creator_uri += "/#{id}" if params[:add_uri]
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::DC.creator => creator_uri})
        #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{RDF::OT.hasSource => params[:dataset_uri]})
        #}
      #$logger.debug master.size
      #$logger.debug master.collect { |r| r.join(',') }.join("\n")
      #$logger.debug ""
    end

  end

end

