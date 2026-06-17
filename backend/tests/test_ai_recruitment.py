import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200


def test_cv_screening():
    payload = {
        "job_description": "We are looking for a Flutter Developer with 2 years of experience.",
        "cv_text": "Nguyen Van A. Experience: 2 years of experience in Flutter development."
    }
    response = client.post("/api/v1/cv/screen", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "score" in data
    assert "result" in data
    assert data["result"] in ["pass", "review", "fail"]
    assert "strengths" in data
    assert "weaknesses" in data
    assert "reason" in data


def test_interview_flow():
    # 1. Start interview
    start_payload = {
        "job_title": "Flutter Developer",
        "job_description": "Flutter mobile developer",
        "cv_text": "Nguyen Van A - Junior Flutter Dev",
        "custom_questions": ["Bạn có kinh nghiệm với Riverpod không?"]
    }
    start_response = client.post("/api/v1/interview/start", json=start_payload)
    assert start_response.status_code == 200
    start_data = start_response.json()
    assert "session_id" in start_data
    assert "question" in start_data
    
    session_id = start_data["session_id"]
    assert len(session_id) > 0

    # 2. Respond to questions
    # AI service mock mode has len(mock_questions) = 5 questions (3 default + 1 custom + 1 final)
    # We will loop sending answers until finished = True
    finished = False
    question = start_data["question"]
    attempts = 0
    
    while not finished and attempts < 10:
        respond_payload = {
            "session_id": session_id,
            "answer": f"This is my test answer for question {attempts + 1}"
        }
        respond_response = client.post("/api/v1/interview/respond", json=respond_payload)
        assert respond_response.status_code == 200
        respond_data = respond_response.json()
        
        finished = respond_data["finished"]
        if not finished:
            assert "question" in respond_data
            assert respond_data["question"] is not None
            question = respond_data["question"]
        else:
            assert "report" in respond_data
            report = respond_data["report"]
            assert report is not None
            assert "total_score" in report
            assert "strengths" in report
            assert "weaknesses" in report
            assert "recommend_to_employer" in report
            assert "reason" in report
            
        attempts += 1

    assert finished is True
    assert attempts == 4 or attempts == 5


def test_non_cv_screening():
    payload = {
        "job_description": "We are looking for a Flutter Developer with 2 years of experience.",
        "cv_text": "Lab Assignment 3: Setup OSPF routing protocol on Cisco routers. Objective: configure loopback interface, run network commands, verify neighbor adjacency."
    }
    response = client.post("/api/v1/cv/screen", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["score"] == 0
    assert data["result"] == "fail"
    assert len(data["weaknesses"]) > 0
    assert "reason" in data

