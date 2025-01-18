# Dockerfile for Nginx reverse proxy
FROM nginx:latest

# Install envsubst for dynamic configuration
RUN apt-get update && apt-get install -y gettext-base

# Copy the Nginx template to the container
COPY pod/nginx.conf /etc/nginx/templates/nginx.conf.template

# Use envsubst to replace variables before starting Nginx
CMD ["sh", "-c", "envsubst '${PORT}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf && cat /etc/nginx/nginx.conf && nginx -t && nginx -g 'daemon off;'"]
