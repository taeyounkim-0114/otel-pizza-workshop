FROM nginx:1.31.6-alpine3.24

COPY index.html /usr/share/nginx/html/
COPY dash0.js.template /etc/nginx/dash0/dash0.js.template
COPY docker-entrypoint.d/10-dash0-config.sh /docker-entrypoint.d/10-dash0-config.sh

RUN chmod +x /docker-entrypoint.d/10-dash0-config.sh

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
