# FINAL, SECURE DOCKERFILE

# Use a lightweight Nginx web server as the base image
FROM nginx:alpine

# Remove the default Nginx configuration file
RUN rm /etc/nginx/conf.d/default.conf

# Copy our custom, non-root-friendly Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy our application files. The .dockerignore file will ensure
# that only the necessary files (HTML, CSS, JS) are copied.
COPY . /usr/share/nginx/html

# Switch to the non-root 'nginx' user that comes with the official image
USER nginx

# Expose the non-privileged port we defined in our custom nginx.conf
EXPOSE 80

# Command to start Nginx using our custom configuration
CMD ["nginx", "-c", "/etc/nginx/nginx.conf"]
