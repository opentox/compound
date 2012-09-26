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
      #$logger.debug cdk_ids.to_yaml
      #cdk_single_ids.collect { |x| $logger.debug x }
      #$logger.debug cdk_single_ids.to_yaml
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

          #cdk_single_ids && cdk_single_ids.each_with_index { |id,idx|
          #  raise "Feature not found" if ! ds.features[File.join(ds.uri, "feature", id.to_s)]
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{DC.description => "#{pc_descriptors[cdk_ids[idx]][:name]} [#{pc_descriptors[cdk_ids[idx]][:pc_type]}, #{pc_descriptors[cdk_ids[idx]][:lib]}]"})
          #  creator_uri = ds.uri.gsub(/\/dataset\/.*/, "/algorithm/pc")
          #  creator_uri += "/#{cdk_ids[idx]}" if params[:add_uri]
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{DC.creator => creator_uri})
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{OT.hasSource => params[:dataset_uri]})
          #}

          #ob_ids && ob_ids.each { |id|
          #  raise "Feature not found" if ! ds.features[File.join(ds.uri, "feature", id.to_s)]
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{DC.description => "#{pc_descriptors[id][:name]} [#{pc_descriptors[id][:pc_type]}, #{pc_descriptors[id][:lib]}]"})
          #  creator_uri = ds.uri.gsub(/\/dataset\/.*/, "/algorithm/pc")
          #  creator_uri += "/#{id}" if params[:add_uri]
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{DC.creator => creator_uri})
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{OT.hasSource => params[:dataset_uri]})
          #}
          #jl_ids && jl_ids.each { |id|
          #  raise "Feature not found" if ! ds.features[File.join(ds.uri, "feature", id.to_s)]
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{DC.description => "#{pc_descriptors[id][:name]} [#{pc_descriptors[id][:pc_type]}, #{pc_descriptors[id][:lib]}]"})
          #  creator_uri = ds.uri.gsub(/\/dataset\/.*/, "/algorithm/pc")
          #  creator_uri += "/#{id}" if params[:add_uri]
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{DC.creator => creator_uri})
          #  ds.add_feature_metadata(File.join(ds.uri, "feature", id.to_s),{OT.hasSource => params[:dataset_uri]})
          #}


          features = []
          pc_descriptors = YAML::load_file($keysfile)
          master[0].each_with_index { |f,idx|
            if (idx != 0)

              # Description
              description = ""
              descriptor_name = ""
              if cdk_single_ids # we have used CDK
                idx = cdk_single_ids.index(f)
                cdk_id = cdk_ids[idx] if idx
              end
              if cdk_id
                #$logger.debug "#{f} in CDK: #{pc_descriptors[cdk_id][:name]}"
                descriptor_name = pc_descriptors[cdk_id][:name]
                description = "#{descriptor_name} [#{pc_descriptors[cdk_id][:pc_type]}, #{pc_descriptors[cdk_id][:lib]}]" 
              else
                #$logger.debug "#{f} not in CDK"
                if pc_descriptors[f]
                  descriptor_name = pc_descriptors[f][:name]
                  description = "#{descriptor_name} [#{pc_descriptors[f][:pc_type]}, #{pc_descriptors[f][:lib]}]"
                else
                  internal_server_error "PC feature '#{f}' not found"
                end
              end

              # Creator URI
              creator_uri = File.join url_for("/compound/#{inchi}/pc",:full), f
        
              feature = OpenTox::Feature.new nil, @subjectid
              feature.title = f.to_s
              feature.metadata = {
                RDF.type => [RDF::OT.Feature],
                RDF::DC.creator => creator_uri,
                RDF::DC.description => description
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

    end

  end

end

