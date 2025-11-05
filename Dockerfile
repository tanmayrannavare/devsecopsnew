# Use a lightweight Nginx web server as the base image
FROM nginx:alpine

# Copy your application files (HTML, CSS, JS) into the Nginx web root directory
COPY . /usr/share/nginx/html

# Expose port 80 to allow traffic to the web server
EXPOSE 80

# The command to start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]
