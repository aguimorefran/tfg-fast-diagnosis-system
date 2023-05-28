FROM python:3.8-slim

WORKDIR /app

COPY app/requirements.txt ./
COPY ./entrypoint.sh ./
RUN pip install --no-cache-dir -r requirements.txt

# Instalar cqlsh
RUN apt-get update && apt-get install -y curl
RUN curl https://bootstrap.pypa.io/get-pip.py | python
RUN pip install cqlsh

COPY app/ ./

RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
