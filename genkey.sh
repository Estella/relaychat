echo "Generating Keys"
openssl req -x509 -newkey rsa:4096 -keyout chat.key -out chat.crt -days 365 -nodes
