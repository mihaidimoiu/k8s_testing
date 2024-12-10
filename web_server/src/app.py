import os
import sys
import time
from flask import Flask, jsonify
from pymongo import MongoClient, errors

app = Flask(__name__)
use_local = True
db = None
pod_name = None


# MongoDB connection setup
def connect_to_mongo(mongo_uri, retries=5, delay=5):
    for i in range(retries):
        try:
            print(f"Trying to connect to: {mongo_uri}")
            client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
            client.admin.command('ping')  # Test the connection
            print("Connected to MongoDB successfully!")
            return client.get_database()
        except errors.ServerSelectionTimeoutError as e:
            print(f"MongoDB connection error: {e}, retrying in {delay}s...")
            time.sleep(delay)
    # If we reach here, all retries failed
    print("Could not connect to MongoDB after multiple retries.")
    return None


def login():
    global use_local, db, pod_name
    pod_name = os.getenv("POD_NAME", "unknown")
    user = os.getenv("DB_USERNAME", None)
    pwd = os.getenv("DB_PASSWORD", None)
    db_url = os.getenv("DB_URL", None)
    db_port = os.getenv("DB_PORT", None)

    if not db_url or not db_port:
        print(f"Invalid URL: {db_url} and Port: {db_port}")
        sys.exit(1)

    if user and pwd:
        mongo_uri = f"mongodb://{user}:{pwd}@{db_url}:{db_port}/app_db"
    else:
        mongo_uri = f"mongodb://{db_url}:{db_port}/app_db"

    db_instance = connect_to_mongo(mongo_uri)
    if db_instance is not None:
        db = db_instance
        use_local = False
    else:
        use_local = True


# Local counter fallback
local_count = 0

@app.route('/')
def hello():
    global local_count
    
    if not use_local:
        # Update the count in MongoDB
        record = db.visits.find_one({"_id": "counter"}) or {"_id": "counter", "count": 0}
        record["count"] += 1
        db.visits.update_one({"_id": "counter"}, {"$set": record}, upsert=True)
        global pod_name

        return f'Hello World! I have been seen {record["count"]} times. Pod name: {pod_name}.\n'
    else:
        # Fallback to local counter
        local_count += 1
        return f'Hello World! I have been seen {local_count} times (local fallback).\n'

@app.route('/status')
def status():
    if not use_local:
        # Check the database connection
        try:
            db.command("ping")
            return jsonify({"status": "ok", "database": "connected", "pod_name": pod_name})
        except Exception as e:
            return jsonify({"status": "error", "database": str(e), "pod_name": pod_name}), 500
    else:
        return jsonify({"status": "ok", "database": "local fallback"}), 200

if __name__ == '__main__':
    login()
    port = int(os.getenv("PORT", 8000))
    app.run(host='0.0.0.0', port=port)
