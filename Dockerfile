# Fetch images from docker hub
FROM wiseoldman/app:latest as app-build
FROM wiseoldman/bot-website:latest as bot-website-build

# Setup NGINX image
FROM nginx:alpine

COPY /nginx.conf /etc/nginx/conf.d/
RUN rm /etc/nginx/conf.d/default.conf

# Copy the static files into the NGINX html files
COPY --from=app-build /wise-old-man/app/build /var/www/html/app
COPY --from=bot-website-build /wise-old-man/bot-website/public /var/www/html/bot-website

EXPOSE 80
CMD [ "nginx", "-g", "daemon off;" ]
