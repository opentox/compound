=begin
* Name: pc_descriptors.rb
* Description: Calculation of pc descriptors
* Author: Andreas Maunz <andreas@maunz.de>
* Date: 10/2012
=end

require 'csv'

module OpenTox

  class Compound

    class PcDescriptorFactory
      def initialize params
        @params = params
        @lib = params[:lib].split(',') if params[:lib]
      end

      # Calculate physico-chemical descriptors for a given compound.
      # Results are returned as CSV, together with ids (descriptor names) used
      # @return[Array] CSV master, ids for cdk, ob, jl, cdk single ids
      def calculate 
        cdk_master, ob_master, jl_master = nil
        cdk_ids, ob_ids, jl_ids = nil
        cdk_single_ids = nil
        if (!@lib || @lib.include?("cdk"))
          cdk = CDKDescriptors.new(@params)
          cdk_master, cdk_ids = cdk.calculate
          cdk_single_ids = cdk_master[0].to_a.collect { |id| id.to_s.sub(/[^-]*-/,"").gsub(/[\/.\\\(\)\{\}\[\]]/,"_") } # get column headers w/ nice '_'
          cdk_master[0].each_index{ |idx| cdk_master[0][idx] = cdk_single_ids[idx] } # Single IDs as features in result ds
          cdk_single_ids.shift # remove SMILES for IDs
        end
        if (!@lib || @lib.include?("openbabel"))
          openbabel = OpenBabelDescriptors.new(@params)
          openbabel_master, openbabel_ids = openbabel.calculate
        end
        if (!@lib || @lib.include?("joelib"))
          joelib = JoelibDescriptors.new(@params)
          joelib_master, joelib_ids = joelib.calculate
        end
        master = master_join(cdk_master, joelib_master)
        master = master_join(master, openbabel_master)
        [ master, cdk_ids, ob_ids, jl_ids, cdk_single_ids ]
      end

      # Right-merges CSV data m2 onto m1
      # @param[Array] m1 the left part
      # @param[Array] m2 the right part
      # @return[Array] m1 with m2 merged onto it
      def master_join (m1, m2)
        if m2 && m1
          nr_cols = (m2[0].size)-1
          $logger.debug "Merging #{nr_cols} new columns on #{m1[0].size} (including ID), yields #{nr_cols + m1[0].size}"
          m1.each {|row| nr_cols.times { row.push(nil) }  }
          m2.each do |row|
            temp = m1.assoc(row[0]) # Finds the appropriate line in master
            ((-1*nr_cols)..-1).collect.each { |idx|
              temp[idx] = row[nr_cols+idx+1] if temp # Updates columns if line is found
            }
          end
          master = m1
        else # either m2 or m1 nil
          master = m2 || m1
        end
        
      end

    end


    # Calculate physico-chemical descriptors for a given compound.
    class PcDescriptors
      # @param[Hash] params required keys: :inchi optional keys: :descriptor, :lib, :pc_type
      def initialize(params)
        @inchi = params[:inchi]
        @smiles = params[:smiles]
        @lib = params[:lib].split(',') if params[:lib]
        @pc_type = params[:pc_type].split(',') if params[:pc_type]
        @descriptor = params[:descriptor]
        @compound = params[:compound]
        # Does not work here: OpenTox::RestClientWrapper.post($compound[:uri],inchi,{:content_type => 'chemical/x-inchi'})
        # Does not work here: OpenTox::Compound.from_inchi($compound[:uri],inchi)
        # Java start
        Rjb.load(nil,["-Xmx128m"]) # start vm
        jSystem = Rjb::import('java.lang.System')
        jPrintStream = Rjb::import('java.io.PrintStream')
        jFile = Rjb::import('java.io.File')
        p = jPrintStream.new(jFile.new('java_debug.txt'))
        jSystem.setOut(p)
        jSystem.setErr(p)
      end
    end


    # No initialize(): Creating an instance with params automatically calls super
    class CDKDescriptors < PcDescriptors
      # Calculate CDK descriptors
      # @return[Array] 2-Array containing headers and data row
      def calculate
        master = nil
        cdk_class = nil
        ids_multiplied = nil
        begin
          cdk_class = Rjb::import('ApplyCDKDescriptors')
          pc_descriptors = YAML::load_file($keysfile)
          ids = pc_descriptors.collect{ |id, info| 
            id if info[:lib] == "cdk" && (!@pc_type || @pc_type.include?(info[:pc_type])) && (!@descriptor || id == @descriptor)
          }.compact
          if ids.length > 0
            sdf_data = []
            $logger.debug "3D for #{@smiles}"
            obconv = OpenBabel::OBConversion.new
            obmol = OpenBabel::OBMol.new
            obconv.set_in_format("smi") 
            obconv.read_string(obmol, @smiles) 
            obconv.set_out_format("sdf") 
            sdf_string = obconv.write_string(obmol)  
            gen3d = OpenBabel::OBOp.find_type("Gen3D") 
            gen3d.do(obmol) 
            sdf_string_3d = obconv.write_string(obmol)  
            if sdf_string_3d.index(/.nan/).nil?
              sdf_data << sdf_string_3d
            else
              sdf_data << sdf_string
              $logger.debug "3D failed (using 2D)"
            end
            infile = Tempfile.open(['jl_descriptors-in-','.sdf'])
            csvfile = infile.path.gsub(/jl_descriptors-in/,"jl_descriptors-out").gsub(/\.sdf/,".csv")
            infile.puts sdf_data.join("")
            infile.flush
            cdk_class.new(infile.path, csvfile, ids.join(','))
            master = CSV::parse(File.open(csvfile, "rb").read)
            $logger.debug "CDK: #{master[0].size-1} entries"
            master[0][0] = "InChI"
            master[1][0] = "\"#{@inchi}\""
            master[1].collect! { |x| x.to_s == "null" ? nil : x }
            ids_multiplied = master[0].to_a.collect { |x| x.gsub(/-.*/,"") }
            ids_multiplied.shift # remove ID
          end
        #rescue Exception => e
          #$logger.debug "#{e.class}: #{e.message}"
          #$logger.debug "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        ensure
          [ csvfile ].each { |f| File.delete(f) } if csvfile
        end
        [ master, ids_multiplied ]
      end
    end


    class JoelibDescriptors < PcDescriptors
      # Calculate Joelib descriptors
      # @return[Array] 2-Array containing headers and data row
      def calculate
        master = joelib_class = infile = outfile_path = nil
        begin
          joelib_class = Rjb::import('JoelibFc')
          pc_descriptors = YAML::load_file($keysfile)
          ids = pc_descriptors.collect{ |id, info| 
            id if info[:lib] == "joelib" && (!@pc_type || @pc_type.include?(info[:pc_type])) && (!@descriptor || id == @descriptor)
          }.compact
          if ids.length > 0
            csvfile = Tempfile.open(['jl_descriptors-','.csv'])
            csvfile.puts((["InChI"] + ids).join(","))
            obconv = OpenBabel::OBConversion.new
            obmol = OpenBabel::OBMol.new
            obconv.set_in_format("smi") 
            obconv.read_string(obmol, @smiles) 
            obconv.set_out_format("sdf") 
            sdf_string = obconv.write_string(obmol)  
            infile = Tempfile.open(['jl_descriptors-in-','.sdf'])
            outfile_path = infile.path.gsub(/jl_descriptors-in/,"jl_descriptors-out")
            infile.puts sdf_string
            infile.flush
            joelib_class.new(infile.path, outfile_path) # runs joelib
            row = [ "\"#{@inchi}\"" ]
            ids.each do |k| # Fill row
              re = Regexp.new(k)
              open(outfile_path) do |f|
                f.each do |line|
                  if @prev == k
                    entry = line.chomp
                    val = nil
                    if entry.numeric?
                      val = Float(entry)
                      val = nil if val.nan?
                      val = nil if (val && val.infinite?)
                    end
                    row << val
                    break
                  end
                  @prev = line.gsub(/^.*types./,"").gsub(/count./,"").gsub(/>/,"").chomp if line =~ re
                end
              end
            end
            $logger.debug "Joelib: #{row.size-1} entries"
            csvfile.puts(row.join(","))
            csvfile.flush
            master = CSV::parse(File.open(csvfile.path, "rb").read)
          end
        #rescue Exception => e
          #$logger.debug "#{e.class}: #{e.message}"
          #$logger.debug "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        ensure
          File.delete(infile.path.gsub(/\.sdf/,".numeric.sdf")) if infile
          File.delete(outfile_path) if outfile_path if outfile_path
        end
        [ master, ids ]
      end
    end


    class OpenBabelDescriptors < PcDescriptors
      # Calculate OpenBabel descriptors
      # @return[Array] 2-Array containing headers and data row
      def calculate
        master = nil
        csvfile = nil
        begin
          csvfile = Tempfile.open(['ob_descriptors-','.csv'])
          pc_descriptors = YAML::load_file($keysfile)
          ids = pc_descriptors.collect{ |id, info| 
            id if info[:lib] == "openbabel" && (!@pc_type || @pc_type.include?(info[:pc_type])) && (!@descriptor || id == @descriptor)
          }.compact
          if ids.length > 0
            csvfile.puts((["InChI"] + ids).join(","))
            obmol = OpenBabel::OBMol.new
            obconversion = OpenBabel::OBConversion.new
            obconversion.set_in_and_out_formats 'inchi', 'can'
            row = [ "\"#{@inchi}\"" ]
            obconversion.read_string(obmol, @inchi)
            ids.each { |name|
              if obmol.respond_to?(name.underscore)
                val = eval("obmol.#{name.underscore}") if obmol.respond_to?(name.underscore) 
              else
                if name != "nF" && name != "spinMult" && name != "nHal" && name != "logP"
                  val = OpenBabel::OBDescriptor.find_type(name.underscore).predict(obmol)
                elsif name == "nF"
                  val = OpenBabel::OBDescriptor.find_type("nf").predict(obmol)
                elsif name == "spinMult" || name == "nHal" || name == "logP"
                  val = OpenBabel::OBDescriptor.find_type(name).predict(obmol)
                end
              end
              if val.numeric?
                val = Float(val)
                val = nil if val.nan?
                val = nil if (val && val.infinite?)
              end
              row << val
            }
            $logger.debug "OpenBabel: #{row.size-1} entries"
            csvfile.puts(row.join(","))
            csvfile.flush
            master = CSV::parse(File.open(csvfile.path, "rb").read)
          end
        #rescue Exception => e
          #$logger.debug "#{e.class}: #{e.message}"
          #$logger.debug "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        ensure
          csvfile.close!  if csvfile
        end
        [ master, ids ]
      end
    end

  end
end


