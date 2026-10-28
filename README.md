# project-zomboid-docker-arm64

This repository provides an automated Docker image for running a Project Zomboid Dedicated Server on ARM64 architecture (such as Oracle Cloud ARM VPS) using FEX-Emu emulation and SteamCMD.

Unlike upstream images, this fork automatically bakes in necessary ARM64 compatibility patches during the build process, preventing JVM crashes out of the box.

**Note**: Tested on Oracle Cloud VM.Standard.A1.Flex (4 OCPU / 24GB RAM). Performance on other ARM64 hosts may vary.

**Note**: Currently issues with stability, FEX emulation may sometimes crash during server start-up or gameplay.

---

## Pre-baked ARM64 Enhancements

- **Automatic FEX Execution:** Modifies `start-server.sh` to execute the x86_64 server binary via FEX-Emu automatically.
- **JVM Crash Prevention:** Automatically replaces the default `-XX:+UseZGC` engine with `-XX:+UseG1GC` in `ProjectZomboid64.json` to prevent emulation crashes.
- **Pre-configured Memory Bounds:** Sets default heap memory bounds (`-Xms4g`, `-Xmx12g`).
  - to-do, make above configurable during build to accomodate custom memory bounds

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
## Volume & Mount Information
``` 
/home/steam
├── pz-server/            <-- Game install (disposable)
│   ├── ProjectZomboid64
│   ├── start-server.sh
│   ├── java/
│   ├── jre64/
│   ├── linux64/
│   └── media/
│
└── Zomboid/              <-- Mounted persistent data
    ├── backups/
    ├── Crafting/
    ├── db/
    ├── Lua/
    ├── Logs/
    ├── mods/
    ├── Saves/
    ├── Server/
    ├── Workshop/
    ├── Recording/
    ├── backups/
    ├── options.ini
    ├── server-console.txt
    └── ItemTracker.log
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
  -v Path/To/Zomboid/Data:/home/steam/Zomboid \
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

## Starting the Server

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

If you get a 'Only 64bit is supported' error, run the following instead:
```bash
cd /home/steam/pz-server

export PATH="/home/steam/pz-server/jre64/bin:$PATH"

export LD_LIBRARY_PATH="/home/steam/pz-server/linux64:/home/steam/pz-server:/home/steam/pz-server/jre64/lib/amd64"

FEX ./ProjectZomboid64
```

FEX Emulation on server start-up is finnicky and slow, if you get a JAVA crash during start-up, run either of the above commands to try again.  
Server start-up can take up to 5 or more minutes on an Oracle VPS with 4 OCPU and 24GB RAM. This may take longer with mods installed.


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

### 4. Viewing live logs
If you exit the termnial session and would like to view live server logs again, enter the Container terminal and run:
```bash
tail -f /home/steam/Zomboid/server-console.txt
```
---
## Managing the server
### 1. Restarting the server
If the server requires a reboot, often required if installed mods or the game itself needs an update, restart the docker container and run the start script again:
```bash
docker exec -it zomboid-server bash
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

### 4. Viewing live logs
If you exit the termnial session and would like to view live server logs again, enter the Container terminal and run:
```bash
tail -f /home/steam/Zomboid/server-console.txt
```

## To-do
- Add server customisation options during build (server name, password, max players etc)
- Include restart and shutdown options
- Automatic server reboots if mod update is detected while server is idle


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
