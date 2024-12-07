import os
import sys
from flask import Flask, jsonify
from pymongo import MongoClient, errors

app = Flask(__name__)
use_local = True
db = None
pod_name = None

# MongoDB connection setup
def login():
    global use_local
    global db
    global pod_name
    
    pod_name = os.getenv("POD_NAME", "unknown")
    user = os.getenv("DB_USERNAME", None)
    pwd = os.getenv("DB_PASSWORD", None)
    db_url = os.getenv("DB_URL", None)
    db_port = os.getenv("DB_PORT", None)
    
    if db_url and db_port:
        if user and pwd:
            mongo_uri = f"mongodb://{user}:{pwd}@{db_url}:{db_port}/app_db"
        else:
            mongo_uri = f"mongodb://{db_url}:{db_port}/app_db"
    else:
        print(f"Invalid URL: {db_url} and Port: {db_port}")
        sys.exit(1)

    try:
        print(f"Trying to connect to: {mongo_uri}")
        client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
        db = client.get_database()
        client.admin.command('ping')
        use_local = False
        print("Connected to MongoDB successfully!")
    except errors.ServerSelectionTimeoutError as e:
        print(f"MongoDB connection error: {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")
        

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
