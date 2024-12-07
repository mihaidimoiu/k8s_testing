# Dockerfile for Flask app with MongoDB support
FROM python:latest

RUN apt-get update && apt-get install -y iputils-ping curl dnsutils

# Set the working directory in the container
WORKDIR /app

# Copy the application code into the container
COPY src /app/web_server

# Install dependencies
RUN pip install -r /app/web_server/requirements.txt

# Expose the port for internal communication (optional)
EXPOSE 5000

# Set the command to run the Flask app
CMD ["python", "web_server/app.py"]
