# Use OpenJDK 11 as the base image
FROM openjdk:11-jdk-slim

# Set environment variables
ENV WILDFLY_VERSION 26.1.3.Final
ENV JBOSS_HOME /opt/jboss/wildfly
ENV MYSQL_CONNECTOR_VERSION 8.0.27
ENV MAVEN_VERSION 3.8.4

# Install necessary tools and clean up in a single layer
RUN apt-get update && \
    apt-get install -y curl unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install Maven
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz | tar xzf - -C /opt/ && \
    ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven && \
    ln -s /opt/maven/bin/mvn /usr/local/bin

# Create necessary directories
RUN mkdir -p /opt/jboss

# Download and install WildFly
RUN curl -L https://github.com/wildfly/wildfly/releases/download/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.zip -o wildfly.zip && \
    unzip wildfly.zip && \
    mv wildfly-${WILDFLY_VERSION} ${JBOSS_HOME} && \
    rm wildfly.zip

# Add MySQL JDBC driver
RUN mkdir -p ${JBOSS_HOME}/modules/system/layers/base/com/mysql/main && \
    curl -L https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar \
    -o ${JBOSS_HOME}/modules/system/layers/base/com/mysql/main/mysql-connector-java.jar

# Copy module.xml
COPY module.xml ${JBOSS_HOME}/modules/system/layers/base/com/mysql/main/

# Copy standalone.xml
COPY standalone.xml ${JBOSS_HOME}/standalone/configuration/

# Create jboss user and set up Maven repository
RUN groupadd -r jboss -g 1000 && \
    useradd -u 1000 -r -g jboss -m -d /opt/jboss -s /sbin/nologin -c "JBoss user" jboss && \
    mkdir -p /opt/jboss/.m2/repository && \
    chown -R jboss:jboss ${JBOSS_HOME} /opt/jboss/.m2

# Switch to jboss user
USER jboss

# Build the kitchensink application
WORKDIR /tmp
RUN curl -L https://github.com/jboss-developer/jboss-eap-quickstarts/archive/refs/heads/8.0.x.zip -o quickstarts.zip && \
    unzip quickstarts.zip && \
    cd jboss-eap-quickstarts-8.0.x/kitchensink && \
    mvn clean package && \
    cp target/kitchensink.war ${JBOSS_HOME}/standalone/deployments/ && \
    rm -rf /tmp/quickstarts.zip /tmp/jboss-eap-quickstarts-8.0.x ~/.m2/repository

# Set the working directory back to JBOSS_HOME
WORKDIR ${JBOSS_HOME}

# Set environment variables
ENV DB_HOST=database \
    DB_PORT=3306 \
    DB_NAME=kitchensink \
    DB_USER=kitchen \
    DB_PASSWORD=kitchen

# Expose the default ports
EXPOSE 8080 9990

# Start WildFly
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]