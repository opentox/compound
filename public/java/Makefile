#all: DisplayStructure.class
all: Display.class

#%.class: %.java
#	javac -Xlint:deprecation -Xlint:unchecked -classpath ./:./cdk-1.0.1.jar $<

%.class: %.java
	javac -classpath ./:./cdk-1.3.5.jar:./cdk-jchempaint-15.jar $<
	#javac -Xlint:deprecation -Xlint:unchecked -classpath ./:./cdk-1.3.5.jar:./cdk-jchempaint-15.jar $<
