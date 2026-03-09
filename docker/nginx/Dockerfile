FROM nginx:alpine

# Copy nginx configuration
COPY conf.d/default.conf /etc/nginx/conf.d/default.conf

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Create VNC access log (nginx creates on first write, but pre-create for debugging)
RUN touch /var/log/nginx/vnc_access.log

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
