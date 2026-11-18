FROM python:3.13-slim
WORKDIR /srv
RUN pip install --no-cache-dir gunicorn==27.0.1
COPY server.py .
USER 65532:65532
ENTRYPOINT ["gunicorn","--bind=0.0.0.0:8000","--workers=2","--no-control-socket","--worker-tmp-dir=/tmp","--timeout=20","--limit-request-line=2048","--limit-request-fields=32","server:application"]
