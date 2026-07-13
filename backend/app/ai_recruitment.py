import os
import uuid
import logging
import io
import httpx
from pathlib import Path
from typing import Optional, Tuple
# pyrefly: ignore [missing-import]
from pypdf import PdfReader
import google.generativeai as genai
from dotenv import load_dotenv

# Load .env file from the backend root directory
load_dotenv(Path(__file__).resolve().parent.parent / ".env")
from .models import (
    CVScreeningResponse,
    InterviewSessionStartRequest,
    InterviewSessionStartResponse,
    InterviewAnswerRequest,
    InterviewAnswerResponse,
    InterviewReport
)

logger = logging.getLogger("ai_recruitment")

# --- Tích hợp Dataset_Module (F&B interview dataset) với suy giảm an toàn ---
# Import được bọc try/except ở CẤP MODULE: nếu import thất bại, đặt sentinel None
# để Prompt_Builder tự động fallback về prompt cũ (không chứa nội dung dataset),
# đồng thời ghi log dấu hiệu lỗi cho người vận hành. Lỗi import KHÔNG được lan ra.
# (Requirements 8.1, 8.5)
try:
    from .fnb_interview_dataset import (
        get_role_for_title as _fnb_get_role_for_title,
        build_dataset_prompt_block as _fnb_build_dataset_prompt_block,
        SCORING_RUBRIC as _FNB_SCORING_RUBRIC,
    )
    _FNB_DATASET_AVAILABLE = True
except Exception as _fnb_import_error:  # pragma: no cover - degrade an toàn
    _fnb_get_role_for_title = None
    _fnb_build_dataset_prompt_block = None
    _FNB_SCORING_RUBRIC = None
    _FNB_DATASET_AVAILABLE = False
    logger.error(
        "Không thể import Dataset_Module (fnb_interview_dataset): %s. "
        "AI Interviewer sẽ chạy với prompt cũ (không có nội dung dataset).",
        _fnb_import_error,
    )

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


# Preamble "lắng nghe phản chiếu" áp dụng cho MỌI lượt do _get_turn_instruction dựng.
# Tại thời điểm hàm này chạy (trong respond_interview), Session LUÔN đã có ít nhất
# một câu trả lời trước của ứng viên — câu hỏi mở đầu được sinh ở start_interview
# và KHÔNG đi qua hàm này (Requirement 3.3). Vì vậy mọi nhánh ở đây đều áp dụng
# trình tự 3 bước (Requirement 3.1, 3.2): (1) công nhận/đồng cảm → (2) diễn giải
# lại ý câu trả lời gần nhất → (3) đặt đúng MỘT câu hỏi đào sâu.
_REFLECTIVE_LISTENING_PREAMBLE = """[Phong cách bắt buộc cho lượt này — Lắng nghe phản chiếu]:
1. CÔNG NHẬN/ĐỒNG CẢM: Mở đầu bằng một nhận xét ấm áp, chân thành để ghi nhận câu trả lời VỪA RỒI của ứng viên, cho thấy bạn thực sự lắng nghe.
2. DIỄN GIẢI LẠI Ý: Tóm lược/diễn giải ngắn gọn ý chính trong câu trả lời gần nhất của ứng viên bằng lời của bạn, để xác nhận đã hiểu đúng.
3. CHỈ ĐẶT MỘT CÂU HỎI: Sau đó mới chuyển sang phần hỏi bên dưới và chỉ đặt ĐÚNG MỘT (01) câu hỏi đào sâu trong lượt này (tuyệt đối không hỏi nhiều câu cùng lúc)."""


def _get_turn_instruction(current_idx: int, turns: list[str]) -> str:
    # _get_turn_instruction phải LUÔN trả về chuỗi và KHÔNG BAO GIỜ ném ngoại lệ
    # (Requirement 7.3 / suy giảm an toàn). Bọc toàn bộ logic trong try/except.
    try:
        if current_idx >= len(turns):
            return ""
        question = turns[current_idx]
        preamble = _REFLECTIVE_LISTENING_PREAMBLE
        if question.startswith("Custom Question: "):
            q_text = question.replace("Custom Question: ", "")
            return f"""
{preamble}

[Nội dung câu hỏi bắt buộc cho lượt này]:
ĐÂY LÀ YÊU CẦU BẮT BUỘC: Câu hỏi đào sâu của bạn ở bước (3) phải chính là câu hỏi sau đây từ Nhà tuyển dụng: "{q_text}". Hãy dẫn dắt thật tự nhiên và lịch sự.
Lưu ý: Không được tự tiện thay đổi hoặc bỏ qua câu hỏi này.
"""
        elif question == "Technical Question based on CV/JD":
            return f"""
{preamble}

[Nội dung câu hỏi cho lượt này]:
Ở bước (3), dựa vào CV của ứng viên và bản mô tả công việc (JD), hãy đặt MỘT câu hỏi phỏng vấn kỹ thuật hoặc tình huống chuyên môn thực tế và sâu sắc để thử thách năng lực của ứng viên.
"""
        elif question == "Salary and Work Expectations":
            return f"""
{preamble}

[Nội dung câu hỏi cho lượt này]:
Ở bước (3), hãy đặt MỘT câu hỏi về mức lương mong muốn cùng kỳ vọng đối với môi trường làm việc mới và thời gian có thể bắt đầu nhận việc (gộp thành một câu hỏi tự nhiên, không tách thành nhiều câu rời rạc).
"""
        elif question == "Candidate Questions & Wrap up":
            return f"""
{preamble}

[Nội dung câu hỏi cho lượt này]:
ĐÂY LÀ LƯỢT HỎI CUỐI CÙNG của buổi phỏng vấn. Sau khi công nhận và diễn giải lại câu trả lời gần nhất của ứng viên, hãy cảm ơn ứng viên vì sự tham gia của họ, rồi lịch sự đặt MỘT câu hỏi xem họ có câu hỏi nào dành cho công ty chúng ta hoặc có chia sẻ gì thêm không.
"""
        else:
            return f"""
{preamble}

[Nội dung câu hỏi cho lượt này]:
Ở bước (3), hãy đặt MỘT câu hỏi đào sâu tiếp theo liên quan đến chủ đề: "{question}".
"""
    except Exception as _turn_err:  # pragma: no cover - degrade an toàn, không bao giờ ném
        logger.error("Lỗi khi dựng turn instruction (current_idx=%s): %s", current_idx, _turn_err)
        return ""



def _download_and_extract_cv(cv_url: str) -> dict | None:
    if not cv_url or not (cv_url.startswith("http://") or cv_url.startswith("https://")):
        return None
    try:
        logger.info(f"📥 Downloading CV from: {cv_url}")
        import zipfile
        import xml.etree.ElementTree as ET
        
        response = httpx.get(cv_url, timeout=15.0)
        if response.status_code != 200:
            logger.error(f"Failed to download CV: HTTP {response.status_code}")
            return None
            
        content_bytes = response.content
        if not content_bytes:
            return None
            
        url_lower = cv_url.lower()
        if content_bytes.startswith(b"%PDF") or ".pdf" in url_lower:
            extracted_text = ""
            try:
                pdf_bytes = io.BytesIO(content_bytes)
                reader = PdfReader(pdf_bytes)
                for page in reader.pages:
                    page_text = page.extract_text()
                    if page_text:
                        extracted_text += page_text + "\n"
                extracted_text = extracted_text.strip()
            except Exception as pdf_err:
                logger.error(f"Error extracting text from PDF bytes: {pdf_err}")
                
            return {
                "type": "pdf",
                "bytes": content_bytes,
                "text": extracted_text
            }
            
        if content_bytes.startswith(b"PK\x03\x04") or ".docx" in url_lower:
            try:
                with zipfile.ZipFile(io.BytesIO(content_bytes)) as z:
                    xml_content = z.read("word/document.xml")
                root = ET.fromstring(xml_content)
                texts = []
                for elem in root.iter():
                    if elem.tag.endswith("}t") or elem.tag.endswith("t"):
                        if elem.text:
                            texts.append(elem.text)
                docx_text = " ".join(texts).strip()
                return {
                    "type": "text",
                    "text": docx_text
                }
            except Exception as docx_err:
                logger.error(f"Error extracting DOCX text: {docx_err}")
                return None
                
        return None
    except Exception as e:
        logger.error(f"Error downloading or parsing CV file from {cv_url}: {e}")
        return None



def _detect_conversational_request(answer: str) -> str | None:
    """
    Phát hiện xem câu trả lời của ứng viên có phải là một yêu cầu hội thoại (nói lại, giải thích, bỏ qua) hay không.
    Trả về: 'repeat', 'clarify', 'skip' hoặc None.
    """
    if not answer:
        return None
    ans_lower = answer.lower().strip()
    
    # 1. Yêu cầu lặp lại / nói lại
    repeat_keywords = [
        "nói lại", "nhắc lại", "lặp lại", "hỏi lại", "chưa nghe", "chưa rõ", "nghe chưa",
        "nói lại đi", "hỏi lại đi", "nhắc lại đi", "lặp lại đi", "chưa nghe rõ",
        "nói lại câu hỏi", "hỏi lại câu hỏi", "nhắc lại câu hỏi", "lặp lại câu hỏi",
        "repeat", "say again", "pardon"
    ]
    if any(kw in ans_lower for kw in repeat_keywords) or (len(ans_lower) < 15 and "nghe" in ans_lower and "chưa" in ans_lower):
        return "repeat"
        
    # 2. Yêu cầu giải thích / làm rõ
    clarify_keywords = [
        "giải thích", "làm rõ", "chưa hiểu", "không hiểu", "chưa rõ ý", "nghĩa là gì",
        "giải nghĩa", "giải thích thêm", "giải thích rõ", "chưa nắm được", "không rõ ý",
        "clarify", "explain", "what do you mean"
    ]
    if any(kw in ans_lower for kw in clarify_keywords):
        return "clarify"
        
    # 3. Yêu cầu bỏ qua / đổi câu hỏi
    skip_keywords = [
        "bỏ qua", "hỏi câu khác", "đổi câu hỏi", "câu khác đi", "qua câu", "next câu",
        "skip", "next question"
    ]
    if any(kw in ans_lower for kw in skip_keywords):
        return "skip"
        
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
        extracted_file = _download_and_extract_cv(cv_url) if cv_url else None
        
        if cls.is_mock_mode():
            logger.info("Running screen_cv in MOCK mode")
            text_to_eval = cv_text
            if extracted_file:
                if extracted_file["type"] == "text":
                    text_to_eval = extracted_file["text"]
                elif extracted_file["type"] == "pdf" and extracted_file["text"]:
                    text_to_eval = extracted_file["text"]
            
            cv_lower = text_to_eval.lower()
            is_non_cv = False
            if "lab assignment" in cv_lower or "ospf" in cv_lower or "cisco" in cv_lower:
                is_non_cv = True
            elif not any(kw in cv_lower for kw in [
                "experience", "education", "skills", "projects", "cv", "resume", "nguyen van",
                "kinh nghiệm", "học vấn", "kỹ năng", "họ tên", "ứng viên"
            ]):
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
            elif len(text_to_eval) < 100:
                score = 45
                result = "fail"
            
            return CVScreeningResponse(
                score=score,
                result=result,
                strengths=["Kỹ năng chuyên môn phù hợp với vị trí công việc", "Kinh nghiệm làm việc thực tế với các dự án tương tự"],
                weaknesses=["Cần cải thiện kỹ năng giao tiếp tiếng Anh", "Chưa có chứng chỉ quốc tế liên quan"],
                reason="[MOCK] CV của ứng viên cho thấy sự tương thích tốt về mặt kỹ thuật và kinh nghiệm thực hiện dự án được yêu cầu trong JD."
            )

        system_instruction = """
Bạn là một AI chuyên viên tuyển dụng cao cấp.

CHÚ Ý QUAN TRỌNG VỀ PHÂN LOẠI VÀ THẨM ĐỊNH TÀI LIỆU (BẮT BUỘC KIỂM TRA ĐẦU TIÊN):
Tài liệu của ứng viên gửi lên bắt buộc phải là một bản CV (Resume / Hồ sơ ứng tuyển) hợp lệ của một cá nhân cụ thể.
Một bản CV/Resume hợp lệ BẮT BUỘC phải thỏa mãn đồng thời các điều kiện sau:
1. Có thông tin định danh cá nhân tối thiểu (ví dụ: Họ tên và một trong các thông tin liên hệ như Email, Số điện thoại, Địa chỉ, Link LinkedIn/GitHub).
2. Có cấu trúc thể hiện quá trình làm việc, học tập hoặc bộ kỹ năng của một cá nhân (bao gồm các phần như Kinh nghiệm làm việc, Học vấn, Kỹ năng, Mục tiêu nghề nghiệp, Dự án cá nhân).

Các tài liệu sau đây được coi là KHÔNG HỢP LỆ (KHÔNG PHẢI CV):
- Đề bài tập, bài giải lab, slide bài giảng, giáo trình, bài báo cáo học thuật.
- Hướng dẫn kỹ thuật, tài liệu cấu hình (config), mã nguồn (source code), log file, thông báo lỗi.
- Hóa đơn, chứng từ, tài liệu sản phẩm, bài viết tin tức, tiểu thuyết, truyện, hoặc văn bản ngẫu nhiên.
- Bản mô tả công việc (JD) của chính công ty hoặc tài liệu không chứa thông tin của một người xin việc cụ thể.

NẾU TÀI LIỆU KHÔNG PHẢI LÀ CV/RESUME HỢP LỆ, BẠN BẮT BUỘC PHẢI TRẢ VỀ:
{
  "score": 0,
  "result": "fail",
  "strengths": [],
  "weaknesses": ["Tài liệu tải lên không phải là một CV/Resume hợp lệ (phát hiện tài liệu kỹ thuật, bài lab, bài tập, slide hoặc văn bản không liên quan)."],
  "reason": "Tài liệu được tải lên không chứa thông tin về CV/Hồ sơ ứng viên hợp lệ để đánh giá tuyển dụng."
}
TUYỆT ĐỐI không được đánh giá các từ khóa kỹ thuật hay kỹ năng trong các văn bản không phải CV này để chấm điểm hoặc cho kết quả "pass". An toàn và chính xác trong việc phân loại tài liệu là ưu tiên số một.

Nếu tài liệu đúng là một bản CV/Resume hợp lệ, hãy tiến hành đánh giá CV đó so với bản mô tả công việc (JD) bên dưới theo các tiêu chí:
1. Kỹ năng bắt buộc (Must-have skills)
2. Kinh nghiệm làm việc liên quan
3. Dự án thực tế đã thực hiện
4. Học vấn và chứng chỉ chuyên ngành
5. Mức độ phù hợp tổng thể

Hãy xuất kết quả chính xác theo định dạng JSON với cấu trúc được chỉ định trong schema.
""".strip()

        if extracted_file and extracted_file["type"] == "pdf":
            content_parts = [
                {
                    "mime_type": "application/pdf",
                    "data": extracted_file["bytes"]
                },
                f"Yêu cầu công việc (JD):\n{job_description}\n\nNội dung tài liệu của ứng viên nằm trong file PDF đính kèm ở trên. Hãy kiểm tra xem đây có phải là CV/Resume hợp lệ không, và nếu có thì đánh giá so với JD."
            ]
        else:
            text_to_eval = cv_text
            if extracted_file and extracted_file["type"] == "text":
                text_to_eval = extracted_file["text"]
            content_parts = [
                f"Yêu cầu công việc (JD):\n{job_description}\n\nNội dung tài liệu của ứng viên:\n{text_to_eval}"
            ]

        models_to_try = get_fallback_models()
        last_error = None
        for model_name in models_to_try:
            try:
                logger.info(f"Trying screen_cv with model: {model_name}")
                model = genai.GenerativeModel(
                    model_name=model_name,
                    system_instruction=system_instruction,
                    generation_config={
                        "response_mime_type": "application/json",
                        "response_schema": CVScreeningResponse,
                    }
                )
                response = model.generate_content(content_parts)
                import json
                res_data = json.loads(response.text)
                if not isinstance(res_data, dict):
                    res_data = {}
                if "score" not in res_data:
                    res_data["score"] = 50
                if "result" not in res_data:
                    res_data["result"] = "fail" if res_data.get("score", 50) < 50 else "pass"
                if "strengths" not in res_data or not isinstance(res_data["strengths"], list):
                    res_data["strengths"] = []
                if "weaknesses" not in res_data or not isinstance(res_data["weaknesses"], list):
                    res_data["weaknesses"] = []
                if "reason" not in res_data:
                    res_data["reason"] = "Tài liệu đã được phân tích."
                return CVScreeningResponse(**res_data)
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
        extracted_file = _download_and_extract_cv(payload.cv_url) if payload.cv_url else None
        if extracted_file:
            if extracted_file["type"] == "text":
                payload.cv_text = extracted_file["text"]
            elif extracted_file["type"] == "pdf" and extracted_file["text"]:
                payload.cv_text = extracted_file["text"]
        session_id = f"sess_{uuid.uuid4().hex[:16]}"
        
        # Friendly mock questions for Mock mode (F&B focused)
        mock_questions = [
            f"Chào bạn, tôi là AI Interviewer cho vị trí {payload.job_title}. Bạn hãy giới thiệu ngắn gọn về bản thân và kinh nghiệm nổi bật nhất của bạn trong ngành F&B nhé?",
            "Cảm ơn phần giới thiệu của bạn. Nếu cửa hàng rơi vào giờ cao điểm, khách xếp hàng rất đông và bạn đang bị quá tải công việc, bạn sẽ xử lý thế nào để đảm bảo phục vụ chu đáo?",
            "Trong quá trình phục vụ, nếu gặp trường hợp khách hàng phàn nàn đồ ăn/đồ uống không đúng vị hoặc có vấn đề vệ sinh, bạn sẽ giải quyết tình huống này ra sao?",
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
            req_type = _detect_conversational_request(answer)
            if req_type in ["repeat", "clarify"] and current_idx > 0:
                pass
            else:
                report = cls._generate_interview_report(session)
                INTERVIEW_SESSIONS.pop(session_id, None)
                return InterviewAnswerResponse(
                    question=None,
                    finished=True,
                    report=report
                )

        # Phát hiện yêu cầu hội thoại
        req_type = _detect_conversational_request(answer)
        
        is_repeat_or_clarify = False
        steered_prompt = ""
        turns = session.get("turns", [])

        if req_type in ["repeat", "clarify"] and current_idx > 0:
            is_repeat_or_clarify = True
            prev_turn = turns[current_idx - 1]
            if req_type == "repeat":
                steered_prompt = f"""
[Ứng viên yêu cầu]: "{answer}"
[YÊU CẦU BẮT BUỘC]: Ứng viên yêu cầu lặp lại câu hỏi vừa rồi. 
Bạn hãy bày tỏ sự lịch sự, vui vẻ (ví dụ: "Dạ vâng...", "Tất nhiên rồi bạn...") và lặp lại câu hỏi của lượt trước liên quan đến chủ đề: "{prev_turn}". 
TUYỆT ĐỐI KHÔNG chuyển sang câu hỏi tiếp theo và không hỏi chủ đề mới.
"""
            else:
                steered_prompt = f"""
[Ứng viên yêu cầu]: "{answer}"
[YÊU CẦU BẮT BUỘC]: Ứng viên yêu cầu giải thích hoặc làm rõ câu hỏi vừa rồi. 
Bạn hãy bày tỏ sự sẵn lòng giúp đỡ và giải thích, làm rõ hoặc diễn đạt lại câu hỏi liên quan đến chủ đề: "{prev_turn}" bằng ngôn từ đơn giản, dễ hiểu hơn. 
TUYỆT ĐỐI KHÔNG chuyển sang câu hỏi tiếp theo và không hỏi chủ đề mới.
"""
        elif req_type == "skip":
            current_idx = session["current_question_index"]
            if current_idx < max_questions:
                next_turn_instruction = _get_turn_instruction(current_idx, turns)
                steered_prompt = f"""
[Ứng viên yêu cầu]: "{answer}"
[YÊU CẦU BẮT BUỘC]: Ứng viên yêu cầu bỏ qua câu hỏi vừa rồi. Bạn hãy lịch sự đồng ý (ví dụ: "Được chứ, mình qua câu hỏi tiếp theo nhé...") và chuyển ngay sang câu hỏi mới dưới đây:
{next_turn_instruction}
"""
            else:
                report = cls._generate_interview_report(session)
                INTERVIEW_SESSIONS.pop(session_id, None)
                return InterviewAnswerResponse(
                    question=None,
                    finished=True,
                    report=report
                )

        next_question = ""
        if cls.is_mock_mode():
            if is_repeat_or_clarify:
                prev_q = session["mock_questions"][current_idx - 1]
                if req_type == "repeat":
                    next_question = f"[MOCK REPEAT] {prev_q}"
                else:
                    next_question = f"[MOCK CLARIFY] {prev_q}"
            else:
                next_question = session["mock_questions"][current_idx]
                session["current_question_index"] += 1
            
            return InterviewAnswerResponse(
                question=next_question,
                finished=False,
                report=None
            )
        else:
            try:
                history = session["messages"]
                system_instruction = cls._get_interview_system_instruction(
                    session["job_title"], session["job_description"], session["cv_text"], session["custom_questions"]
                )
                
                pref_model = session.get("model_name", MODEL_NAME)
                all_models = get_fallback_models()
                if pref_model in all_models:
                    all_models.remove(pref_model)
                models_to_try = [pref_model] + all_models
                
                if not steered_prompt:
                    turn_instruction = _get_turn_instruction(current_idx, turns)
                    steered_prompt = f"""
[Ứng viên trả lời]:
"{answer}"

{turn_instruction}
"""

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
                        
                        response = chat.send_message(steered_prompt)
                        next_question = response.text
                        
                        session["messages"].append({"role": "user", "parts": [answer]})
                        session["messages"].append({"role": "model", "parts": [next_question]})
                        
                        if not is_repeat_or_clarify:
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
                    logger.error(f"Failed to respond with any model. Falling back to mock. Error: {last_error}")
                    if is_repeat_or_clarify:
                        prev_q = session["mock_questions"][current_idx - 1]
                        next_question = f"[MOCK REPEAT] {prev_q}"
                    else:
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
                if is_repeat_or_clarify:
                    prev_q = session["mock_questions"][current_idx - 1]
                    next_question = f"[MOCK REPEAT] {prev_q}"
                else:
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
                past_experience_score=score - 2,
                situation_handling_score=score + 3,
                operations_score=score,
                custom_questions_score=score - 5 if session.get("custom_questions") else 80,
                strengths=[
                    "Ứng viên có thái độ niềm nở, vui vẻ, thích hợp với môi trường dịch vụ khách hàng",
                    "Hiểu và chú trọng quy trình vệ sinh an toàn thực phẩm",
                    "Cách xử lý phàn nàn của khách hàng rất khéo léo và bình tĩnh"
                ],
                weaknesses=[
                    "Cần cải thiện thêm tốc độ thao tác pha chế/phục vụ trong giờ cao điểm",
                    "Kỹ năng đề xuất món ăn thêm (upselling) để tăng doanh thu còn hạn chế"
                ],
                recommend_to_employer=recommend,
                reason=f"[MOCK] Ứng viên cho thấy sự tương thích tốt về mặt thái độ phục vụ và có kinh nghiệm cơ bản trong ngành F&B. Trả lời thuyết phục các câu hỏi xử lý tình huống của cửa hàng."
            )

        try:
            messages = session["messages"]
            last_answer = session["answers"][-1]
            
            conversation_text = ""
            for idx, msg in enumerate(messages):
                role_label = "Interviewer (AI)" if msg["role"] == "model" else "Candidate"
                conversation_text += f"{role_label}: {msg['parts'][0]}\n"
            
            conversation_text += f"Candidate: {last_answer}\n"

            # Lấy nội dung Scoring_Rubric từ Dataset_Module để CHÈN THÊM vào prompt
            # báo cáo (bổ sung cho hướng dẫn chấm điểm chi tiết sẵn có, không thay thế).
            # Chỉ chạy ở chế độ AI thật (nhánh này); Mock_Mode đã return ở trên nên
            # không bao giờ tới đây. Bọc try/except + guard _FNB_DATASET_AVAILABLE:
            # nếu lỗi → bỏ qua rubric, dùng prompt cũ, ghi log, KHÔNG ném ra caller.
            # (Requirements 4.1, 8.3, 8.4, 8.6)
            rubric_block = ""
            if _FNB_DATASET_AVAILABLE and _FNB_SCORING_RUBRIC:
                try:
                    rubric_block = (
                        "\n\nRUBRIC CHẤM ĐIỂM CHUẨN HÓA (tham chiếu bắt buộc, "
                        "bổ sung cho hướng dẫn chấm điểm chi tiết ở trên):\n"
                        f"{_FNB_SCORING_RUBRIC}\n"
                    )
                except Exception as _rubric_err:  # degrade an toàn - dùng prompt gốc
                    logger.error(
                        "Lỗi khi lấy SCORING_RUBRIC cho prompt báo cáo: %s. "
                        "Dùng prompt gốc (không có rubric).",
                        _rubric_err,
                    )
                    rubric_block = ""

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
Bạn là một AI Interviewer chuyên nghiệp kiêm chuyên gia đánh giá tuyển dụng ngành F&B (Nhà hàng, Quán ăn, Cửa hàng Cafe).
Dưới đây là lịch sử buổi phỏng vấn trực tiếp giữa bạn và ứng viên cho vị trí {session['job_title']}.

Thông tin công việc (JD):
{session['job_description']}

CV của ứng viên:
{session['cv_text']}

Lịch sử phỏng vấn chi tiết:
{conversation_text}

Nhiệm vụ của bạn:
Hãy đánh giá kết quả phỏng vấn một cách khách quan, nghiêm túc và chính xác theo các tiêu chí và khung điểm quy định dưới đây.

HƯỚNG DẪN CHẤM ĐIỂM CHI TIẾT (0-100 điểm cho mỗi phần):
1. **past_experience_score (Điểm đánh giá về kinh nghiệm làm việc ngành F&B):** Đánh giá dựa trên việc ứng viên đã từng làm các công việc F&B tương tự trong quá khứ hay chưa, có hiểu tính chất công việc không.
2. **situation_handling_score (Điểm giải quyết và xử lý tình huống thực tế):** Đánh giá cách ứng viên ứng biến, xử lý các tình huống giả định hoặc sự cố (ví dụ: phục vụ chậm, khách phàn nàn, áp lực giờ cao điểm).
3. **operations_score (Điểm quy trình vận hành và tác phong làm việc):** Đánh giá tính kỷ luật, giờ giấc ca kíp, quy tắc vệ sinh an toàn thực phẩm, thái độ dịch vụ.
4. **custom_questions_score (Điểm trả lời các câu hỏi riêng từ Employer):** Đánh giá mức độ trả lời chính xác, đầy đủ các câu hỏi bắt buộc do Nhà tuyển dụng đề ra. (Nếu Employer không có câu hỏi riêng, cho điểm mặc định bằng điểm trung bình cộng của các phần khác).
5. **total_score (Tổng điểm trung bình):** Tổng điểm trung bình phản ánh chính xác năng lực tổng thể của ứng viên.

LƯU Ý QUAN TRỌNG VỀ ĐÁNH GIÁ ĐIỂM SỐ (BẮT BUỘC TUÂN THỦ):
- Điểm số phỏng vấn phải phản ánh chính xác chất lượng câu trả lời của ứng viên. Không được cho điểm cao mang tính động viên hoặc mặc định.
- **Khung điểm DƯỚI 40 (Chống chỉ định/Không đạt):** 
  Nếu ứng viên có thái độ thiếu nghiêm túc, cợt nhả, trả lời cộc lốc hoặc vô nghĩa (ví dụ: trả lời 'Không', 'Không biết', '...', hoặc câu trả lời chỉ có vài từ thiếu hợp tác), hoặc hoàn toàn không trả lời được các câu hỏi cơ bản và câu hỏi riêng của Nhà tuyển dụng. Hoặc nếu ứng viên sử dụng ngôn từ không chuẩn mực/thô tục/vô lễ, hay chia sẻ hành vi vi phạm đạo đức nghề nghiệp nghiêm trọng (như ăn cắp, lừa dối, phá hoại).
- **Khung điểm từ 40 đến 69 (Trung bình / Cần cân nhắc thêm):**
  Ứng viên trả lời nghiêm túc, có cố gắng trả lời đầy đủ nhưng câu trả lời còn ngắn gọn, thiếu chiều sâu thực tế, hoặc còn lúng túng trước câu hỏi tình huống hoặc câu hỏi riêng của Nhà tuyển dụng. Hoặc nếu phát hiện ứng viên có hành vi sử dụng AI/chatbot khác để trả lời câu hỏi (cần hạ điểm toàn bộ xuống dưới 50).
- **Khung điểm từ 70 đến 100 (Đạt yêu cầu / Khuyên dùng):**
  Ứng viên có thái độ chuyên nghiệp, trả lời đầy đủ, chi tiết, thể hiện rõ năng lực chuyên môn, kinh nghiệm thực tế phù hợp với JD và trả lời thuyết phục các câu hỏi riêng bắt buộc từ Nhà tuyển dụng. Tuyệt đối không có dấu hiệu sử dụng AI hoặc vi phạm đạo đức/tác phong.

Nhiệm vụ đánh giá chi tiết:
1. Phân tích thái độ, tính chuyên nghiệp, sự hợp tác của ứng viên.
2. Đánh giá kinh nghiệm, xử lý tình huống và vận hành F&B dựa trên câu hỏi chuyên môn/CV.
3. Kiểm tra xem ứng viên có trả lời và đáp ứng tốt các câu hỏi riêng bắt buộc từ Nhà tuyển dụng không.
4. PHÁT HIỆN NGÔN TỪ KHÔNG CHUẨN MỰC & VI PHẠM ĐẠO ĐỨC: Kiểm tra kỹ xem ứng viên có sử dụng từ ngữ thô tục, vô lễ hoặc kể các hành vi vi phạm đạo đức nghề nghiệp F&B (ăn cắp tiền, phá hoại, lừa dối, gây hại cho khách/đồng nghiệp). Nếu có, bắt buộc chấm toàn bộ các điểm số thành phần và tổng kết (`total_score`) xuống DƯỚI 40 điểm (từ 0 đến 35 điểm), đặt `recommend_to_employer` là False, ghi rõ hành vi vi phạm đạo đức này trong `weaknesses` và giải thích lý do cụ thể trong `reason`.
5. PHÁT HIỆN SỬ DỤNG AI ĐỂ TRẢ LỜI: Kiểm tra xem ứng viên có dấu hiệu sao chép câu trả lời từ AI/chatbot khác hay không (dấu hiệu: câu trả lời cực kỳ dài, cấu trúc gạch đầu dòng hoàn hảo, dùng từ ngữ chatbot học thuật, thiếu chi tiết cá nhân thực tế). Nếu phát hiện hoặc nghi ngờ mạnh mẽ hành vi này, bắt buộc hạ toàn bộ các điểm số xuống DƯỚI 50 điểm (từ 0 đến 45 điểm), đặt `recommend_to_employer` là False, ghi rõ nghi vấn sử dụng AI trong `weaknesses` và giải thích lý do cụ thể trong `reason`.
6. Cho điểm tổng kết (`total_score`) từ 0-100. Đề xuất `recommend_to_employer` là True nếu điểm từ 70 trở lên và không vi phạm quy tắc đạo đức hay dùng AI, ngược lại False.
7. Tổng hợp các điểm mạnh, điểm yếu lớn và nêu lý do chi tiết giải thích cho điểm số đó.
{rubric_block}
Hãy trả về kết quả chính xác theo định dạng JSON với cấu trúc quy định trong schema.
"""
                    response = report_model.generate_content(prompt)
                    # Cơ chế parse JSON GIỮ NGUYÊN: response_schema + model_validate_json.
                    # Tách riêng bước parse/validate để xử lý đúng yêu cầu 4.4: khi parse
                    # JSON thất bại, trả về InterviewReport hợp lệ ĐỦ 4 trường điểm kèm
                    # ghi chú điểm yếu CHỈ RÕ đây là lỗi chấm điểm của AI. (Requirement 4.4)
                    try:
                        return InterviewReport.model_validate_json(response.text)
                    except Exception as parse_err:
                        logger.error(
                            "Lỗi parse/validate JSON báo cáo từ model %s: %s. "
                            "Trả về báo cáo hợp lệ với ghi chú lỗi chấm điểm AI.",
                            model_name,
                            parse_err,
                        )
                        return InterviewReport(
                            total_score=60,
                            past_experience_score=60,
                            situation_handling_score=60,
                            operations_score=60,
                            custom_questions_score=60,
                            strengths=["Ứng viên đã hoàn thành buổi phỏng vấn"],
                            weaknesses=[
                                "Lỗi chấm điểm của AI: hệ thống không thể phân tích (parse) "
                                "kết quả JSON chấm điểm do mô hình trả về, nên điểm số tạm "
                                "thời mang tính trung lập và cần đánh giá lại thủ công."
                            ],
                            recommend_to_employer=False,
                            reason=(
                                "Buổi phỏng vấn đã hoàn tất nhưng hệ thống gặp lỗi khi đọc/parse "
                                f"kết quả chấm điểm JSON từ AI (model {model_name}). Đây là lỗi "
                                "chấm điểm của AI, không phải do ứng viên."
                            ),
                        )
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
                past_experience_score=60,
                situation_handling_score=60,
                operations_score=60,
                custom_questions_score=60,
                strengths=["Nộp bài đầy đủ"],
                weaknesses=["Lỗi kỹ thuật trong quá trình chấm điểm AI"],
                recommend_to_employer=True,
                reason=f"Đã hoàn thành phỏng vấn nhưng tất cả các AI model đều quá giới hạn (Rate Limit): {str(last_error)}."
            )
        except Exception as e:
            logger.error(f"Error generating interview report: {e}")
            return InterviewReport(
                total_score=60,
                past_experience_score=60,
                situation_handling_score=60,
                operations_score=60,
                custom_questions_score=60,
                strengths=["Nộp bài đầy đủ"],
                weaknesses=["Lỗi hệ thống trong quá trình chấm điểm AI"],
                recommend_to_employer=True,
                reason=f"Đã hoàn thành phỏng vấn nhưng gặp lỗi hệ thống: {str(e)}."
            )



    @staticmethod
    def _get_interview_system_instruction(job_title: str, job_description: str, cv_text: str, custom_questions: list) -> str:
        custom_questions_str = "\n".join([f"- {q}" for q in custom_questions]) if custom_questions else "Không có câu hỏi riêng."
        base_instruction = f"""
Bạn là một AI Interviewer chuyên nghiệp, lịch thiệp và dày dạn kinh nghiệm quản lý trong ngành F&B (Nhà hàng - Cà phê - Khách sạn). Bạn đang phỏng vấn ứng viên cho vị trí: {job_title}.

Thông tin công việc (JD):
{job_description}

Thông tin CV của ứng viên:
{cv_text}

Câu hỏi riêng bắt buộc từ Nhà tuyển dụng (Employer):
{custom_questions_str}

Nội dung và Mục tiêu Phỏng vấn:
1. **Tìm hiểu Kinh nghiệm đã làm:** Hỏi ứng viên về kinh nghiệm thực tế tại các vị trí F&B trước đây, vai trò và môi trường làm việc cũ.
2. **Xử lý Tình huống Thực tế:** Đặt câu hỏi tình huống thực tiễn ngành F&B (ví dụ: khách chê món ăn/đồ uống có vấn đề, đông khách giờ cao điểm và thiếu người, xung đột với đồng nghiệp trong ca).
3. **Đặt Câu hỏi từ Employer:** Phải đưa các câu hỏi riêng của Employer vào đúng lượt đi.

Quy tắc giao tiếp (BẮT BUỘC):
1. Nói tiếng Việt tự nhiên, ấm áp, lịch sự, đóng vai trò như một quản lý/chủ quán thực thụ đang trò chuyện trực tiếp.
2. Bạn phải lắng nghe và đọc kỹ câu trả lời của ứng viên ở mỗi lượt. Luôn nhận xét ngắn gọn, tự nhiên (thể hiện sự khích lệ hoặc công nhận câu trả lời cũ) trước khi đặt câu hỏi mới.
3. CHỈ ĐẶT 1 CÂU HỎI duy nhất ở mỗi lượt. Tuyệt đối không hỏi dồn dập nhiều câu cùng một lúc.
4. Ở mỗi lượt hội thoại, hệ thống sẽ gửi câu trả lời kèm theo "[Chỉ đạo dành riêng cho lượt này của Người phỏng vấn]". Bạn phải tuân thủ nghiêm ngặt chỉ đạo đó để đặt câu hỏi tương ứng (ví dụ: chào hỏi ở lượt đầu, hỏi câu hỏi chuyên môn/tình huống ở lượt kế tiếp, hỏi câu hỏi riêng từ Employer, hoặc cảm ơn kết thúc).
5. TƯƠNG TÁC CÓ CẢM XÚC & ĐỒNG CẢM SÂU SẮC: Thể hiện sự đồng cảm ấm áp khi ứng viên chia sẻ về những vất vả của ca làm F&B và tán thưởng chân thành đối với những thành tích tốt của họ.
6. THỰC HIỆN YÊU CẦU ĐƠN GIẢN: Nếu ứng viên có yêu cầu đơn giản như nhờ nói lại câu hỏi, giải thích thêm hay đổi câu hỏi, hãy thực hiện ngay lập tức một cách thân thiện.
7. PHÁT HIỆN ỨNG VIÊN DÙNG AI: Nếu nghi ngờ ứng viên dùng AI (ChatGPT/Gemini) để trả lời phỏng vấn (cấu trúc gạch đầu dòng tự động, dài dòng, sáo rỗng), hãy hỏi thêm câu hỏi phụ đào sâu rất cụ thể về trải nghiệm thực tế để kiểm chứng.
8. XỬ LÝ NGÔN TỪ KHÔNG CHUẨN MỰC: Nếu ứng viên dùng từ ngữ thô tục, vô lễ hoặc hành vi phi đạo đức, hãy giữ sự bình tĩnh, lịch sự của người phỏng vấn và hướng câu chuyện quay lại chủ đề chính.
"""

        # Làm giàu prompt bằng Dataset_Module: style guide + few-shot + gợi ý câu
        # hỏi theo vị trí F&B, CHÈN VÀO CUỐI prompt gốc (append-only, không sửa nội
        # dung gốc). Toàn bộ lời gọi dataset được bọc try/except: bất kỳ ngoại lệ
        # nào → bỏ qua nội dung dataset, dùng prompt cũ, KHÔNG ném ra caller.
        # (Requirements 2.1, 2.6, 8.4, 8.5)
        if not _FNB_DATASET_AVAILABLE:
            return base_instruction
        try:
            role = _fnb_get_role_for_title(job_title)
            dataset_block = _fnb_build_dataset_prompt_block(role)
            if dataset_block:
                return f"{base_instruction}\n{dataset_block}"
            return base_instruction
        except Exception as e:  # degrade an toàn - dùng prompt gốc
            logger.error(
                "Lỗi khi dựng nội dung Dataset_Module cho system instruction: %s. "
                "Dùng prompt gốc (không có nội dung dataset).",
                e,
            )
            return base_instruction
