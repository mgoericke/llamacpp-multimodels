# PoC: Llama.cpp Multi Model Server with Kong API Gateway

All scripts created with Claude Code ❤️

* On first start - checks and installs everything automatically
  
This command starts all llama servers and performs automatic checks and installation if needed.
```
./start-llama-servers.sh start
```

* Manual installation of llama.cpp
  
Run this to install the llama.cpp dependencies and build steps.
```
./start-llama-servers.sh install
```

* Check status
  
Shows the current status of the running llama servers.
```
./start-llama-servers.sh status
```

* Show logs
  
Displays the logs produced by the start script.
```
./start-llama-servers.sh logs
```


# 2. Start Kong
  
Starts db-less Kong Api Gateway in detached mode using Docker Compose. Mounts a kong.yml with the pre-defined services and routes

```shell
docker-compose up -d
```

`docker-compose-full.yaml` will start a full Kong API Gateway Server with database, kong migrations and admin ui. 
Requires manual setup of services and routes 

# 3. View logs
  
Follows the Kong container logs so you can watch startup and runtime output.

```shell
docker-compose logs -f kong
```

# 4. Testing
## Completions
  
Send a chat completion request to the local completions endpoint to test model responses.
```shell
curl http://localhost:9001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen",
    "messages": [{"role": "user", "content": "Hallo!"}]
  }'
```

## Embeddings
  
Quick test call to the embeddings endpoint to verify embedding generation.
```shell
# Einfacher Test
curl http://localhost:8034/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "input": "Das ist ein Test",
    "model": "nomic-embed-text"
  }'
```

## Demo Service

Start the demo-service.

```shell script
cd demo-agent
./mvnw quarkus:dev
```
  
Sends a simple request to the demo service endpoint to exercise the demo API.
```shell
# Einfacher Test
curl http://localhost:8080/hello \
  -H "Content-Type: application/json" \
  -d 'Hey, denk dir ein paar spaßige Motivationssprüche aus'
```