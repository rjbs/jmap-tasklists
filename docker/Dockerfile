FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y ruby ruby-dev build-essential && \
    gem install kramdown-rfc && \
    pip install --no-cache-dir xml2rfc && \
    apt-get purge -y build-essential && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
