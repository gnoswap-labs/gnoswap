FROM python:3.11-slim

RUN pip install uv

WORKDIR /app

COPY requirements.txt .

# install dependencies
RUN uv venv && \
    . .venv/bin/activate && \
    uv pip install -r requirements.txt

COPY . .

CMD ["python3", "setup.py"] 