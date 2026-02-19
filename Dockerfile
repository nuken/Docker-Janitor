FROM python:3.9-slim
RUN pip install flask docker
WORKDIR /app
COPY app.py .
CMD ["python", "app.py"]
