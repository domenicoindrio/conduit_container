FROM nginx:alpine

# Remove the default Nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy the custom config into the image
COPY nginx.conf /etc/nginx/conf.d/