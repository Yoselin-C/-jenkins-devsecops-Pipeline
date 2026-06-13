import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))
from app import app

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

def test_index(client):
    response = client.get("/")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"

def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "healthy"

def test_get_users(client):
    response = client.get("/api/users")
    assert response.status_code == 200
    users = response.get_json()
    assert isinstance(users, list)
    assert len(users) > 0

def test_echo(client):
    payload = {"message": "hello devsecops"}
    response = client.post("/api/echo", json=payload)
    assert response.status_code == 200
    data = response.get_json()
    assert data["echo"]["message"] == "hello devsecops"
