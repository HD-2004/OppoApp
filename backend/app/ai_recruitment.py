import os
import uuid
import logging
import io
import httpx
from typing import Optional, Tuple
# pyrefly: ignore [missing-import]
from pypdf import PdfReader
import google.generativeai as genai
from .models import (
    CVScreeningResponse,
    InterviewSessionStartRequest,
    InterviewSessionStartResponse,
    InterviewAnswerRequest,
    InterviewAnswerResponse,
    InterviewReport
)

logger = logging.getLogger("ai_recruitment")

# Biến lưu trữ session phỏng vấn trong bộ nhớ (In-memory store)
INTERVIEW_SESSIONS = {}

# Cấu hình API Key của Gemini nếu có
api_key = os.environ.get("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)
    logger.info("Gemini API key loaded successfully.")
else:
    logger.warning("GEMINI_API_KEY environment variable is not set. AI Recruitment will run in MOCK mode.")

MODEL_NAME = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

def get_fallback_models() -> list[str]:
    primary = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    fallbacks = [primary, "gemini-3.1-flash-lite", "gemini-1.5-flash-latest", "gemini-2.5-pro", "gemini-1.5-pro"]
    # Remove duplicates preserving order
    seen = set()
    return [x for x in fallbacks if not (x in seen or seen.add(x))]


def _get_turn_instruction(current_idx: int, turns: list[str]) -> str:
    if current_idx >= len(turns):
        return ""
    question = turns[current_idx]
    if question.startswith("Custom Question: "):
        q_text = question.replace("Custom Question: ", "")
        return f"""
[Chỉ đạo dành riêng cho lượt này của Người phỏng vấn]:
1. Hãy nhận xét ngắn gọn, tự nhiên về câu trả lời trước đó của ứng viên (ví dụ: công nhận hoặc cảm ơn câu trả lời đó).
2. ĐÂY LÀ YÊU CẦU BẮT BUỘC: Bạn phải đặt câu hỏi sau đây từ Nhà tuyển dụng: "{q_text}". Hãy dẫn dắt thật tự nhiên và lịch sự.
Lưu ý: Không được tự tiện thay đổi hoặc bỏ qua câu hỏi này.
"""
    elif question == "Technical Question based on CV/JD":
        return """
[Chỉ đạo dành riêng cho lượt này của Người phỏng vấn]:
1. Hãy nhận xét ngắn gọn, sắc sảo về câu trả lời trước đó của ứng viên.
2. Dựa vào CV của ứng viên và bản mô tả công việc (JD), hãy đặt một câu hỏi phỏng vấn kỹ thuật hoặc tình huống chuyên môn thực tế và sâu sắc để thử thách năng lực của ứng viên.
"""
    elif question == "Salary and Work Expectations":
        return """
[Chỉ đạo dành riêng cho lượt này của Người phỏng vấn]:
1. Hãy nhận xét ngắn gọn câu trả lời trước của ứng viên.
2. Hỏi ứng viên về mức lương mong muốn, kỳ vọng đối với môi trường làm việc mới và thời gian có thể bắt đầu nhận việc.
"""
    elif question == "Candidate Questions & Wrap up":
        return """
[Chỉ đạo dành riêng cho lượt này của Người phỏng vấn]:
1. ĐÂY LÀ LƯỢT HỎI CUỐI CÙNG của buổi phỏng vấn.
2. Hãy cảm ơn ứng viên vì sự tham gia của họ, và lịch sự hỏi xem họ có bất kỳ câu hỏi nào dành cho công ty chúng ta không, hoặc có chia sẻ gì thêm không.
"""
    else:
        return f"""
[Chỉ đạo dành riêng cho lượt này của Người phỏng vấn]:
Hãy đặt câu hỏi tiếp theo liên quan đến chủ đề: "{question}".
"""



def extract_text_from_pdf_url(cv_url: str) -> str | None:
    if not cv_url:
        return None
    try:
        logger.info(f"📥 Downloading PDF from: {cv_url}")
        response = httpx.get(cv_url, timeout=15.0)
        if response.status_code != 200:
            logger.error(f"Failed to download PDF: HTTP {response.status_code}")
            return None
        
        pdf_bytes = io.BytesIO(response.content)
        reader = PdfReader(pdf_bytes)
        text = ""
        for page in reader.pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + "\n"
        
        cleaned_text = text.strip()
        if cleaned_text:
            logger.info(f"✅ Successfully extracted {len(cleaned_text)} characters from PDF")
            return cleaned_text
        else:
            logger.warning("⚠️ Extracted text is empty")
            return None
    except Exception as e:
        logger.error(f"❌ Error extracting text from PDF URL: {e}")
        return None


class AIRecruitmentService:
    @staticmethod
    def is_mock_mode() -> bool:
        return not os.environ.get("GEMINI_API_KEY")

    @classmethod
    def screen_cv(cls, job_description: str, cv_text: str, cv_url: str = None) -> CVScreeningResponse:
        """
        Vòng 1: So sánh CV với JD và chấm điểm độ phù hợp.
        """
        pdf_text = extract_text_from_pdf_url(cv_url)
        if pdf_text:
            cv_text = pdf_text
        if cls.is_mock_mode():
            # Giả lập kết quả khi không có API key
            logger.info("Running screen_cv in MOCK mode")
            
            cv_lower = cv_text.lower()
            is_non_cv = False
            if "lab assignment" in cv_lower or "ospf" in cv_lower or "cisco" in cv_lower:
                is_non_cv = True
            elif not any(kw in cv_lower for kw in ["experience", "education", "skills", "projects", "cv", "resume", "nguyen van"]):
                is_non_cv = True

            if is_non_cv:
                return CVScreeningResponse(
                    score=0,
                    result="fail",
                    strengths=[],
                    weaknesses=["Tài liệu tải lên không phải là một CV/Resume hợp lệ (phát hiện tài liệu kỹ thuật, bài lab, bài tập, slide hoặc văn bản không liên quan)."],
                    reason="Tài liệu được tải lên không chứa thông tin về CV/Hồ sơ ứng viên hợp lệ để đánh giá tuyển dụng."
                )

            score = 80
            result = "pass"
            if "flutter" in cv_lower and "flutter" in job_description.lower():
                score = 88
                result = "pass"
            elif "python" in cv_lower and "python" in job_description.lower():
                score = 82
                result = "pass"
            elif len(cv_text) < 100:
                score = 45
                result = "fail"
            
            return CVScreeningResponse(
                score=score,
                result=result,
                strengths=["Kỹ năng chuyên môn phù hợp với vị trí công việc", "Kinh nghiệm làm việc thực tế với các dự án tương tự"],
                weaknesses=["Cần cải thiện kỹ năng giao tiếp tiếng Anh", "Chưa có chứng chỉ quốc tế liên quan"],
                reason="[MOCK] CV của ứng viên cho thấy sự tương thích tốt về mặt kỹ thuật và kinh nghiệm thực hiện dự án được yêu cầu trong JD."
            )

        prompt = f"""
Bạn là một AI chuyên viên tuyển dụng cao cấp.

CHÚ Ý QUAN TRỌNG VỀ PHÂN LOẠI TÀI LIỆU:
Trước tiên, hãy kiểm tra kỹ xem nội dung tài liệu được cung cấp dưới đây có thực sự là một bản CV / Resume / Hồ sơ ứng tuyển hợp lệ hay không. 
Nếu nội dung tài liệu KHÔNG PHẢI là một bản CV/Resume (ví dụ: là đề bài tập lab, bài giải lab, slide bài học, bài báo cáo kỹ thuật, tài liệu cấu hình thiết bị/phần mềm, hóa đơn, sách, truyện, hoặc văn bản ngẫu nhiên khác không chứa thông tin cá nhân/hồ sơ xin việc của một ứng viên cụ thể), bạn bắt buộc phải trả về kết quả như sau:
- `score`: 0
- `result`: "fail"
- `strengths`: []
- `weaknesses`: ["Tài liệu tải lên không phải là một CV/Resume hợp lệ (phát hiện tài liệu kỹ thuật, bài lab, bài tập, slide hoặc văn bản không liên quan)."]
- `reason`: "Tài liệu được tải lên không chứa thông tin về CV/Hồ sơ ứng viên hợp lệ để đánh giá tuyển dụng."

Nếu tài liệu đúng là một bản CV/Resume, hãy đánh giá CV của ứng viên so với bản mô tả công việc (JD) của nhà tuyển dụng dưới đây.

Yêu cầu công việc (JD):
{job_description}

Nội dung CV của ứng viên:
{cv_text}

Hãy đánh giá và chấm điểm dựa trên các tiêu chí sau nếu tài liệu là CV hợp lệ:
1. Kỹ năng bắt buộc (Must-have skills)
2. Kinh nghiệm làm việc liên quan
3. Dự án thực tế đã thực hiện
4. Học vấn và chứng chỉ chuyên ngành
5. Mức độ phù hợp tổng thể

Hãy xuất kết quả chính xác theo định dạng JSON với cấu trúc được chỉ định trong schema.
"""

        models_to_try = get_fallback_models()
        last_error = None
        for model_name in models_to_try:
            try:
                logger.info(f"Trying screen_cv with model: {model_name}")
                model = genai.GenerativeModel(
                    model_name=model_name,
                    generation_config={
                        "response_mime_type": "application/json",
                        "response_schema": CVScreeningResponse,
                    }
                )
                response = model.generate_content(prompt)
                return CVScreeningResponse.model_validate_json(response.text)
            except Exception as e:
                err_str = str(e).lower()
                if any(x in err_str for x in ["quota", "429", "exhausted", "limit"]):
                    logger.warning(f"Model {model_name} failed with quota/rate limit: {e}. Trying next fallback...")
                    last_error = e
                    continue
                else:
                    logger.error(f"Model {model_name} failed with non-quota error: {e}")
                    last_error = e
                    break

        return CVScreeningResponse(
            score=50,
            result="review",
            strengths=["Có kỹ năng cơ bản"],
            weaknesses=["Gặp lỗi kết nối AI hoặc quá giới hạn yêu cầu (Rate Limit)"],
            reason=f"Tất cả các mô hình AI đều quá tải hoặc hết hạn ngạch (Quota Exceeded). Lỗi cuối cùng: {str(last_error)}"
        )

    @classmethod
    def start_interview(cls, payload: InterviewSessionStartRequest) -> InterviewSessionStartResponse:
        """
        Vòng 2: Khởi tạo session phỏng vấn mới và sinh câu hỏi đầu tiên.
        """
        pdf_text = extract_text_from_pdf_url(payload.cv_url)
        if pdf_text:
            payload.cv_text = pdf_text
        session_id = f"sess_{uuid.uuid4().hex[:16]}"
        
        # Friendly mock questions for Mock mode
        mock_questions = [
            f"Chào bạn, tôi là AI Interviewer cho vị trí {payload.job_title}. Bạn hãy giới thiệu ngắn gọn về bản thân và kinh nghiệm nổi bật nhất của mình nhé?",
            "Cảm ơn phần giới thiệu của bạn. Dựa trên CV của bạn, bạn đã từng thực hiện dự án nào mà bạn thấy tự hào nhất? Hãy chia sẻ về vai trò của bạn trong dự án đó.",
            "Trong quá trình làm việc nhóm hoặc phát triển dự án, bạn đã bao giờ gặp xung đột kỹ thuật hoặc khó khăn lớn nào chưa? Bạn đã giải quyết nó như thế nào?",
        ]
        if payload.custom_questions:
            mock_questions.extend(payload.custom_questions)
        else:
            mock_questions.append("Bạn kỳ vọng gì vào môi trường làm việc mới và mức lương mong muốn của bạn là bao nhiêu?")
        mock_questions.append("Cảm ơn bạn. Câu hỏi cuối cùng: Bạn có câu hỏi nào dành cho công ty chúng tôi không?")

        # Logical interview phases/turns for real Gemini mode
        turns = [
            "Greeting and Self-Introduction",
            "Technical Question based on CV/JD",
        ]
        if payload.custom_questions:
            for q in payload.custom_questions:
                turns.append(f"Custom Question: {q}")
        else:
            turns.append("Salary and Work Expectations")
        turns.append("Candidate Questions & Wrap up")

        session = {
            "session_id": session_id,
            "job_title": payload.job_title,
            "job_description": payload.job_description,
            "cv_text": payload.cv_text,
            "custom_questions": payload.custom_questions,
            "current_question_index": 0,
            "max_questions": len(turns),
            "messages": [],
            "mock_questions": mock_questions,
            "turns": turns,
            "answers": []
        }

        first_question = ""
        if cls.is_mock_mode():
            first_question = mock_questions[0]
            session["current_question_index"] = 1
        else:
            system_instruction = cls._get_interview_system_instruction(
                payload.job_title, payload.job_description, payload.cv_text, payload.custom_questions
            )
            models_to_try = get_fallback_models()
            last_error = None
            chat_started = False
            for model_name in models_to_try:
                try:
                    logger.info(f"Trying start_interview with model: {model_name}")
                    model = genai.GenerativeModel(
                        model_name=model_name,
                        system_instruction=system_instruction
                    )
                    chat = model.start_chat(history=[])
                    prompt = f"""
[Ứng viên bắt đầu vào phòng phỏng vấn]
"Xin chào, tôi đã sẵn sàng. Hãy bắt đầu buổi phỏng vấn."

[Chỉ đạo dành riêng cho lượt này]:
Hãy gửi lời chào mừng ứng viên thân thiện, nêu rõ vị trí ứng tuyển "{payload.job_title}", và yêu cầu ứng viên giới thiệu ngắn gọn bản thân cùng kinh nghiệm nổi bật nhất của họ.
"""
                    response = chat.send_message(prompt)
                    first_question = response.text
                    
                    session["messages"] = [
                        {"role": "model", "parts": [first_question]}
                    ]
                    session["current_question_index"] = 1
                    session["model_name"] = model_name
                    chat_started = True
                    break
                except Exception as e:
                    err_str = str(e).lower()
                    if any(x in err_str for x in ["quota", "429", "exhausted", "limit"]):
                        logger.warning(f"Model {model_name} in start_interview failed with quota/rate limit: {e}. Trying next...")
                        last_error = e
                        continue
                    else:
                        logger.error(f"Model {model_name} in start_interview failed with non-quota error: {e}")
                        last_error = e
                        break
            
            if not chat_started:
                logger.error(f"Failed to start chat with any model. Falling back to mock first question. Error: {last_error}")
                first_question = mock_questions[0]
                session["current_question_index"] = 1
                session["model_name"] = "mock"

        INTERVIEW_SESSIONS[session_id] = session
        return InterviewSessionStartResponse(session_id=session_id, question=first_question)

    @classmethod
    def respond_interview(cls, payload: InterviewAnswerRequest) -> InterviewAnswerResponse:
        """
        Vòng 2: Nhận câu trả lời từ Candidate, trả về câu hỏi tiếp theo hoặc kết quả tổng kết.
        """
        session_id = payload.session_id
        session = INTERVIEW_SESSIONS.get(session_id)
        if not session:
            return InterviewAnswerResponse(
                question="Không tìm thấy phiên phỏng vấn. Vui lòng bắt đầu lại.",
                finished=True,
                report=None
            )

        answer = payload.answer
        session["answers"].append(answer)
        current_idx = session["current_question_index"]
        max_questions = session["max_questions"]

        # Kiểm tra xem đã kết thúc phỏng vấn chưa
        if current_idx >= max_questions:
            report = cls._generate_interview_report(session)
            INTERVIEW_SESSIONS.pop(session_id, None)
            return InterviewAnswerResponse(
                question=None,
                finished=True,
                report=report
            )

        next_question = ""
        if cls.is_mock_mode():
            next_question = session["mock_questions"][current_idx]
            session["current_question_index"] += 1
            return InterviewAnswerResponse(
                question=next_question,
                finished=False,
                report=None
            )
        else:
            try:
                # Use clean messages list directly as history (supported natively by the SDK)
                history = session["messages"]


                system_instruction = cls._get_interview_system_instruction(
                    session["job_title"], session["job_description"], session["cv_text"], session["custom_questions"]
                )
                
                # Get preferred model from session, then fallback list
                pref_model = session.get("model_name", MODEL_NAME)
                all_models = get_fallback_models()
                if pref_model in all_models:
                    all_models.remove(pref_model)
                models_to_try = [pref_model] + all_models
                
                # Get turn instruction based on logical turns
                turns = session.get("turns", [])
                turn_instruction = _get_turn_instruction(current_idx, turns)
                
                next_question = ""
                response_sent = False
                last_error = None
                
                for model_name in models_to_try:
                    try:
                        logger.info(f"Trying respond_interview with model: {model_name}")
                        model = genai.GenerativeModel(
                            model_name=model_name,
                            system_instruction=system_instruction
                        )
                        chat = model.start_chat(history=history)
                        
                        steered_prompt = f"""
[Ứng viên trả lời]:
"{answer}"

{turn_instruction}
"""
                        response = chat.send_message(steered_prompt)
                        next_question = response.text
                        
                        session["messages"].append({"role": "user", "parts": [answer]})
                        session["messages"].append({"role": "model", "parts": [next_question]})
                        session["current_question_index"] += 1
                        session["model_name"] = model_name
                        response_sent = True
                        break
                    except Exception as e:
                        err_str = str(e).lower()
                        if any(x in err_str for x in ["quota", "429", "exhausted", "limit"]):
                            logger.warning(f"Model {model_name} in respond_interview failed with quota/rate limit: {e}. Trying next...")
                            last_error = e
                            continue
                        else:
                            logger.error(f"Model {model_name} in respond_interview failed with non-quota error: {e}")
                            last_error = e
                            break
                            
                if not response_sent:
                    # Fallback to mock questions if all models fail
                    logger.error(f"Failed to respond with any model. Falling back to mock. Error: {last_error}")
                    next_question = session["mock_questions"][current_idx]
                    session["current_question_index"] += 1
                    return InterviewAnswerResponse(
                        question=next_question,
                        finished=False,
                        report=None
                    )
                
                return InterviewAnswerResponse(
                    question=next_question,
                    finished=False,
                    report=None
                )
            except Exception as e:
                logger.error(f"Error in chat step: {e}")
                next_question = session["mock_questions"][current_idx]
                session["current_question_index"] += 1
                return InterviewAnswerResponse(
                    question=next_question,
                    finished=False,
                    report=None
                )

    @classmethod
    def _generate_interview_report(cls, session: dict) -> InterviewReport:
        """
        Chấm điểm tổng kết sau khi kết thúc buổi phỏng vấn.
        """
        if cls.is_mock_mode() or not session.get("messages"):
            logger.info("Generating mock interview report")
            total_len = sum(len(ans) for ans in session["answers"])
            score = 75
            if total_len > 100:
                score = 85
            elif total_len < 30:
                score = 50
                
            recommend = score >= 70
            return InterviewReport(
                total_score=score,
                strengths=["Ứng viên nắm vững lý thuyết nền tảng", "Có khả năng giải thích tốt cấu trúc dự án cũ", "Thái độ phỏng vấn chuyên nghiệp, cởi mở"],
                weaknesses=["Kinh nghiệm thực tế về tối ưu hóa hiệu năng còn hạn chế", "Cần cải thiện thêm về cấu trúc thuật toán"],
                recommend_to_employer=recommend,
                reason=f"[MOCK] Ứng viên đạt kết quả khá tốt trong các câu hỏi chuyên môn và trả lời đầy đủ các câu hỏi phụ của nhà tuyển dụng. Đề xuất chuyển CV cho Employer."
            )

        try:
            messages = session["messages"]
            last_answer = session["answers"][-1]
            
            conversation_text = ""
            for idx, msg in enumerate(messages):
                role_label = "Interviewer (AI)" if msg["role"] == "model" else "Candidate"
                conversation_text += f"{role_label}: {msg['parts'][0]}\n"
            
            conversation_text += f"Candidate: {last_answer}\n"

            pref_model = session.get("model_name", MODEL_NAME)
            all_models = get_fallback_models()
            if pref_model in all_models:
                all_models.remove(pref_model)
            models_to_try = [pref_model] + all_models
            
            last_error = None
            for model_name in models_to_try:
                try:
                    logger.info(f"Trying report generation with model: {model_name}")
                    report_model = genai.GenerativeModel(
                        model_name=model_name,
                        generation_config={
                            "response_mime_type": "application/json",
                            "response_schema": InterviewReport,
                        }
                    )
                    prompt = f"""
Bạn là một AI Interviewer chuyên nghiệp kiêm chuyên gia đánh giá tuyển dụng.
Dưới đây là lịch sử buổi phỏng vấn trực tiếp giữa bạn và ứng viên cho vị trí {session['job_title']}.

Thông tin công việc (JD):
{session['job_description']}

CV của ứng viên:
{session['cv_text']}

Lịch sử phỏng vấn chi tiết:
{conversation_text}

Nhiệm vụ của bạn:
Hãy đánh giá kết quả phỏng vấn một cách khách quan, nghiêm túc và chính xác theo các tiêu chí và khung điểm quy định dưới đây.

LƯU Ý QUAN TRỌNG VỀ ĐÁNH GIÁ ĐIỂM SỐ (BẮT BUỘC TUÂN THỦ):
- Điểm số phỏng vấn phải phản ánh chính xác chất lượng câu trả lời của ứng viên. Không được cho điểm cao mang tính động viên hoặc mặc định.
- **Khung điểm DƯỚI 40 (Chống chỉ định/Không đạt):** 
  Nếu ứng viên có thái độ thiếu nghiêm túc, cợt nhả, trả lời cộc lốc hoặc vô nghĩa (ví dụ: trả lời 'Không', 'Không biết', '...', hoặc câu trả lời chỉ có vài từ thiếu hợp tác), hoặc hoàn toàn không trả lời được các câu hỏi cơ bản và câu hỏi riêng của Nhà tuyển dụng.
- **Khung điểm từ 40 đến 69 (Trung bình / Cần cân nhắc thêm):**
  Ứng viên trả lời nghiêm túc, có cố gắng trả lời đầy đủ nhưng câu trả lời còn ngắn gọn, thiếu chiều sâu kỹ thuật, hoặc còn lúng túng trước câu hỏi chuyên môn, câu hỏi riêng của Nhà tuyển dụng.
- **Khung điểm từ 70 đến 100 (Đạt yêu cầu / Khuyên dùng):**
  Ứng viên có thái độ chuyên nghiệp, trả lời đầy đủ, chi tiết, thể hiện rõ năng lực chuyên môn, kinh nghiệm thực tế phù hợp với JD và trả lời thuyết phục các câu hỏi riêng bắt buộc từ Nhà tuyển dụng.

Nhiệm vụ đánh giá chi tiết:
1. Phân tích thái độ, tính chuyên nghiệp và sự hợp tác của ứng viên.
2. Đánh giá năng lực chuyên môn dựa trên các câu hỏi kỹ thuật/CV.
3. Kiểm tra xem ứng viên có trả lời và đáp ứng tốt các câu hỏi riêng bắt buộc từ Nhà tuyển dụng không.
4. Cho điểm tổng kết (`total_score`) từ 0-100. Đề xuất `recommend_to_employer` là True nếu điểm từ 70 trở lên, ngược lại False.
5. Tổng hợp các điểm mạnh, điểm yếu lớn và nêu lý do chi tiết giải thích cho điểm số đó.

Hãy trả về kết quả chính xác theo định dạng JSON với cấu trúc quy định trong schema.
"""
                    response = report_model.generate_content(prompt)
                    return InterviewReport.model_validate_json(response.text)
                except Exception as e:
                    err_str = str(e).lower()
                    if any(x in err_str for x in ["quota", "429", "exhausted", "limit"]):
                        logger.warning(f"Model {model_name} in report generation failed with quota/rate limit: {e}. Trying next...")
                        last_error = e
                        continue
                    else:
                        logger.error(f"Model {model_name} in report generation failed with non-quota error: {e}")
                        last_error = e
                        break

            # If all fail, return fallback report
            return InterviewReport(
                total_score=60,
                strengths=["Nộp bài đầy đủ"],
                weaknesses=["Lỗi kỹ thuật trong quá trình chấm điểm AI"],
                recommend_to_employer=True,
                reason=f"Đã hoàn thành phỏng vấn nhưng tất cả các AI model đều quá giới hạn (Rate Limit): {str(last_error)}."
            )
        except Exception as e:
            logger.error(f"Error generating interview report: {e}")
            return InterviewReport(
                total_score=60,
                strengths=["Nộp bài đầy đủ"],
                weaknesses=["Lỗi hệ thống trong quá trình chấm điểm AI"],
                recommend_to_employer=True,
                reason=f"Đã hoàn thành phỏng vấn nhưng gặp lỗi hệ thống: {str(e)}."
            )



    @staticmethod
    def _get_interview_system_instruction(job_title: str, job_description: str, cv_text: str, custom_questions: list) -> str:
        custom_questions_str = "\n".join([f"- {q}" for q in custom_questions]) if custom_questions else "Không có câu hỏi riêng."
        return f"""
Bạn là một AI Interviewer chuyên nghiệp, lịch sự và nhạy bén cho vị trí: {job_title}. Bạn đang thực hiện buổi phỏng vấn trực tiếp với ứng viên.

Thông tin công việc (JD):
{job_description}

Thông tin CV của ứng viên:
{cv_text}

Câu hỏi riêng từ Nhà tuyển dụng (Employer):
{custom_questions_str}

Quy tắc phỏng vấn:
1. Bạn phải lắng nghe và đọc kỹ câu trả lời của ứng viên ở mỗi lượt. Nhận xét ngắn gọn, tự nhiên, thể hiện sự lắng nghe và thấu hiểu trước khi đặt câu hỏi tiếp theo.
2. CHỈ ĐẶT 1 CÂU HỎI duy nhất ở mỗi lượt. Không được hỏi dồn dập nhiều câu hỏi cùng lúc.
3. Ở mỗi lượt hội thoại, hệ thống sẽ gửi câu trả lời của ứng viên kèm theo "[Chỉ đạo dành riêng cho lượt này của Người phỏng vấn]". Bạn phải tuân thủ nghiêm ngặt chỉ đạo đó để dẫn dắt câu hỏi tiếp theo (ví dụ: hỏi câu hỏi chuyên môn, hỏi câu hỏi riêng của Nhà tuyển dụng, hoặc chào tạm biệt kết thúc).
4. Hãy giữ thái độ lịch thiệp, trọng thị và chuyên nghiệp của một nhà tuyển dụng thực thụ.
"""
