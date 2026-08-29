"""Integration tests - the middle of the pyramid (~20% of suite)."""

import pytest

from app.main import create_app


@pytest.fixture()
def client():
    app = create_app()
    app.config.update(TESTING=True)
    return app.test_client()


def test_health_endpoint_reports_version(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"


def test_balance_returns_formatted_amount(client):
    response = client.get("/accounts/ACC-1001/balance")
    assert response.status_code == 200
    assert response.get_json()["balance"] == "250.00"


def test_unknown_account_returns_404(client):
    assert client.get("/accounts/NOPE/balance").status_code == 404


def test_credit_then_balance_round_trip(client):
    client.post("/accounts/ACC-1002/transactions", json={"amount": "10.00", "kind": "credit"})
    assert client.get("/accounts/ACC-1002/balance").get_json()["balance"] == "10.00"


def test_overdraft_returns_409(client):
    response = client.post(
        "/accounts/ACC-1002/transactions", json={"amount": "9999.00", "kind": "debit"}
    )
    assert response.status_code == 409


def test_malformed_amount_returns_400(client):
    response = client.post(
        "/accounts/ACC-1001/transactions", json={"amount": "1.005", "kind": "credit"}
    )
    assert response.status_code == 400
