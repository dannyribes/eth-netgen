set -x

if [ "$#" -ne 2 ]; then
  echo "Uso: $0 <numero_nodos> <id_cadena>"
  exit 1
fi

NUM_NODOS=$1
CHAIN_ID=$2

# Crear directorio para almacenar archivos generados
mkdir -p ../blockchain-$CHAIN_ID

# Borrar el directorio keystore si ya existe
if [ -d "../blockchain-$CHAIN_ID/keystore" ]; then
  rm -rf ../blockchain-$CHAIN_ID/keystore
fi

# Generamos una contraseña aleatoria y la escribimos en el archivo pwd.txt
./generar_password.sh $CHAIN_ID

# Crear la configuración inicial del genesis.json
cat > ../blockchain-$CHAIN_ID/genesis.json <<EOF
{
  "config": {
    "chainId": $CHAIN_ID,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "clique": {
      "period": 15,
      "epoch": 30000
    }
  },
  "coinbase": "0x0000000000000000000000000000000000000000",
  "difficulty": "0x20000",
  "extraData": "0x",
  "gasLimit": "0x2fefd8",
  "alloc": {}
}
EOF

# Agregar cuentas para los nodos
for i in $(seq 1 $NUM_NODOS); do  #for ((i=1; i<=$NUM_NODOS; i++)); do
    ADDRESS=$(printf "0x%02x" $i)
    echo "Creando cuenta para nodo $i: $ADDRESS"
    ACCOUNT=$(geth --datadir ../blockchain-$CHAIN_ID account new --password ../blockchain-$CHAIN_ID/pwd.txt | awk '/Public address of the key/ {print $6}')
    # echo $ACCOUNT

    if [ $i -eq 1 ]; then
      SIGNER_ADDRESS=$ACCOUNT
      # echo "SIGNER_ADDRESS" $SIGNER_ADDRESS
      sed -i.bak "s/\"extraData\": \"0x\"/\"extraData\": \"0x0000000000000000000000000000000000000000000000000000000000000000$(echo $ACCOUNT | cut -c 3- | tr -d '\n')0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000\"/" ../blockchain-$CHAIN_ID/genesis.json
      sed -i.bak 's/"alloc": {/"alloc": {\n\ \ \ \ '\""$(echo $ACCOUNT | cut -c 3-)"\"': { "balance": "1000000000000000000000000" }\n\t/' ../blockchain-$CHAIN_ID/genesis.json
    else
      sed -i.bak 's/"alloc": {/"alloc": {\n\ \ \ \ '\""$(echo $ACCOUNT | cut -c 3-)"\"': { "balance": "1000000000000000000000000" },/' ../blockchain-$CHAIN_ID/genesis.json
    fi 
done

# Numero aleatorio entre 10 y 255 para las ips
IP_ALEATORIA_BOOTNODE=$((RANDOM % 246 + 10))
IP_ALEATORIA_RPC=$((RANDOM % 246 + 10))
IP_ALEATORIA_MINERO=$((RANDOM % 246 + 10))
RANGO_IP_ALEATORIO=$((RANDOM % 246 + 10))

# Numero aleatorio entre 8545 y 9500 para el puerto del nodo rpc
PUERTO_RPC=$((RANDOM % (9500 - 8545 + 1) + 8545))

# Generar el bootnode
bootnode --genkey=../blockchain-$CHAIN_ID/bootnode.key
BOOTNODE_KEY=$(cat ../blockchain-$CHAIN_ID/bootnode.key)
# echo "BOOTNODE_KEY" $BOOTNODE_KEY

bootnode --writeaddress --addr 172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_BOOTNODE:30305 --netrestrict="172.16.$RANGO_IP_ALEATORIO.0/24" --nodekey=../blockchain-$CHAIN_ID/bootnode.key > ../blockchain-$CHAIN_ID/bootnode.enode

# Agregar el enode del bootnode al archivo genesis.json
BOOTNODE_ENODE=$(cat ../blockchain-$CHAIN_ID/bootnode.enode)
echo "enode://$BOOTNODE_ENODE@172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_BOOTNODE:0?discport=30305" > ../blockchain-$CHAIN_ID/enode.txt
ENODE=$(cat ../blockchain-$CHAIN_ID/enode.txt)
# echo "ENODE" $ENODE

# Crear la configuración inicial del docker-compose
cat > ../blockchain-$CHAIN_ID/docker-compose.yaml <<EOF
version: '3.7'

services:
  geth-bootnode:
    hostname: geth-bootnode
    image: ethereum/client-go:alltools-latest
    volumes:
      - ./bootnode.key:/root/.ethereum/bootnode.key
      - ./genesis.json:/root/genesis.json
    entrypoint: sh -c 'geth init 
      /root/genesis.json && geth  
      --nodekeyhex="$BOOTNODE_KEY"
      --networkid=$CHAIN_ID
      --netrestrict="172.16.$RANGO_IP_ALEATORIO.0/24"
      --port=30305'
    networks:
      priv-eth-net-$CHAIN_ID:
        ipv4_address: 172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_BOOTNODE

  geth-rpc-endpoint:
    hostname: geth-rpc-endpoint
    image: ethereum/client-go:alltools-latest
    volumes:
      - ./genesis.json:/root/genesis.json
    depends_on:
      - geth-bootnode
    networks:
      priv-eth-net-$CHAIN_ID:
        ipv4_address: 172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_RPC
    ports:
      - "$PUERTO_RPC:8545"
    entrypoint: sh -c 'geth init 
      /root/genesis.json && geth     
      --netrestrict="172.16.$RANGO_IP_ALEATORIO.0/24"    
      --bootnodes="$ENODE"
      --nat "extip:172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_RPC"
      --networkid=$CHAIN_ID
      --http 
      --http.addr "0.0.0.0" 
      --http.port 8545 
      --http.corsdomain "*" 
      --http.api "admin,clique,eth,debug,miner,net,txpool,personal,web3"'

  geth-miner:
    hostname: geth-miner
    image: ethereum/client-go:alltools-latest
    volumes:
      - ./genesis.json:/root/genesis.json
      - ./pwd.txt:/root/.ethereum/pwd.sec
      - ./keystore:/root/.ethereum/keystore
    depends_on:
      - geth-bootnode
    networks:
      priv-eth-net-$CHAIN_ID:
        ipv4_address: 172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_MINERO
    entrypoint: sh -c 'geth init 
      /root/genesis.json && geth   
      --nat "extip:172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_MINERO"
      --netrestrict="172.16.$RANGO_IP_ALEATORIO.0/24"
      --bootnodes="$ENODE"
      --miner.etherbase $SIGNER_ADDRESS   
      --mine  
      --unlock $SIGNER_ADDRESS
      --password /root/.ethereum/pwd.sec'
EOF

# Añadir los nodos al docker compose
for i in $(seq 1 $NUM_NODOS); do  #for ((i=1; i<=$NUM_NODOS; i++)); do

  # Numero aleatorio entre 10 y 255 para las ips
  IP_ALEATORIA_NODO=$((RANDOM % 246 + 10))

  cat >> ../blockchain-$CHAIN_ID/docker-compose.yaml <<EOF
  nodo-$i:
    hostname: nodo-$i
    image: ethereum/client-go:alltools-latest
    volumes:
      - ./genesis.json:/root/genesis.json
    depends_on:
      - geth-bootnode
    networks:
      priv-eth-net-$CHAIN_ID:
        ipv4_address: 172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_NODO
    entrypoint: sh -c 'geth init
      /root/genesis.json && geth
      --bootnodes="$ENODE"
      --netrestrict="172.16.$RANGO_IP_ALEATORIO.0/24"
      --nat "extip:172.16.$RANGO_IP_ALEATORIO.$IP_ALEATORIA_NODO"'
EOF
done

cat >> ../blockchain-$CHAIN_ID/docker-compose.yaml <<EOF
networks:
  priv-eth-net-$CHAIN_ID:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: 172.16.$RANGO_IP_ALEATORIO.0/24
      
EOF

# Borrar la red si ya existe para crearla de nuevo
NOMBRE_DE_RED="blockchain-${CHAIN_ID}_priv-eth-net-${CHAIN_ID}"

./borrar_red.sh $NOMBRE_DE_RED

# Listar las redes
# ./listar_redes.sh

# Lanzar la red
cd ../blockchain-$CHAIN_ID
docker-compose up

echo "Red de Ethereum creada con éxito"
