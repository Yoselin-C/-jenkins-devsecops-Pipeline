from flask import Flask, request, jsonify
import os

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({"status": "ok", "message": "DevSecOps Demo App v1.0"})

@app.route("/health")
def health():
    return jsonify({"status": "healthy"})

@app.route("/api/users", methods=["GET"])
def get_users():
    users = [
        {"id": 1, "name": "Admin"},
        {"id": 2, "name": "User"}
    ]
    return jsonify(users)

@app.route("/api/echo", methods=["POST"])
def echo():
    data = request.get_json()
    return jsonify({"echo": data})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
