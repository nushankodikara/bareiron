
# Stage 1: Build the application
FROM debian:bullseye AS builder
ARG TARGETARCH

# Install necessary packages and Bun
RUN apt-get update && \
    apt-get install -y gcc curl unzip && \
    rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install OpenJDK 24
RUN JAVA_ARCH="" && \
    case ${TARGETARCH} in \
        amd64) JAVA_ARCH="x64" ;; \
        arm64) JAVA_ARCH="aarch64" ;; \
    esac && \
    curl -LO "https://download.java.net/java/GA/jdk24.0.2/fdc5d0102fe0414db21410ad5834341f/12/GPL/openjdk-24.0.2_linux-${JAVA_ARCH}_bin.tar.gz" && \
    tar -xzf "openjdk-24.0.2_linux-${JAVA_ARCH}_bin.tar.gz" && \
    rm "openjdk-24.0.2_linux-${JAVA_ARCH}_bin.tar.gz"

ENV PATH="/jdk-24.0.2/bin:${PATH}"

# Copy application source code
WORKDIR /app
COPY . .

# Dump Minecraft server registries
RUN mkdir notchian && \
    cd notchian && \
    curl -Lo server.jar https://piston-data.mojang.com/v1/objects/6bce4ef400e4efaa63a13d5e6f6b500be969ef81/server.jar && \
    echo "eula=true" > eula.txt && \
    java -DbundlerMainClass="net.minecraft.data.Main" -jar server.jar --all

# Generate registry headers
RUN bun run build_registries.js

# Build the application
RUN gcc src/*.c -O3 -Iinclude -o bareiron

# Stage 2: Create the final image
FROM gcr.io/distroless/cc-debian11
WORKDIR /app

# Copy the built application from the builder stage
COPY --from=builder /app/bareiron .
# COPY --from=builder /app/world.bin .
# Expose the port the server runs on (default is 25565)
EXPOSE 25565

# Command to run the application
CMD ["./bareiron"]
