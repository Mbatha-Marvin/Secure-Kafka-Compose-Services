# Secure Kafka Cluster

---

## Overview

Simple podman compose setup for ssl secured dev kafka cluster



## Tools

- Podman and podman-compose

- Bitnami images

- Bash scripts



### How to Run

To get up and running you need to do the following:

1. rename the .example.env to .env and update the variables 
   
   ```bash
   mv .example.env .env
   ```

2. Make the scripts executable
   
   ```bash
   chmod +x start.sh scripts/jks-stores-gen.sh scripts/run_podman_compose.sh
   ```

3. run the start script to start the services
   
   ```bash
   ./start.sh
   ```



For more information on the Bitnami Kafka image see [containers/bitnami/kafka at main · bitnami/containers · GitHub](https://github.com/bitnami/containers/tree/main/bitnami/kafka)
