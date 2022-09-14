FROM python:3.7-slim as python

WORKDIR /app


RUN apt-get update
RUN apt-get install curl -y

COPY ./requirements.txt /app/requirements.txt
COPY /packages /app/packages
RUN pip install -r /app/requirements.txt

COPY . /app/