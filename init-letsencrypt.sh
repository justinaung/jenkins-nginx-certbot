#!/bin/bash
# https://github.com/wmnnd/nginx-certbot
domains=("jenkins.myantype.com")
rsa_key_size=4096
data_path="./certbot"
email="justin.aung19@gmail.com" # Adding a valid address is strongly recommended
staging=1 # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi


if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi


echo "### Creating dummy certificate for $domains ..."
for val in ${domains[*]}; do
  path="/etc/letsencrypt/live/$val"
  mkdir -p "$data_path/conf/live/$val"
  docker-compose run --rm --entrypoint " \
    openssl req -x509 -nodes -newkey rsa:1024 -days 1 \
      -keyout '$path/privkey.pem' \
      -out '$path/fullchain.pem' \
      -subj '/CN=localhost'" certbot
  echo
done


echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domains ..."
for val in ${domains[*]}; do
  docker-compose run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/$val && \
    rm -Rf /etc/letsencrypt/archive/$val && \
    rm -Rf /etc/letsencrypt/renewal/$val.conf" certbot
  echo
done


echo "### Requesting Let's Encrypt certificate for $domains ..."
# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

for val in ${domains[*]}; do
  docker-compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
      $staging_arg \
      $email_arg \
      -d $val \
      --rsa-key-size $rsa_key_size \
      --agree-tos \
      --non-interactive
      --force-renewal" certbot
  echo
done

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
