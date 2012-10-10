# compound.rb
# OpenTox Compound
# Author: Andreas Maunz

module OpenTox

  class Application < Service



    ## Get a list of descriptor calculation algorithms
    ## @return [text/uri-list] URIs
    get %r{/compound/(.*)/pc} do
      inchi=params["captures"][0]
      descriptors = YAML::load_file File.join(ENV['HOME'], ".opentox", "config", "pc_descriptors.yaml")
      alg_params = [
        { DC.description => "Dataset URI",
          OT.paramScope => "mandatory",
          DC.title => "dataset_uri" }
      ]
      alg_params << {
        DC.description => "Physico-chemical type, one or more of '#{descriptors.collect { |id, info| info[:pc_type] }.uniq.sort.join(",")}'",
        OT.paramScope => "optional", 
        DC.title => "pc_type"
      }
      alg_params << {
        DC.description => "Software Library, one or more of '#{descriptors.collect { |id, info| info[:lib] }.uniq.sort.join(",")}'",
        OT.paramScope => "optional", 
        DC.title => "lib"
      }
      alg_params << {
        DC.description => "Descriptor, one of '#{descriptors.keys.sort.join(",")}'. Takes precedence over pc_type, lib.",
        OT.paramScope => "optional", 
        DC.title => "descriptor"
      }
      # Contents
      algorithm = OpenTox::Algorithm.new(url_for("/compound/#{inchi}/pc",:full))
      mmdata = {
        DC.title => "pc",
        DC.creator => "andreas@maunz.de",
        DC.description => "PC descriptor calculation",
        RDF.type => [OTA.DescriptorCalculation],
      }
      algorithm.metadata=mmdata
      algorithm.parameters = alg_params
      format_output(algorithm)
    end



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
              
              # Search feature by title
              feature_uri = nil
              sparql = "SELECT DISTINCT ?feature WHERE { ?feature <#{RDF.type}> <#{RDF::OT['feature'.capitalize]}>. ?feature <#{RDF::DC.title}> '#{f.to_s}' }"
              feature_uri = OpenTox::Backend::FourStore.query(sparql,"text/uri-list").split("\n").first # is nil for non-existing feature
              unless feature_uri
                feature = OpenTox::Feature.new feature_uri, @subjectid
                feature.title = f.to_s
                feature.metadata = {
                  RDF.type => [RDF::OT.Feature, RDF::OT.NumericFeature],
                  RDF::DC.creator => creator_uri,
                  RDF::DC.description => description
                }
                feature.put
              else
                feature = OpenTox::Feature.find(feature_uri, @subjectid)
              end
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

