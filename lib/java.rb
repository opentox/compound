# Contains Java settings.
# # Joelib runs on Java.
# # Author: Andreas Maunz, 2012

java_dir = File.join File.expand_path(File.dirname(__FILE__)),"../java"
dirs = jars = []
dirs << "#{ENV["JAVA_HOME"]}/lib/tools.jar"
dirs << "#{ENV["JAVA_HOME"]}/lib/classes.jar"
dirs << "#{java_dir}" + "/joelib"
dirs << "#{java_dir}" + "/cdk"
jars << Dir[java_dir+"/joelib/*.jar"].collect {|f| File.expand_path(f) }
jars << Dir[java_dir+"/cdk/*.jar"].collect {|f| File.expand_path(f) }
ENV["CLASSPATH"] = (dirs + jars).join(":")

