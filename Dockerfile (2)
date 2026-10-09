# Official nginx as the Supabase API gateway (replaces Kong/Envoy; Shelf only needs Auth + Storage).
FROM nginx:1.28-alpine
COPY default.conf /etc/nginx/conf.d/default.conf
COPY email-templates/ /usr/share/nginx/email-templates/
