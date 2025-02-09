FROM kong/kong-gateway:3.8.1.0-ubuntu

# Ensure any patching steps are executed as root user
USER root

# Install dependencies
RUN apt update && apt install -y git zlib1g-dev lua5.1 luarocks

# Install Lua zlib module
RUN luarocks install lua-zlib

# Ensure Kong uses the updated dependencies
RUN kong prepare

# Set file permissions
RUN chown -R kong:kong /usr/local/kong

# Add custom plugin to the image
COPY kong/plugins/treblle /usr/local/share/lua/5.1/kong/plugins/treblle
ENV KONG_PLUGINS=bundled,treblle

# Ensure kong user is selected for image execution
USER kong

# Run kong
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8000 8443 8001 8444
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=10s --timeout=10s --retries=10 CMD kong health
CMD ["kong", "docker-start"]
