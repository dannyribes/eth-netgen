if [ "$#" -ne 1 ]; then
  echo "Uso: $0 <id_cadena>"
  exit 1
fi

CHAIN_ID=$1

# Función para generar una contraseña aleatoria
generate_password() {
  tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c 16
}

# Genera y muestra la contraseña
generate_password > ../blockchain-$CHAIN_ID/pwd.txt
echo "Contraseña generada"