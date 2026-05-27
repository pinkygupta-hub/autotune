FROM quay.io/fedora/python-311:latest

WORKDIR /opt/app-root/src

# Install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py ./
RUN echo '--- IMAGE APP.PY ---' && sed -n '1,120p' ./app.py

# Expose port
EXPOSE 8080

# Run with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "120", "app:app"]

# Made with Bob
