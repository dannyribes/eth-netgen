# Nombre del archivo JSON de salida
output_file="../../back/redes_blockchain.json"

# Obtiene la lista de redes de Docker que comienzan con "blockchain"
networks=$(docker network ls --filter "name=blockchain*" --format '{{.Name}}')

# Verifica si hay redes encontradas
if [ -n "$networks" ]; then
  # Inicializa el archivo JSON
  echo "[" > "$output_file"
  
  # Itera sobre cada red y escribe en el archivo JSON
  while IFS= read -r network_name; do
    echo "  {\"name\": \"$network_name\"}," >> "$output_file"
  done <<< "$networks"

  sed -i '$ s/,$//' "$output_file"
  
  # Finaliza el archivo JSON
  echo "]" >> "$output_file"
  
  echo "Archivo JSON generado con éxito: $output_file"
else
  echo "No se encontraron redes de Docker que comiencen con 'blockchain'."
fi