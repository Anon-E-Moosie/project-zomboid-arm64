# ==== STAGE 1: BUILDER ====
FROM arm64v8/ubuntu:25.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install builder dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    ninja-build \
    pkg-config \
    ccache \
    clang \
    llvm \
    lld \
    python3 python3-setuptools \
    squashfs-tools squashfuse \
    qt6-base-dev qt6-declarative-dev \
    libc-bin \
    nasm \
    curl \
    sudo \
    fuse3 \
    wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/fex
RUN git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git && \
    cd FEX && \
    git checkout 376d6ba72 && \
    git submodule sync --recursive && \
    git submodule update --init --recursive && \
    mkdir Build && cd Build && \
    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_LINKER=lld \
    -DENABLE_LTO=True \
    -DBUILD_TESTS=False -G Ninja .. && \
    ninja install && \
    ls -lah /usr/bin/FEX*


# === STAGE 2: RUNNER ===
FROM arm64v8/ubuntu:25.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libsdl3-0 \
    libssl3t64 \
    squashfuse \
    libc-bin \
    curl \
    sudo \
    wget \
    vim \
    nano \
    tmux \
    binfmt-support && \
    rm -rf /var/lib/apt/lists/*

# Copy the finished FEX binaries from the builder
COPY --from=builder /usr/bin/ /usr/bin/

RUN ls -lah /usr/bin | grep -i fex || true

# Set up the steam user
RUN useradd -m -s /bin/bash steam && \
    echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/steam

USER steam
WORKDIR /home/steam

# Setup RootFS
RUN mkdir -p /home/steam/.fex-emu/RootFS/Ubuntu_25_04 /home/steam/Steam /home/steam/pz-server && \
    wget -O /tmp/Ubuntu_25_04.tar.gz "https://www.dropbox.com/scl/fi/na3t1pwu1f8hwemtescjd/Ubuntu_25_04.tar.gz?rlkey=vhnm1jeuh09z6406lptn5izrx&st=eo4w8s9q&dl=1" && \
    tar xpzf /tmp/Ubuntu_25_04.tar.gz -C /home/steam/.fex-emu/RootFS/Ubuntu_25_04/ && \
    rm /tmp/Ubuntu_25_04.tar.gz && \
    sudo cp /etc/resolv.conf /home/steam/.fex-emu/RootFS/Ubuntu_25_04/etc/resolv.conf && \
    echo '{"Config":{"RootFS":"Ubuntu_25_04"}}' > /home/steam/.fex-emu/Config.json && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam/Steam && \
    sed -i '/ulimit -n/d' /home/steam/Steam/steamcmd.sh

RUN find /usr/bin -iname '*fex*' | sort && false

    # Prime SteamCMD
#RUN FEX /home/steam/Steam/steamcmd.sh +login anonymous +quit

# Install Project Zomboid
RUN FEX /home/steam/Steam/steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir /home/steam/pz-server/ \
    +login anonymous \
    +app_update 380870 validate \
    +quit && \
    rm -rf /home/steam/Steam/logs /home/steam/Steam/appcache

# === APPLY OUR CRASH FIXES AUTOMATICALLY ===
# 1. Swap -XX:+UseZGC to -XX:+UseG1GC to stop FEX emulation crashes
RUN sed -i 's/-XX:+UseZGC/-XX:+UseG1GC/g' /home/steam/pz-server/ProjectZomboid64.json

# 2. Update memory allocation to 4GB min / 12GB max
RUN sed -i 's/-Xms[0-9]*[gG]/-Xms4g/g' /home/steam/pz-server/ProjectZomboid64.json && \
    sed -i 's/-Xmx[0-9]*[gG]/-Xmx12g/g' /home/steam/pz-server/ProjectZomboid64.json
# 2b. Store JVM crash logs in persistent storage
#RUN sed -i '/-XX:-OmitStackTraceInFastThrow/a\ "-XX:ErrorFile=/home/steam/Zomboid/Logs/hs_err_pid%p.log",' \
#/home/steam/pz-server/ProjectZomboid64.json

# 3. Patch start-server.sh for ARM64/FEX
RUN sed -i 's|if "${INSTDIR}/jre64/bin/java"|if FEX "${INSTDIR}/jre64/bin/java"|' \
/home/steam/pz-server/start-server.sh && \
sed -i 's|export PATH="${INSTDIR}/jre64/bin:$PATH"|export PATH="${INSTDIR}/jre64/bin:$PATH"|' \
/home/steam/pz-server/start-server.sh && \
sed -i 's|LD_PRELOAD="${LD_PRELOAD}:${JSIG}" ./ProjectZomboid64 "$@"|LD_PRELOAD="${LD_PRELOAD}:${JSIG}" FEX ./ProjectZomboid64 "$@"|' \
/home/steam/pz-server/start-server.sh

EXPOSE 16261/udp 16262/udp 27015/tcp

ENV PATH="/home/steam/pz-server/jre64/bin:${PATH}"

ENV LD_LIBRARY_PATH="/home/steam/pz-server/linux64:/home/steam/pz-server:/home/steam/pz-server/jre64/lib/amd64"

WORKDIR /home/steam/pz-server

ENTRYPOINT [ "/bin/bash" ]
