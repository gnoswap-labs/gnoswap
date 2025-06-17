FROM python:3.11-slim

# Create a non-root user
RUN groupadd -r appuser && useradd -r -g appuser -m appuser

RUN pip install uv

WORKDIR /app

COPY requirements.txt .

# install dependencies
RUN uv venv && \
    . .venv/bin/activate && \
    uv pip install -r requirements.txt

# Copy only necessary files
COPY setup.py .
COPY scripts/ scripts/
COPY contract/ contract/
COPY mapping.yml .

# Change ownership of the application files
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

CMD ["python3", "setup.py"] 