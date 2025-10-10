FROM ubuntu:22.04

# Installer curl, unzip et libicu (version 70 sur Jammy)
RUN apt-get update && apt-get install -y curl unzip libicu70 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Télécharger et extraire FastTransfer
RUN curl -L -o FastTransfer.zip "https://aetpshared.s3.eu-west-1.amazonaws.com/FastTransfer/trial/FastTransfer-linux-x64.zip" \
    && unzip FastTransfer.zip \
    && rm FastTransfer.zip

RUN chmod +x ./FastTransfer

ENTRYPOINT ["./FastTransfer"]
