FROM python:3.12-slim

RUN pip install --no-cache-dir websockify

WORKDIR /var/www

EXPOSE 6080

CMD ["sh", "-c", "mkdir -p /var/www/storage/app && touch /var/www/storage/app/vnc-tokens.txt && exec websockify -v --token-plugin TokenFile --token-source /var/www/storage/app/vnc-tokens.txt 0.0.0.0:6080"]
