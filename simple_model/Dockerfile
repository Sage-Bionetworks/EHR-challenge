# docker build -t docker.synapse.org/syn4990358/simple_ehr_model .
FROM python:3.7

WORKDIR /app
COPY infer.sh infer.sh
COPY train.sh train.sh
COPY infer.py infer.py
COPY train.py train.py

