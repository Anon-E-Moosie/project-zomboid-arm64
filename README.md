# project-zomboid-docker-arm64
## Currently not working

~~This repository provides an automated Docker image for running a Project Zomboid Dedicated Server on ARM64 architecture (such as Oracle Cloud ARM VPS) using FEX-Emu emulation and SteamCMD.~~

~~Unlike upstream images, this fork automatically bakes in necessary ARM64 compatibility patches during the build process, preventing JVM crashes out of the box.~~

~~**Note**: Tested on Oracle Cloud VM.Standard.A1.Flex (4 OCPU / 24GB RAM). Performance on other ARM64 hosts may vary.~~

---

## Pre-baked ARM64 Enhancements

- **Automatic FEX Execution:** Modifies `start-server.sh` to execute the x86_64 server binary via FEX-Emu automatically.
- **JVM Crash Prevention:** Automatically replaces the default `-XX:+UseZGC` engine with `-XX:+UseG1GC` in `ProjectZomboid64.json` to prevent emulation crashes.
- **Pre-configured Memory Bounds:** Sets default heap memory bounds (`-Xms4g`, `-Xmx12g`).

---

## Prerequisites

- ARM64 environment (e.g., Ubuntu 22.04 / 24.04 / 25.04 on Oracle Cloud Ampere A1).
- Docker and Docker Compose installed.
- Required open ports on host/firewall:
  - `16261/UDP` (Game Port)
  - `16262/UDP` (Direct Join Port)
  - `27015/TCP` (SteamCMD)

---

## Installation & Build

### 1. Clone the Repository
```bash
git clone https://github.com/Anon-E-Moosie/project-zomboid-docker-arm64.git
cd project-zomboid-docker-arm64
```

### 2. Build the Docker Image
```bash
docker build -t zomboid-arm64:latest .
```

---

## Running the Server

### Option A: Via Docker Run (With Persistent Volumes)

To ensure game saves, server configs, and workshop items survive container updates or recreations, bind a host folder to `/home/steam/Zomboid`. The game installation remains separately within the container at `/home/steam/pz-server`

```bash
docker run -it -d \
  --name zomboid-server \
  -p 16261:16261/udp \
  -p 16262:16262/udp \
  -p 27015:27015/tcp \
  -v /Zomboid:/home/steam/Zomboid \
  zomboid-arm64:latest
```

### Option B: Via Docker Compose

Create a `docker-compose.yml` file in your server directory:

```yaml
version: "3.8"

services:
  zomboid-server:
    build: .
    container_name: zomboid-server
    restart: unless-stopped
    ports:
      - "16261:16261/udp"
      - "16262:16262/udp"
      - "27015:27015/tcp"
    volumes:
      - /Zomboid:/home/steam/Zomboid
    tty: true
    stdin_open: true
```

Launch with:
```bash
docker compose up -d
```

---

## Starting & Managing the Server

### 1. Launching the Server
Access the container interactive shell:
```bash
docker exec -it zomboid-server bash
```

The Project Zomboid server files are installed to:  
 `/home/steam/pz-server`  
 
 Persistent save data, configuration files, logs, and databases are stored in:  
 `/home/steam/Zomboid`  
 
 After entering the container, you should already be in `/home/steam/pz-server`.  

Run the pre-configured start script:
```bash
./start-server.sh
```

### 2. Detaching Safely
To disconnect from an attached container without shutting down the server process, press:
```text
Ctrl + P, followed by Ctrl + Q
```

### 3. Fixing Hung Attach Sessions
If your terminal session gets stuck while attached to the container, kill the client attachment process safely from a separate host terminal:
```bash
pkill -f "docker attach zomboid-server"
```

---

## Useful References

- [SteamCMD Documentation](https://developer.valvesoftware.com/wiki/SteamCMD)
- [FEX-Emu Documentation](https://fex-emu.com/)
- [Docker Documentation](https://docs.docker.com/)

---

##  Credits & Acknowledgments

* **Original Base Projects:**
  * [TeriyakiGod/steamcmd-docker-arm64](https://github.com/TeriyakiGod/steamcmd-docker-arm64)
  * [EthanHand/project-zomboid-docker-arm64](https://github.com/EthanHand/project-zomboid-docker-arm64)
* **Development Note:** ARM64 compatibility patches and Dockerfile optimizations for this fork were developed with the assistance of AI.
