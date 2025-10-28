# Use official Tomcat base image
FROM tomcat:9.0-jdk17

# Remove default ROOT web app
RUN rm -rf /usr/local/tomcat/webapps/ROOT

# Copy your WAR into Tomcat's webapps folder as ROOT.war
COPY target/my-webapp.war /usr/local/tomcat/webapps/ROOT.war

# Expose Tomcat default port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
