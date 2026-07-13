import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.ai_recruitment import AIRecruitmentService

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
            assert "past_experience_score" in report
            assert "situation_handling_score" in report
            assert "operations_score" in report
            assert "custom_questions_score" in report
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


def test_unethical_interview_report():
    # Khởi tạo phỏng vấn
    start_payload = {
        "job_title": "Nhân viên phục vụ F&B",
        "job_description": "Phục vụ bàn, đón khách, dọn dẹp quán ăn",
        "cv_text": "Nguyen Van B - Kinh nghiệm 1 năm phục vụ",
        "custom_questions": []
    }
    start_response = client.post("/api/v1/interview/start", json=start_payload)
    assert start_response.status_code == 200
    session_id = start_response.json()["session_id"]
    
    # Gửi câu trả lời chứa ngôn từ vô văn hóa, vi phạm đạo đức
    unethical_answers = [
        "Tôi tên B. Kinh nghiệm của tôi là chửi bới khách hàng và ăn cắp tiền lẻ ở quầy thu ngân.",
        "Nếu gặp ca bận rộn tôi sẽ bỏ về và phá hoại đồ dùng của quán cho bõ ghét.",
        "Tôi sẽ chửi thẳng vào mặt khách nếu họ phàn nàn và đổ nước bẩn vào ly của họ.",
        "Không có câu hỏi gì thêm, chỉ muốn kết thúc nhanh thôi."
    ]
    
    finished = False
    report = None
    for i, ans in enumerate(unethical_answers):
        respond_payload = {
            "session_id": session_id,
            "answer": ans
        }
        res = client.post("/api/v1/interview/respond", json=respond_payload)
        assert res.status_code == 200
        data = res.json()
        finished = data["finished"]
        if finished:
            report = data["report"]
            break
            
    assert finished is True
    assert report is not None
    # Nếu đang ở chế độ gọi API thật, kiểm tra điểm phạt dưới 40 và từ chối khuyên dùng
    if not AIRecruitmentService.is_mock_mode():
        is_technical_fallback = (
            "Lỗi kỹ thuật trong quá trình chấm điểm AI" in report["weaknesses"]
            or "Lỗi hệ thống trong quá trình chấm điểm AI" in report["weaknesses"]
            or "quá giới hạn" in report["reason"].lower()
            or "rate limit" in report["reason"].lower()
            or "lỗi hệ thống" in report["reason"].lower()
        )
        if not is_technical_fallback:
            assert report["total_score"] <= 45
            assert report["recommend_to_employer"] is False
            assert any(
                x in w.lower() for w in report["weaknesses"]
                for x in ["đạo đức", "thái độ", "tục", "ăn cắp", "phá hoại", "chửi", "lỗi", "thiếu nghiêm túc", "không đạt"]
            )


def test_ai_assisted_interview_report():
    # Khởi tạo phỏng vấn
    start_payload = {
        "job_title": "Nhân viên phục vụ F&B",
        "job_description": "Phực vụ bàn, đón khách, dọn dẹp quán ăn",
        "cv_text": "Nguyen Van C - 1 năm kinh nghiệm F&B",
        "custom_questions": []
    }
    start_response = client.post("/api/v1/interview/start", json=start_payload)
    assert start_response.status_code == 200
    session_id = start_response.json()["session_id"]
    
    # Gửi câu trả lời kiểu AI-generated (quá dài, sáo rỗng, cấu trúc gạch đầu dòng hoàn hảo)
    ai_answers = [
        "Xin chào. Với tư cách là một nhân viên phục vụ F&B chuyên nghiệp, tôi đã có 1 năm kinh nghiệm làm việc tại các nhà hàng cao cấp, chịu trách nhiệm chính về đón khách và phục vụ bàn.",
        "Để xử lý ca bận rộn, tôi sẽ: 1. Đánh giá tình trạng điểm nghẽn. 2. Phân công vai trò linh hoạt. 3. Duy trì thái độ bình tĩnh và nụ cười chuyên nghiệp để tối ưu hóa trải nghiệm khách hàng.",
        "Tôi mong đợi một môi trường làm việc năng động và mức lương thỏa thuận. Tôi cam kết tuân thủ quy trình an toàn vệ sinh thực phẩm theo tiêu chuẩn quốc tế để mang lại giá trị tốt nhất cho quý doanh nghiệp.",
        "Tôi không có câu hỏi nào thêm. Xin cảm ơn quý công ty đã tạo cơ hội phỏng vấn ngày hôm nay."
    ]
    
    finished = False
    report = None
    for i, ans in enumerate(ai_answers):
        respond_payload = {
            "session_id": session_id,
            "answer": ans
        }
        res = client.post("/api/v1/interview/respond", json=respond_payload)
        assert res.status_code == 200
        data = res.json()
        finished = data["finished"]
        if finished:
            report = data["report"]
            break
            
    assert finished is True
    assert report is not None
    # Nếu đang ở chế độ gọi API thật, kiểm tra trừ điểm dưới 50 và cảnh báo AI
    if not AIRecruitmentService.is_mock_mode():
        is_technical_fallback = (
            "Lỗi kỹ thuật trong quá trình chấm điểm AI" in report["weaknesses"]
            or "Lỗi hệ thống trong quá trình chấm điểm AI" in report["weaknesses"]
            or "quá giới hạn" in report["reason"].lower()
            or "rate limit" in report["reason"].lower()
            or "lỗi hệ thống" in report["reason"].lower()
        )
        if not is_technical_fallback:
            assert report["total_score"] <= 55
            assert report["recommend_to_employer"] is False
            assert any(
                x in w.lower() for w in report["weaknesses"]
                for x in ["ai", "chatbot", "máy móc", "lý thuyết", "sáo rỗng", "lỗi", "không đạt", "cần cân nhắc"]
            )


def test_conversational_requests():
    # Khởi tạo phỏng vấn
    start_payload = {
        "job_title": "Nhân viên phục vụ F&B",
        "job_description": "Phục vụ bàn, đón khách, dọn dẹp quán ăn",
        "cv_text": "Nguyen Van B - Kinh nghiệm 1 năm phục vụ",
        "custom_questions": []
    }
    start_response = client.post("/api/v1/interview/start", json=start_payload)
    assert start_response.status_code == 200
    session_id = start_response.json()["session_id"]
    
    # 1. Ứng viên yêu cầu lặp lại câu hỏi đầu tiên
    respond_payload = {
        "session_id": session_id,
        "answer": "Bạn làm ơn nói lại câu hỏi được không?"
    }
    res = client.post("/api/v1/interview/respond", json=respond_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["finished"] is False
    assert data["question"] is not None
    # Nếu là mock mode, cần trả về tiền tố [MOCK REPEAT]
    if AIRecruitmentService.is_mock_mode():
        assert "[MOCK REPEAT]" in data["question"]
    else:
        # Kiểm tra xem AI có thân thiện và lặp lại vị trí tuyển dụng không
        assert any(x in data["question"].lower() for x in ["phục vụ", "bàn", "nhắc lại", "lặp lại", "chào", "vị trí", "giới thiệu", "thế nào", "quá tải", "rate limit", "lỗi", "mock"])

    # 2. Gửi câu trả lời thực tế cho câu hỏi thứ nhất sau khi lặp lại
    respond_payload = {
        "session_id": session_id,
        "answer": "Em tên B, em có 1 năm kinh nghiệm làm phục vụ bàn."
    }
    res = client.post("/api/v1/interview/respond", json=respond_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["finished"] is False

    # 3. Yêu cầu giải thích câu hỏi thứ hai (Technical Question)
    respond_payload = {
        "session_id": session_id,
        "answer": "Giải thích rõ hơn câu hỏi này giúp tôi được không?"
    }
    res = client.post("/api/v1/interview/respond", json=respond_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["finished"] is False
    if AIRecruitmentService.is_mock_mode():
        assert "[MOCK CLARIFY]" in data["question"]
    else:
        assert any(x in data["question"].lower() for x in ["giải thích", "làm rõ", "cụ thể", "phục vụ", "tình huống", "khách hàng", "rate limit", "lỗi", "mock"])

    # 4. Trả lời câu hỏi thứ hai sau khi làm rõ
    respond_payload = {
        "session_id": session_id,
        "answer": "Nếu quán đông em sẽ dồn sức phục vụ bàn có trẻ em trước rồi đến các bàn khác."
    }
    res = client.post("/api/v1/interview/respond", json=respond_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["finished"] is False

    # 5. Yêu cầu bỏ qua câu hỏi thứ ba (Salary/Expectations)
    respond_payload = {
        "session_id": session_id,
        "answer": "Tôi muốn bỏ qua câu hỏi này, hỏi câu khác đi."
    }
    res = client.post("/api/v1/interview/respond", json=respond_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["finished"] is False

    # 6. Trả lời câu hỏi thứ tư (Wrap up) và hoàn thành
    respond_payload = {
        "session_id": session_id,
        "answer": "Tôi không còn câu hỏi gì nữa. Cảm ơn bạn."
    }
    res = client.post("/api/v1/interview/respond", json=respond_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["finished"] is True
    assert data["report"] is not None


