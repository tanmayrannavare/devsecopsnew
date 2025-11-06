# Use lightweight Nginx
FROM nginx:alpine

# Remove default Nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom Nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy application files
COPY . /usr/share/nginx/html

# Expose port 80 for the web app
EXPOSE 80

# Start Nginx in foreground
CMD ["nginx", "-c", "/etc/nginx/nginx.conf"]
