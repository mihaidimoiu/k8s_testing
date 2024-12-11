FROM mongo:latest

# Install required tools and MongoDB repo
RUN apt-get update && \
    apt-get install -y gnupg curl && \
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" > /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    apt-get update && \
    apt-get install -y mongodb-org-tools mongodb-mongosh&& \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify mongo-tools installation
RUN mongoexport --version
RUN mongosh --version
