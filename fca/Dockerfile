FROM r-base:latest

WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y \
    default-jdk \
    libcurl4-openssl-dev \
    libjpeg-dev \
    libsodium-dev \
    libudunits2-dev \
    libgdal-dev \
    proj-bin \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.r ./
RUN Rscript requirements.r

COPY . ./

EXPOSE 8005

CMD ["Rscript", "run_api.r"]
