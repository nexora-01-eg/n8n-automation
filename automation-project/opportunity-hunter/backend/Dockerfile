FROM python:3.12-slim
WORKDIR /app
COPY backend ./backend
COPY tests ./tests
COPY dashboard ./dashboard
COPY database ./database
COPY config ./config
ENV OH_DB=/data/opps.db OH_PORT=8091 PYTHONUNBUFFERED=1
VOLUME ["/data"]
EXPOSE 8091
CMD ["python", "-m", "backend.api"]
