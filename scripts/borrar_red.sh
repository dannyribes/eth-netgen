if [ "$#" -ne 1 ]; then
  echo "Uso: $0 <nombre_de_red>"
  # echo "Uso: $0 <id_cadena>"
  exit 1
fi

NOMBRE_DE_RED=$1
# CHAIN_ID=$1

# Verificar si la red existe
if docker network inspect "$NOMBRE_DE_RED" &> /dev/null; then

  # Obtener los nombres de los contenedores asociados a la red
  CONTAINER_NAMES=$(docker ps -a --filter "network=$NOMBRE_DE_RED" --format '{{.Names}}')
  echo "CONTAINER_NAMES => " $CONTAINER_NAMES

  # Detener y eliminar cada contenedor asociado a la red
  for CONTAINER_NAME in $CONTAINER_NAMES; do
    echo "CONTAINER_NAME => " $CONTAINER_NAME
    echo "Deteniendo y eliminando contenedor: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
  done 

  # La red existe, así que la eliminamos
  docker network rm "$NOMBRE_DE_RED"
  echo "La red '$NOMBRE_DE_RED' ha sido eliminada."
else
  echo "La red '$NOMBRE_DE_RED' no existe."
fi

# cd ../blockchain-$CHAIN_ID
# docker-compose down