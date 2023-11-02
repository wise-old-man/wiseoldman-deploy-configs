# Fetch website images from docker hub
FROM wiseoldman/app:latest as app-build

# Setup NGINX image
FROM nginx:alpine

COPY /nginx.conf /etc/nginx/conf.d/
RUN rm /etc/nginx/conf.d/default.conf

# Copy the static files into the NGINX html files
COPY --from=app-build /wise-old-man/app/build /var/www/html/app

EXPOSE 80
CMD [ "nginx", "-g", "daemon off;" ]
