printf "
\tssl_certificate       ${SSL_CERTIFICATE};
\tssl_certificate_key   ${SSL_CERTIFICATE_KEY};
\tssl_protocols         ${SSL_PROTOCOLS};
\tssl_ciphers           ${SSL_CIPHERS};
\n";

if [[ "$SSL_PASSWORD_FILE" != "" ]]; 
then
    printf "\tssl_password_file ${SSL_PASSWORD_FILE};\n"
fi