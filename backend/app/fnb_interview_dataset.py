"""F&B interview dataset module.

Thuần dữ liệu tĩnh + thư viện chuẩn Python (KHÔNG phụ thuộc ngoài).

Module này cung cấp dữ liệu và các hàm chọn lọc thuần (không side-effect) để
làm giàu prompt của AI Interviewer (Vòng 2) trong ``ai_recruitment.py``:

- ``COMMUNICATION_STYLE_GUIDE`` / ``SCORING_RUBRIC``: hằng số text.
- ``FnbRole``: cấu trúc dữ liệu mô tả một vị trí F&B.
- ``GENERIC_FALLBACK_ROLE``: vị trí mặc định khi không khớp keyword nào.
- ``FNB_ROLES``: danh sách 23 vị trí F&B (được bổ sung ở task 1.2).

Các hàm ``get_role_for_title`` / ``build_fewshot_block`` / ``build_question_hints``
sẽ được bổ sung ở các task kế tiếp (2.x, 3.x) trong cùng file này.

Ghi chú thiết kế: module chỉ sử dụng ``typing`` và ``unicodedata`` từ thư viện
chuẩn; không khai báo hay yêu cầu bất kỳ phụ thuộc bên ngoài nào (Requirement 8.2).
"""

from __future__ import annotations

import unicodedata
from typing import Dict, List, Optional, TypedDict

__all__ = [
    "COMMUNICATION_STYLE_GUIDE",
    "SCORING_RUBRIC",
    "FnbAnswer",
    "FnbAnswerSet",
    "FnbFewshotExample",
    "FnbQuestionBank",
    "FnbRole",
    "GENERIC_FALLBACK_ROLE",
    "FNB_ROLES",
    "get_role_for_title",
    "build_fewshot_block",
    "build_question_hints",
    "DEFAULT_TOKEN_BUDGET",
    "build_dataset_prompt_block",
]


# ---------------------------------------------------------------------------
# Cấu trúc dữ liệu (typed dict) cho một vị trí F&B — theo Data Models trong design
# ---------------------------------------------------------------------------


class FnbAnswer(TypedDict):
    """Một câu trả lời mẫu của ứng viên kèm phản hồi minh hoạ phong cách của AI."""

    text: str       # Lời ứng viên (ví dụ minh hoạ)
    ai_reply: str   # Phản hồi của AI: công nhận/đồng cảm → diễn giải → câu hỏi đào sâu


class FnbAnswerSet(TypedDict):
    """Ba mức chất lượng câu trả lời cho cùng một câu hỏi few-shot."""

    good: FnbAnswer
    fair: FnbAnswer
    weak: FnbAnswer


class FnbFewshotExample(TypedDict):
    """Một ví dụ hội thoại few-shot: một câu hỏi và các mức trả lời good/fair/weak."""

    question: str
    answers: FnbAnswerSet


class FnbQuestionBank(TypedDict):
    """Ngân hàng câu hỏi theo các nhóm năng lực."""

    experience: List[str]        # Kinh nghiệm
    situation: List[str]         # Xử lý tình huống
    operations: List[str]        # Quy trình/vận hành
    hygiene: List[str]           # Vệ sinh an toàn thực phẩm
    teamwork: List[str]          # Phối hợp nhóm
    service_attitude: List[str]  # Thái độ phục vụ


class FnbRole(TypedDict):
    """Cấu trúc dữ liệu một vị trí F&B."""

    id: str                          # định danh duy nhất, vd "waiter"
    name: str                        # tên hiển thị, vd "Phục vụ bàn"
    keywords: List[str]              # từ khóa map từ job_title (có dấu/không dấu/tiếng Anh)
    question_bank: FnbQuestionBank   # ngân hàng câu hỏi theo nhóm năng lực
    fewshot: List[FnbFewshotExample]  # ví dụ hội thoại minh hoạ phong cách


# ---------------------------------------------------------------------------
# Hằng số text: hướng dẫn phong cách giao tiếp (3 bước theo đúng thứ tự)
# ---------------------------------------------------------------------------

COMMUNICATION_STYLE_GUIDE: str = """\
PHONG CÁCH GIAO TIẾP (bắt buộc tuân theo đúng 3 bước, đúng thứ tự):
1) Công nhận/đồng cảm: Mở đầu bằng một câu ghi nhận ấm áp, chân thành với điều \
ứng viên vừa chia sẻ (ví dụ: ghi nhận nỗ lực, sự cố gắng, hoặc cảm xúc của họ). \
Tránh khen sáo rỗng; thể hiện bạn thật sự lắng nghe.
2) Diễn giải lại ý (lắng nghe phản chiếu): Tóm tắt/diễn giải lại ngắn gọn ý chính \
trong câu trả lời gần nhất của ứng viên bằng lời của bạn, để xác nhận đã hiểu đúng \
trước khi hỏi tiếp.
3) Câu hỏi đào sâu: Sau khi công nhận và diễn giải, đặt đúng MỘT câu hỏi đào sâu \
liên quan trực tiếp tới điều ứng viên vừa nói, nhằm khai thác thêm chi tiết, ví dụ \
cụ thể, hoặc cách họ xử lý tình huống.

Giữ giọng điệu tự nhiên, ấm áp như một quản lý/chủ quán F&B thực thụ; không máy móc, \
không lặp lại nguyên văn lời ứng viên.

CÁC QUY TẮC PHẢN HỒI NÂNG CAO (BẮT BUỘC):
- CẢM XÚC VÀ ĐỒNG CẢM SÂU SẮC (Empathy & Emotion): Hãy thể hiện cảm xúc chân thành, \
tự nhiên của một nhà tuyển dụng/quản lý F&B thực tế. Nếu ứng viên chia sẻ về những vất vả \
(ví dụ: ca làm mệt mỏi, khách hàng thô lỗ, áp lực giờ cao điểm), hãy bày tỏ sự thấu hiểu \
và đồng cảm sâu sắc (ví dụ: "Mình rất hiểu công việc F&B nhiều lúc rất vất vả...", "Rất đồng \
cảm với bạn về áp lực đó..."). Nếu ứng viên chia sẻ về thành tựu hay nỗ lực tốt, hãy bày tỏ \
sự nhiệt tình, khích lệ và tán thưởng (ví dụ: "Tuyệt vời quá!", "Đây là một điểm cộng rất lớn...").
- ĐÁP ỨNG YÊU CẦU GIAO TIẾP ĐƠN GIẢN (Handling conversational requests): Nếu ứng viên có \
yêu cầu đơn giản như nhờ nói lại/lặp lại câu hỏi ("nói lại câu hỏi giúp tôi", "chưa nghe rõ lắm"), \
giải thích thêm ("giải thích giúp tôi câu này"), hoặc đổi câu hỏi ("hỏi câu khác đi", "bỏ qua câu này"), \
bạn phải lập tức thực hiện yêu cầu của họ một cách lịch sự, thân thiện thay vì bỏ qua và đi tiếp kịch bản.
- PHÁT HIỆN & ĐIỀU CHỈNH KHI ỨNG VIÊN DÙNG AI (AI-assisted response detection): Nếu câu trả lời \
của ứng viên quá dài dòng, có cấu trúc gạch đầu dòng tự động hoàn hảo, dùng ngôn từ chatbot học thuật \
khuôn mẫu hoặc các cụm từ đệm máy móc (ví dụ: "Với tư cách là một...", "Để giải quyết vấn đề này..."), \
hãy phát hiện ngay và điều chỉnh bằng cách đặt một câu hỏi đào sâu cực kỳ cụ thể về trải nghiệm thực tế \
của họ (ví dụ: "Câu trả lời của bạn nghe rất lý thuyết và bài bản. Hãy chia sẻ một tình huống thực tế \
cụ thể bạn đã trực tiếp xử lý tại quán để chứng minh điều này được không?").
- PHÁT HIỆN & XỬ LÝ NGÔN TỪ KHÔNG CHUẨN MỰC, THIẾU ĐẠO ĐỨC (Inappropriate/Unethical speech): \
Nếu ứng viên dùng từ ngữ thô tục, vô lễ hoặc chia sẻ các hành vi vi phạm đạo đức nghề nghiệp (ăn cắp tiền, \
phá hoại, trả thù khách hàng/đồng nghiệp), hãy giữ sự điềm tĩnh và chuyên nghiệp tuyệt đối, nhắc nhở nhẹ nhàng \
hoặc khéo léo hướng câu chuyện về chủ đề phỏng vấn chính mà không tỏ ra nóng giận hay đôi co."""


# ---------------------------------------------------------------------------
# Hằng số text: rubric chấm điểm theo 4 trục năng lực (khớp InterviewReport)
# ---------------------------------------------------------------------------

SCORING_RUBRIC: str = """\
RUBRIC CHẤM ĐIỂM (mỗi trục cho điểm số nguyên 0–100):

1) past_experience_score — Kinh nghiệm làm việc ngành F&B:
   - 0–39: Hầu như không có kinh nghiệm liên quan, mô tả mơ hồ.
   - 40–69: Có một số kinh nghiệm liên quan nhưng còn hạn chế hoặc chưa rõ vai trò.
   - 70–100: Kinh nghiệm phong phú, đúng vị trí, nêu được ví dụ cụ thể và kết quả.

2) situation_handling_score — Giải quyết và xử lý tình huống thực tế:
   - 0–39: Lúng túng, không đưa ra hướng xử lý hợp lý.
   - 40–69: Xử lý được tình huống cơ bản nhưng thiếu chủ động hoặc chiều sâu.
   - 70–100: Bình tĩnh, có quy trình rõ ràng, ưu tiên trải nghiệm khách hàng, linh hoạt.

3) operations_score — Kiến thức quy trình vận hành F&B và tác phong làm việc:
   - 0–39: Không nắm quy trình/vệ sinh an toàn thực phẩm, tác phong yếu.
   - 40–69: Hiểu quy trình cơ bản, tác phong ổn nhưng cần nhắc nhở.
   - 70–100: Thành thạo quy trình, ý thức vệ sinh ATTP cao, tác phong chuyên nghiệp.

4) custom_questions_score — Trả lời các câu hỏi riêng từ Employer:
   - 0–39: Trả lời lạc đề hoặc không đáp ứng yêu cầu riêng.
   - 40–69: Đáp ứng phần nào nhưng chưa đầy đủ hoặc thiếu thuyết phục.
   - 70–100: Trả lời sát yêu cầu, thuyết phục, thể hiện sự phù hợp với cửa hàng.

Yêu cầu: cho điểm khách quan, nhất quán dựa trên bằng chứng trong câu trả lời; \
tránh thiên lệch; giải thích ngắn gọn điểm mạnh/điểm yếu tương ứng từng trục."""


# ---------------------------------------------------------------------------
# Vị trí fallback mặc định — phải là một FnbRole hợp lệ
# ---------------------------------------------------------------------------

GENERIC_FALLBACK_ROLE: FnbRole = {
    "id": "generic_fnb",
    "name": "Nhân viên F&B",
    "keywords": ["nhan vien f&b", "nhân viên f&b", "fnb staff", "f&b", "nhan vien", "nhân viên"],
    "question_bank": {
        "experience": [
            "Bạn đã từng làm công việc nào trong ngành F&B chưa? Hãy kể về vai trò gần nhất của bạn.",
            "Điều gì khiến bạn muốn gắn bó với công việc trong ngành nhà hàng/quán ăn?",
        ],
        "situation": [
            "Khi quán đông khách và bạn bị quá tải, bạn xử lý thế nào để vẫn phục vụ tốt?",
            "Nếu một khách hàng phàn nàn về món ăn hoặc dịch vụ, bạn sẽ làm gì?",
        ],
        "operations": [
            "Bạn hiểu thế nào về quy trình làm việc theo ca và bàn giao ca?",
            "Bạn giữ gìn vệ sinh khu vực làm việc và an toàn thực phẩm như thế nào?",
        ],
        "hygiene": [
            "Bạn thực hiện những bước nào để đảm bảo vệ sinh an toàn thực phẩm hằng ngày?",
        ],
        "teamwork": [
            "Hãy kể một lần bạn phối hợp với đồng nghiệp để hoàn thành công việc trong giờ cao điểm.",
        ],
        "service_attitude": [
            "Với bạn, một dịch vụ làm khách hàng hài lòng cần những yếu tố gì?",
        ],
    },
    "fewshot": [
        {
            "question": "Bạn đã từng làm công việc nào trong ngành F&B chưa? Hãy kể về vai trò gần nhất của bạn.",
            "answers": {
                "good": {
                    "text": "Em từng làm phục vụ ở một quán cà phê gần 1 năm, vừa order vừa hỗ trợ pha chế khi đông khách.",
                    "ai_reply": "Cảm ơn em đã chia sẻ, gần một năm gắn bó là một quá trình đáng quý. Vậy là em vừa quen với việc order vừa linh hoạt hỗ trợ pha chế lúc cao điểm. Em có thể kể một tình huống cụ thể mà em phải xoay xở giữa hai việc đó cùng lúc không?",
                },
                "fair": {
                    "text": "Em có làm thêm vài chỗ nhưng không lâu, chủ yếu là bưng bê thôi.",
                    "ai_reply": "Cảm ơn em đã thành thật chia sẻ. Vậy là em đã có trải nghiệm thực tế ở khâu bưng bê và phục vụ tại bàn. Trong những lần làm đó, công việc nào khiến em thấy mình làm tốt nhất?",
                },
                "weak": {
                    "text": "Dạ em chưa làm bao giờ.",
                    "ai_reply": "Không sao đâu, ai cũng có lần đầu và em chủ động ứng tuyển là điều rất đáng khích lệ. Vậy là đây sẽ là công việc F&B đầu tiên của em. Điều gì ở công việc này khiến em muốn thử sức và sẵn sàng học hỏi?",
                },
            },
        },
        {
            "question": "Khi quán đông khách và bạn bị quá tải, bạn xử lý thế nào để vẫn phục vụ tốt?",
            "answers": {
                "good": {
                    "text": "Bạn có thể nói lại câu hỏi được không? Mình nghe chưa rõ lắm.",
                    "ai_reply": "Tất nhiên rồi bạn, mình sẵn lòng nhắc lại câu hỏi nhé. Câu hỏi của mình là: Khi quán rơi vào giờ cao điểm, khách xếp hàng rất đông và bạn bị quá tải công việc, bạn sẽ xử lý tình huống đó thế nào để vẫn đảm bảo phục vụ khách chu đáo?",
                },
                "fair": {
                    "text": "Cũng mệt mỏi lắm bạn ơi, quán đông là chạy muốn xỉu luôn á.",
                    "ai_reply": "Mình rất hiểu và đồng cảm với em, giờ cao điểm trong ngành F&B thực sự rất vất vả và tốn nhiều sức lực. Tuy ca làm mệt mỏi là vậy, nhưng để giữ hình ảnh quán tốt, em thường ưu tiên làm việc gì trước để ca làm bớt rối?",
                },
                "weak": {
                    "text": "Với tư cách là nhân viên F&B chuyên nghiệp, tôi sẽ: 1. Đánh giá tình hình... 2. Phân loại thứ tự ưu tiên... 3. Giữ bình tĩnh... 4. Giao tiếp hiệu quả... Nhìn chung, việc duy trì quy trình là chìa khóa cốt lõi.",
                    "ai_reply": "Cảm ơn câu trả lời rất chi tiết và bài bản của bạn. Tuy nhiên, nội dung này nghe hơi giống câu trả lời lý thuyết từ AI. Bạn có thể chia sẻ một trải nghiệm thực tế mà bạn đã từng trực tiếp xoay xở khi quán đông khách ở chỗ làm cũ không?",
                },
            },
        },
        {
            "question": "Nếu một khách hàng phàn nàn về món ăn hoặc dịch vụ, bạn sẽ làm gì?",
            "answers": {
                "good": {
                    "text": "Khách mà nói nhiều hoặc phàn nàn vớ vẩn thì em chửi lại luôn chứ sợ gì, hoặc em kệ họ thích làm gì thì làm.",
                    "ai_reply": "Cảm ơn bạn đã thẳng thắn chia sẻ cảm xúc bộc phát của mình. Mình hiểu khi đối mặt với khách hàng khó tính thì rất dễ gây ức chế. Tuy nhiên, giữ thái độ chuyên nghiệp là bắt buộc trong dịch vụ. Nếu bình tĩnh lại, bạn nghĩ có cách xử lý nào khéo léo hơn mà không làm ảnh hưởng đến quán không?",
                },
                "fair": {
                    "text": "Giải thích rõ hơn câu hỏi này được không bạn?",
                    "ai_reply": "Rất sẵn lòng giải thích thêm để bạn rõ hơn nhé. Ý mình là: Trong quá trình làm việc, nếu xảy ra trường hợp khách hàng trực tiếp phàn nàn với bạn rằng món ăn/nước uống không ngon, có tóc hoặc phục vụ quá chậm, bạn sẽ phản ứng và xử lý cụ thể thế nào?",
                },
                "weak": {
                    "text": "Kệ khách thôi, bếp làm sao thì em bưng ra vậy.",
                    "ai_reply": "Cảm ơn em đã chia sẻ thật. Mình hiểu là phục vụ đôi khi chỉ bưng bê theo đồ của bếp. Tuy nhiên, là người trực tiếp tiếp xúc với khách, nếu khách không hài lòng thì uy tín quán sẽ bị ảnh hưởng. Theo em, mình nên làm gì để hỗ trợ kết nối giữa khách hàng và bếp trong lúc đó?",
                },
            },
        },
    ],
}


# ---------------------------------------------------------------------------
# Danh sách vị trí F&B — đúng 23 vị trí, theo 6 nhóm (Requirement 1.8, 1.9)
#
# Các nhóm:
#   - Front of house : waiter, host, cashier, order_taker, food_runner, banquet_setup
#   - Pha chế & bar  : barista, bartender, bar_back
#   - Bếp            : kitchen_assistant, cook, head_chef, pastry_chef, prep_cook
#   - Vệ sinh & hỗ trợ: cleaner, dishwasher, warehouse_assistant, security
#   - Giao hàng       : shipper, takeaway_packer
#   - Quản lý & giám sát: shift_leader, store_manager, area_supervisor
#
# Mỗi role: keywords gồm ít nhất một biến thể tiếng Việt CÓ DẤU, tiếng Việt
# KHÔNG DẤU và tiếng Anh; question_bank đủ 6 nhóm năng lực; fewshot có ví dụ
# hội thoại với ai_reply theo phong cách 3 bước (công nhận → diễn giải → đào sâu).
# ---------------------------------------------------------------------------

FNB_ROLES: List[FnbRole] = [
    # ===================== FRONT OF HOUSE =====================
    {
        "id": "waiter",
        "name": "Phục vụ bàn",
        "keywords": ["phục vụ bàn", "phục vụ", "phuc vu ban", "phuc vu", "waiter", "waitress", "server"],
        "question_bank": {
            "experience": [
                "Bạn đã từng làm phục vụ bàn ở đâu, trong bao lâu và quy mô quán thế nào?",
                "Kể về một ca làm bận rộn nhất mà bạn từng phục vụ và cách bạn xoay xở.",
            ],
            "situation": [
                "Khi bạn bưng nhầm món cho khách, bạn xử lý ra sao?",
                "Một bàn khách gọi mãi mà bếp ra món chậm, bạn nói gì với khách?",
            ],
            "operations": [
                "Bạn nắm quy trình nhận order và chuyển bếp như thế nào?",
                "Bạn set up và dọn bàn theo trình tự nào để nhanh và sạch?",
            ],
            "hygiene": [
                "Bạn giữ vệ sinh khu vực bàn và dụng cụ ăn uống như thế nào trong ca?",
            ],
            "teamwork": [
                "Khi đông khách, bạn phối hợp với chạy món và thu ngân ra sao?",
            ],
            "service_attitude": [
                "Với bạn, thế nào là một lần phục vụ khiến khách muốn quay lại?",
            ],
        },
        "fewshot": [
            {
                "question": "Kể về một ca làm bận rộn nhất mà bạn từng phục vụ và cách bạn xoay xở.",
                "answers": {
                    "good": {
                        "text": "Tối cuối tuần kín bàn, em chia khu vực, ưu tiên ghi order nhanh rồi báo bếp thứ tự ưu tiên, vừa để mắt bàn nào cần nước.",
                        "ai_reply": "Cảm ơn em, nghe cách em mô tả là thấy em quen với áp lực giờ cao điểm. Vậy là em chủ động chia khu vực và sắp xếp thứ tự ưu tiên để không bỏ sót bàn nào. Lúc đó nếu có hai bàn cùng cần em một lúc, em quyết định phục vụ bàn nào trước dựa vào điều gì?",
                    },
                    "fair": {
                        "text": "Đông thì em cũng cố chạy cho kịp thôi, nhiều lúc cũng rối.",
                        "ai_reply": "Em chia sẻ thật lòng như vậy là tốt, giờ cao điểm rối là chuyện ai cũng gặp. Vậy là em vẫn cố gắng chạy cho kịp dù đôi lúc quá tải. Em có cách nào để tự nhắc mình việc nào làm trước việc nào làm sau không?",
                    },
                    "weak": {
                        "text": "Em chưa làm ca đông bao giờ.",
                        "ai_reply": "Không sao đâu em, ai cũng có lần đầu tiên. Vậy là em chưa trải nghiệm ca thật đông khách. Nếu hình dung một tối kín bàn, em nghĩ mình sẽ ưu tiên làm gì trước để không bị cuống?",
                    },
                },
            },
        ],
    },
    {
        "id": "host",
        "name": "Lễ tân / Đón khách",
        "keywords": ["lễ tân", "đón khách", "le tan", "don khach", "host", "hostess", "greeter", "receptionist"],
        "question_bank": {
            "experience": [
                "Bạn từng đón khách ở nhà hàng/quán nào và lượng khách mỗi ca khoảng bao nhiêu?",
                "Bạn quản lý việc xếp bàn và danh sách chờ như thế nào?",
            ],
            "situation": [
                "Khi hết bàn mà khách vẫn tới đông, bạn xử lý hàng chờ ra sao?",
                "Một khách đặt bàn nhưng quán ghi nhầm giờ, bạn làm gì?",
            ],
            "operations": [
                "Bạn tiếp nhận đặt bàn qua điện thoại và sắp xếp sơ đồ bàn thế nào?",
                "Bạn bàn giao thông tin khách đặc biệt (sinh nhật, dị ứng) cho phục vụ ra sao?",
            ],
            "hygiene": [
                "Bạn giữ khu vực quầy đón và thực đơn sạch sẽ, gọn gàng thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với phục vụ để điều phối khách vào bàn nhịp nhàng ra sao?",
            ],
            "service_attitude": [
                "Ấn tượng đầu tiên với khách quan trọng thế nào và bạn tạo nó bằng cách nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Khi hết bàn mà khách vẫn tới đông, bạn xử lý hàng chờ ra sao?",
                "answers": {
                    "good": {
                        "text": "Em chào khách, báo thời gian chờ ước lượng, ghi tên và số người, mời khách ngồi khu chờ và cập nhật khi sắp có bàn.",
                        "ai_reply": "Cảm ơn em, cách em làm rất chuyên nghiệp và quan tâm tới cảm giác của khách. Vậy là em chủ động báo thời gian chờ và giữ liên lạc để khách yên tâm. Khi thời gian chờ kéo dài hơn dự kiến, em sẽ nói gì để khách không khó chịu?",
                    },
                    "fair": {
                        "text": "Em bảo khách đợi chút rồi khi nào có bàn thì gọi.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Vậy là em có mời khách đợi và gọi khi có bàn. Theo em, nếu báo thêm khoảng thời gian chờ cụ thể thì khách sẽ cảm thấy thế nào?",
                    },
                    "weak": {
                        "text": "Hết bàn thì thôi chứ biết sao giờ.",
                        "ai_reply": "Em thẳng thắn như vậy cũng được, tình huống này đúng là khó. Vậy là khi hết bàn em thấy hơi bí cách xử lý. Em thử nghĩ xem có cách nào để khách vẫn muốn ở lại chờ thay vì bỏ đi không?",
                    },
                },
            },
        ],
    },
    {
        "id": "cashier",
        "name": "Thu ngân",
        "keywords": ["thu ngân", "thu ngan", "cashier", "checkout"],
        "question_bank": {
            "experience": [
                "Bạn từng làm thu ngân với phần mềm bán hàng (POS) nào?",
                "Mỗi ca bạn xử lý khoảng bao nhiêu hoá đơn và giá trị tiền mặt thế nào?",
            ],
            "situation": [
                "Khi cuối ca tiền không khớp sổ, bạn xử lý ra sao?",
                "Khách thắc mắc hoá đơn tính sai, bạn làm gì?",
            ],
            "operations": [
                "Bạn thực hiện quy trình mở ca, đối soát và kết ca thế nào?",
                "Bạn xử lý các hình thức thanh toán (tiền mặt, thẻ, ví điện tử) ra sao?",
            ],
            "hygiene": [
                "Bạn giữ khu vực quầy thu ngân sạch sẽ, gọn gàng như thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với phục vụ và quản lý khi có sai sót hoá đơn ra sao?",
            ],
            "service_attitude": [
                "Làm sao để khâu thanh toán nhanh mà khách vẫn thấy thoải mái?",
            ],
        },
        "fewshot": [
            {
                "question": "Khi cuối ca tiền không khớp sổ, bạn xử lý ra sao?",
                "answers": {
                    "good": {
                        "text": "Em đối soát lại từng hoá đơn và phiếu, kiểm tra giao dịch huỷ/hoàn, nếu vẫn lệch em báo quản lý và ghi nhận minh bạch.",
                        "ai_reply": "Cảm ơn em, cách làm của em cho thấy sự cẩn thận và trung thực rất cần ở vị trí thu ngân. Vậy là em rà soát có hệ thống rồi báo minh bạch khi cần. Đã có lần nào em phát hiện ra nguyên nhân lệch tiền và rút kinh nghiệm gì không?",
                    },
                    "fair": {
                        "text": "Em đếm lại tiền vài lần, nếu vẫn lệch thì báo quản lý.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Vậy là em có kiểm lại và báo quản lý khi cần. Ngoài đếm tiền, em nghĩ còn chỗ nào hay gây lệch mà mình nên kiểm tra thêm không?",
                    },
                    "weak": {
                        "text": "Lệch ít thì em bù vào cho đủ thôi.",
                        "ai_reply": "Cảm ơn em đã nói thật. Mình hiểu là em muốn cho nhanh gọn. Tuy nhiên việc đối soát rõ ràng lại rất quan trọng, em thử nghĩ xem nếu báo và truy nguyên nhân thì sẽ có lợi gì cho cả em và quán?",
                    },
                },
            },
        ],
    },
    {
        "id": "order_taker",
        "name": "Nhân viên order",
        "keywords": ["nhân viên order", "ghi order", "nhan vien order", "ghi order", "order taker", "order"],
        "question_bank": {
            "experience": [
                "Bạn từng ghi order tại bàn hay tại quầy, dùng máy POS hay phiếu giấy?",
                "Bạn xử lý thực đơn nhiều món, nhiều tuỳ chọn (size, topping) như thế nào?",
            ],
            "situation": [
                "Khách đổi món liên tục sau khi đã gọi, bạn xử lý ra sao để bếp không nhầm?",
                "Khu vực ồn ào nghe không rõ yêu cầu của khách, bạn làm gì?",
            ],
            "operations": [
                "Bạn xác nhận lại order với khách theo trình tự nào để tránh sai sót?",
                "Bạn ghi chú yêu cầu đặc biệt (ít đường, dị ứng) và báo bếp thế nào?",
            ],
            "hygiene": [
                "Bạn giữ thiết bị ghi order và khu vực làm việc sạch sẽ ra sao?",
            ],
            "teamwork": [
                "Bạn phối hợp với phục vụ và bếp để order được xử lý đúng thứ tự thế nào?",
            ],
            "service_attitude": [
                "Bạn gợi ý món (upsell) thế nào mà khách vẫn thấy được tư vấn chứ không bị ép?",
            ],
        },
        "fewshot": [
            {
                "question": "Khách đổi món liên tục sau khi đã gọi, bạn xử lý ra sao để bếp không nhầm?",
                "answers": {
                    "good": {
                        "text": "Em xác nhận lại order mới nhất với khách, gạch món cũ rõ ràng và báo bếp ngay nếu món chưa làm, tránh để bếp làm trùng.",
                        "ai_reply": "Cảm ơn em, em rất tinh ý khi nghĩ tới việc tránh bếp làm trùng. Vậy là em luôn chốt lại order mới và báo bếp kịp thời. Nếu món cũ đã bắt đầu chế biến rồi thì em sẽ trao đổi với khách và bếp như thế nào?",
                    },
                    "fair": {
                        "text": "Em sửa lại trên máy rồi báo bếp món mới.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Vậy là em cập nhật trên hệ thống và báo bếp. Theo em, làm sao để chắc chắn bếp thấy được phần thay đổi chứ không bỏ sót?",
                    },
                    "weak": {
                        "text": "Khách đổi thì em ghi lại thôi chứ cũng không để ý nhiều.",
                        "ai_reply": "Cảm ơn em đã thành thật. Mình hiểu là lúc đông sẽ dễ bỏ qua. Em thử nghĩ xem nếu không xác nhận kỹ thì điều gì có thể xảy ra với bếp và với khách?",
                    },
                },
            },
        ],
    },
    {
        "id": "food_runner",
        "name": "Chạy món",
        "keywords": ["chạy món", "chạy bàn", "chay mon", "chay ban", "food runner", "runner"],
        "question_bank": {
            "experience": [
                "Bạn từng chạy món ở quán quy mô thế nào, bao nhiêu bàn một ca?",
                "Bạn nhớ và giao đúng món tới đúng bàn bằng cách nào khi đông khách?",
            ],
            "situation": [
                "Khi bếp ra món dồn dập cùng lúc, bạn ưu tiên mang món nào trước?",
                "Mang món ra mà khách báo không phải món họ gọi, bạn xử lý ra sao?",
            ],
            "operations": [
                "Bạn kiểm tra món trước khi mang ra bàn theo những tiêu chí nào?",
                "Bạn phối hợp với bếp về thứ tự ra món thế nào?",
            ],
            "hygiene": [
                "Bạn cầm nắm dĩa/đồ ăn đúng cách để đảm bảo vệ sinh ra sao?",
            ],
            "teamwork": [
                "Bạn phối hợp với phục vụ bàn để không bị chồng chéo khi mang món thế nào?",
            ],
            "service_attitude": [
                "Khi đặt món xuống bàn, bạn nói và làm gì để khách thấy được chăm sóc?",
            ],
        },
        "fewshot": [
            {
                "question": "Khi bếp ra món dồn dập cùng lúc, bạn ưu tiên mang món nào trước?",
                "answers": {
                    "good": {
                        "text": "Em ưu tiên món nóng và món dễ nguội trước, đi theo cụm bàn gần nhau để tiết kiệm lượt, vừa đi vừa nhớ bàn nào đã đủ món.",
                        "ai_reply": "Cảm ơn em, cách em tính toán đường đi và ưu tiên món nóng cho thấy em làm việc rất có đầu óc. Vậy là em sắp xếp theo cụm bàn và độ ưu tiên của món. Khi có món cần ăn ngay nhưng bàn lại xa, em cân nhắc thế nào?",
                    },
                    "fair": {
                        "text": "Món nào ra trước em mang trước thôi.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Vậy là em đi theo thứ tự món ra. Em nghĩ với món nóng cần ăn liền thì có nên ưu tiên hơn một chút không?",
                    },
                    "weak": {
                        "text": "Cái nào gần tay thì em bưng.",
                        "ai_reply": "Cảm ơn em đã nói thẳng. Mình hiểu lúc gấp thì hay làm vậy. Em thử nghĩ xem nếu món nóng để lâu bị nguội thì khách sẽ cảm thấy thế nào nhỉ?",
                    },
                },
            },
        ],
    },
    {
        "id": "banquet_setup",
        "name": "Set up bàn tiệc",
        "keywords": ["set up bàn tiệc", "set up tiệc", "set up ban tiec", "set up tiec", "banquet setup", "banquet", "event setup"],
        "question_bank": {
            "experience": [
                "Bạn từng set up tiệc quy mô bao nhiêu khách và loại tiệc gì?",
                "Bạn chuẩn bị sơ đồ bàn và dụng cụ theo yêu cầu sự kiện như thế nào?",
            ],
            "situation": [
                "Sát giờ tiệc mà khách đổi số lượng bàn, bạn xoay xở ra sao?",
                "Thiếu dụng cụ giữa lúc set up, bạn xử lý thế nào để kịp giờ?",
            ],
            "operations": [
                "Bạn set up bàn tiệc theo tiêu chuẩn (khăn, ly, dao dĩa) theo trình tự nào?",
                "Bạn kiểm tra lần cuối trước khi khách vào theo checklist gì?",
            ],
            "hygiene": [
                "Bạn đảm bảo dụng cụ và khăn bàn sạch sẽ, đúng vệ sinh trước tiệc thế nào?",
            ],
            "teamwork": [
                "Bạn phân chia công việc với nhóm để set up kịp tiến độ ra sao?",
            ],
            "service_attitude": [
                "Một không gian tiệc chỉn chu theo bạn cần chú ý những chi tiết nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Sát giờ tiệc mà khách đổi số lượng bàn, bạn xoay xở ra sao?",
                "answers": {
                    "good": {
                        "text": "Em báo nhóm trưởng, chia người bổ sung bàn và dụng cụ theo số mới, ưu tiên khu khách vào trước rồi hoàn thiện dần phần còn lại.",
                        "ai_reply": "Cảm ơn em, cách em bình tĩnh điều phối lại nhân lực rất đáng quý trong tình huống gấp. Vậy là em ưu tiên khu vực khách vào trước để kịp đón. Lúc đó em giữ liên lạc với nhóm như thế nào để mọi người không bị rối?",
                    },
                    "fair": {
                        "text": "Em cố làm thêm bàn cho kịp.",
                        "ai_reply": "Cảm ơn em đã chia sẻ tinh thần trách nhiệm đó. Vậy là em sẽ cố hoàn thành thêm bàn. Theo em, có nên báo nhóm trưởng để chia người cùng làm cho nhanh không?",
                    },
                    "weak": {
                        "text": "Đổi gấp vậy thì khó làm kịp lắm.",
                        "ai_reply": "Mình hiểu, đổi sát giờ đúng là rất áp lực. Vậy là em thấy khó xoay kịp một mình. Nếu có cả nhóm hỗ trợ, em nghĩ nên bắt đầu từ khu vực nào trước để kịp đón khách?",
                    },
                },
            },
        ],
    },
    # ===================== PHA CHẾ & BAR =====================
    {
        "id": "barista",
        "name": "Pha chế / Barista",
        "keywords": ["pha chế", "pha che", "barista", "pha chế đồ uống", "pha che do uong", "coffee maker"],
        "question_bank": {
            "experience": [
                "Bạn từng pha chế ở quán cà phê/trà sữa nào và thành thạo nhóm đồ uống gì?",
                "Bạn nhớ và pha chuẩn vị theo công thức quán như thế nào?",
            ],
            "situation": [
                "Khách báo đồ uống không đúng vị quen thuộc, bạn xử lý ra sao?",
                "Giờ cao điểm dồn nhiều order đồ uống, bạn sắp xếp pha thế nào cho kịp?",
            ],
            "operations": [
                "Bạn chuẩn bị nguyên liệu đầu ca (mise en place) gồm những gì?",
                "Bạn vệ sinh và hiệu chỉnh máy pha/định lượng theo quy trình nào?",
            ],
            "hygiene": [
                "Bạn bảo quản nguyên liệu (sữa, syrup, trái cây) đúng vệ sinh ATTP thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với order và phục vụ để trả đồ uống đúng và nhanh ra sao?",
            ],
            "service_attitude": [
                "Bạn làm gì để mỗi ly đồ uống vừa ngon vừa đẹp mắt cho khách?",
            ],
        },
        "fewshot": [
            {
                "question": "Giờ cao điểm dồn nhiều order đồ uống, bạn sắp xếp pha thế nào cho kịp?",
                "answers": {
                    "good": {
                        "text": "Em gom các món cùng loại để pha theo mẻ, chuẩn bị sẵn nguyên liệu, ưu tiên món nhanh trước và bám theo thứ tự phiếu để không sót.",
                        "ai_reply": "Cảm ơn em, cách em gom mẻ và chuẩn bị trước cho thấy em hiểu rõ nhịp làm việc của quầy bar. Vậy là em tối ưu thao tác mà vẫn giữ đúng thứ tự. Khi có món phức tạp xen giữa nhiều món nhanh, em cân đối thế nào để không bàn nào phải đợi quá lâu?",
                    },
                    "fair": {
                        "text": "Em pha lần lượt theo phiếu cho khỏi nhầm.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Làm theo thứ tự phiếu giúp tránh nhầm là điểm tốt. Em nghĩ với các món giống nhau thì gom lại pha cùng lúc có giúp nhanh hơn không?",
                    },
                    "weak": {
                        "text": "Đông quá thì em pha đại cho nhanh.",
                        "ai_reply": "Mình hiểu lúc đông sẽ rất cuống. Vậy là em ưu tiên làm cho nhanh. Em thử nghĩ xem nếu vội mà sai vị thì mình lại mất thời gian pha lại, có cách nào vừa nhanh vừa chuẩn không?",
                    },
                },
            },
        ],
    },
    {
        "id": "bartender",
        "name": "Bartender",
        "keywords": ["pha chế rượu", "pha che ruou", "bartender", "nhân viên quầy bar", "nhan vien quay bar", "mixologist"],
        "question_bank": {
            "experience": [
                "Bạn từng làm bartender ở bar/pub nào và thành thạo nhóm cocktail gì?",
                "Bạn nắm công thức và kỹ thuật pha (shake, stir, layer) ra sao?",
            ],
            "situation": [
                "Khách đã uống nhiều và yêu cầu thêm đồ có cồn, bạn xử lý thế nào?",
                "Khách chê cocktail không đúng gu, bạn phản hồi ra sao?",
            ],
            "operations": [
                "Bạn set up quầy bar và kiểm kê rượu/nguyên liệu đầu-cuối ca thế nào?",
                "Bạn kiểm soát định lượng để chuẩn vị và tiết kiệm chi phí ra sao?",
            ],
            "hygiene": [
                "Bạn vệ sinh dụng cụ pha chế và quầy bar đúng tiêu chuẩn thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với phục vụ và bar back trong giờ cao điểm ra sao?",
            ],
            "service_attitude": [
                "Bạn tạo trải nghiệm và tương tác với khách tại quầy bar như thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Khách đã uống nhiều và yêu cầu thêm đồ có cồn, bạn xử lý thế nào?",
                "answers": {
                    "good": {
                        "text": "Em quan sát mức độ của khách, khéo léo mời nước hoặc đồ nhẹ, nếu cần thì báo quản lý để đảm bảo an toàn cho khách và quán.",
                        "ai_reply": "Cảm ơn em, em ý thức được trách nhiệm và an toàn cho khách, đó là phẩm chất rất quan trọng của một bartender. Vậy là em chọn cách khéo léo thay vì từ chối thẳng. Em thường nói thế nào để khách không cảm thấy bị mất lòng?",
                    },
                    "fair": {
                        "text": "Em vẫn phục vụ nhưng để ý chừng khách.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Việc để ý chừng khách là tốt. Theo em, đến mức nào thì mình nên chủ động mời nước hoặc báo quản lý?",
                    },
                    "weak": {
                        "text": "Khách gọi thì em cứ làm thôi.",
                        "ai_reply": "Cảm ơn em đã nói thật. Mình hiểu là chiều khách cũng quan trọng. Nhưng em thử nghĩ xem nếu khách quá chén rồi xảy ra chuyện thì trách nhiệm của quán sẽ thế nào?",
                    },
                },
            },
        ],
    },
    {
        "id": "bar_back",
        "name": "Phụ pha chế (Bar back)",
        "keywords": ["phụ pha chế", "phu pha che", "bar back", "barback", "phụ quầy bar", "phu quay bar"],
        "question_bank": {
            "experience": [
                "Bạn từng hỗ trợ quầy bar/pha chế ở đâu và làm những việc gì?",
                "Bạn chuẩn bị nguyên liệu và tiếp ứng cho bartender/barista ra sao?",
            ],
            "situation": [
                "Giữa cao điểm hết đá/nguyên liệu, bạn xử lý nhanh thế nào?",
                "Bartender cần gấp nguyên liệu mà bạn đang dở việc khác, bạn ưu tiên ra sao?",
            ],
            "operations": [
                "Bạn sắp xếp, châm bổ sung nguyên liệu để quầy luôn sẵn sàng thế nào?",
                "Bạn theo dõi tồn nguyên liệu và báo bổ sung ra sao?",
            ],
            "hygiene": [
                "Bạn rửa, sấy dụng cụ và giữ khu vực bar sạch trong ca thế nào?",
            ],
            "teamwork": [
                "Bạn hỗ trợ bartender/barista nhịp nhàng trong giờ đông khách ra sao?",
            ],
            "service_attitude": [
                "Theo bạn, vai trò phụ bar góp phần vào trải nghiệm khách như thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Giữa cao điểm hết đá/nguyên liệu, bạn xử lý nhanh thế nào?",
                "answers": {
                    "good": {
                        "text": "Em luôn để ý mức tồn từ trước nên hiếm khi hết đột ngột; nếu sắp hết em đi lấy bổ sung ngay và báo bartender để chủ động.",
                        "ai_reply": "Cảm ơn em, em chủ động theo dõi tồn từ sớm thì rất đúng tinh thần của vị trí phụ bar. Vậy là em phòng trước thay vì để hết mới chạy. Em dựa vào dấu hiệu gì để biết khi nào cần đi châm thêm?",
                    },
                    "fair": {
                        "text": "Hết thì em chạy đi lấy thêm liền.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Phản ứng nhanh khi hết là tốt. Theo em, nếu để ý mức tồn từ trước thì có tránh được cảnh hết giữa cao điểm không?",
                    },
                    "weak": {
                        "text": "Em đợi bartender nhắc thì mới đi lấy.",
                        "ai_reply": "Cảm ơn em đã nói thật. Mình hiểu là em chờ chỉ dẫn cho chắc. Nhưng nếu em chủ động để ý trước thì bartender sẽ đỡ phải nhắc, em thấy mình làm được điều đó không?",
                    },
                },
            },
        ],
    },
    # ===================== BẾP =====================
    {
        "id": "kitchen_assistant",
        "name": "Phụ bếp",
        "keywords": ["phụ bếp", "phu bep", "kitchen assistant", "kitchen helper", "phụ việc bếp", "phu viec bep"],
        "question_bank": {
            "experience": [
                "Bạn từng phụ bếp ở quán/nhà hàng nào và đảm nhận những việc gì?",
                "Bạn hỗ trợ đầu bếp trong khâu nào nhiều nhất (sơ chế, trình bày, dọn dẹp)?",
            ],
            "situation": [
                "Khi order dồn dập, bạn hỗ trợ bếp chính ưu tiên việc gì trước?",
                "Bạn làm gì khi phát hiện nguyên liệu sắp hết giữa ca?",
            ],
            "operations": [
                "Bạn chuẩn bị nguyên liệu và dụng cụ đầu ca theo trình tự nào?",
                "Bạn sắp xếp kho lạnh và nguyên liệu theo nguyên tắc nào (FIFO)?",
            ],
            "hygiene": [
                "Bạn thực hiện vệ sinh an toàn thực phẩm trong khu bếp như thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với đầu bếp và các bộ phận khác trong bếp ra sao?",
            ],
            "service_attitude": [
                "Theo bạn, sự tỉ mỉ của phụ bếp ảnh hưởng tới món ăn thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Bạn làm gì khi phát hiện nguyên liệu sắp hết giữa ca?",
                "answers": {
                    "good": {
                        "text": "Em báo ngay bếp chính và kiểm tra kho xem còn dự phòng không, đồng thời ghi chú để đề xuất nhập thêm cho ca sau.",
                        "ai_reply": "Cảm ơn em, em vừa xử lý tình huống vừa nghĩ tới ca sau, cho thấy em làm việc rất có trách nhiệm. Vậy là em báo bếp chính và chủ động kiểm kho. Em theo dõi mức nguyên liệu bằng cách nào để phát hiện sớm như vậy?",
                    },
                    "fair": {
                        "text": "Em báo bếp chính rồi chờ chỉ đạo.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Báo bếp chính kịp thời là đúng. Theo em, mình có thể kiểm kho trước để báo luôn còn bao nhiêu cho bếp chính dễ quyết không?",
                    },
                    "weak": {
                        "text": "Hết thì thôi chứ em đâu quyết được.",
                        "ai_reply": "Mình hiểu, việc nhập hàng đúng là không phải em quyết. Nhưng nếu em báo sớm thì bếp chính sẽ xoay kịp, em thấy mình có thể chủ động báo được không?",
                    },
                },
            },
        ],
    },
    {
        "id": "cook",
        "name": "Đầu bếp / Bếp chính",
        "keywords": ["đầu bếp", "bếp chính", "dau bep", "bep chinh", "cook", "chef", "line cook"],
        "question_bank": {
            "experience": [
                "Bạn nấu chính ở nhóm món nào và từng đứng bếp quán quy mô ra sao?",
                "Bạn đảm bảo món ra đều vị và đúng định lượng như thế nào?",
            ],
            "situation": [
                "Giờ cao điểm nhiều order cùng lúc, bạn điều phối nấu ra sao để món ra kịp và nóng?",
                "Khách trả món vì chưa đạt, bạn xử lý thế nào?",
            ],
            "operations": [
                "Bạn quản lý mise en place và định lượng để giữ chuẩn vị ra sao?",
                "Bạn kiểm soát nhiệt độ và thời gian nấu cho từng món thế nào?",
            ],
            "hygiene": [
                "Bạn đảm bảo an toàn thực phẩm và phòng nhiễm chéo trong lúc nấu thế nào?",
            ],
            "teamwork": [
                "Bạn điều phối phụ bếp và phối hợp với phục vụ ra món ra sao?",
            ],
            "service_attitude": [
                "Theo bạn, sự ổn định chất lượng món ăn quan trọng với khách thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Giờ cao điểm nhiều order cùng lúc, bạn điều phối nấu ra sao để món ra kịp và nóng?",
                "answers": {
                    "good": {
                        "text": "Em đọc phiếu theo cụm, sắp món có thời gian nấu giống nhau làm song song, canh để các món cùng bàn ra gần nhau, ưu tiên món lâu nấu trước.",
                        "ai_reply": "Cảm ơn anh/em, cách sắp xếp song song và canh món cùng bàn ra cùng lúc cho thấy tay nghề điều phối rất chắc. Vậy là bạn tối ưu cả thời gian lẫn trải nghiệm khách. Khi một món lỡ hỏng phải làm lại, bạn điều chỉnh thứ tự thế nào để bàn đó không đợi quá lâu?",
                    },
                    "fair": {
                        "text": "Em cố nấu nhanh hết sức cho kịp.",
                        "ai_reply": "Cảm ơn bạn đã chia sẻ tinh thần đó. Nấu nhanh là cần, nhưng theo bạn nếu sắp xếp món cùng bàn ra gần nhau thì khách có hài lòng hơn không?",
                    },
                    "weak": {
                        "text": "Phiếu nào tới trước em làm trước thôi.",
                        "ai_reply": "Mình hiểu làm theo thứ tự cho khỏi rối. Nhưng bạn thử nghĩ xem nếu hai món cùng bàn ra cách nhau quá xa thì khách sẽ cảm thấy thế nào?",
                    },
                },
            },
        ],
    },
    {
        "id": "head_chef",
        "name": "Bếp trưởng",
        "keywords": ["bếp trưởng", "bep truong", "head chef", "executive chef", "trưởng bếp", "truong bep"],
        "question_bank": {
            "experience": [
                "Bạn từng quản lý bếp quy mô bao nhiêu người và bao nhiêu món?",
                "Bạn xây dựng/định chuẩn công thức và kiểm soát chất lượng ra sao?",
            ],
            "situation": [
                "Khi một nhân sự bếp nghỉ đột xuất giờ cao điểm, bạn điều phối thế nào?",
                "Chi phí nguyên liệu tăng, bạn cân đối chất lượng và giá vốn ra sao?",
            ],
            "operations": [
                "Bạn lập thực đơn, định lượng và kiểm soát giá vốn (food cost) thế nào?",
                "Bạn tổ chức quy trình bếp và phân ca cho đội ngũ ra sao?",
            ],
            "hygiene": [
                "Bạn thiết lập và giám sát tiêu chuẩn vệ sinh ATTP cho cả bếp thế nào?",
            ],
            "teamwork": [
                "Bạn đào tạo, phân công và tạo động lực cho đội bếp ra sao?",
            ],
            "service_attitude": [
                "Bạn giữ sự ổn định chất lượng món qua các ca và các đầu bếp khác nhau thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Khi một nhân sự bếp nghỉ đột xuất giờ cao điểm, bạn điều phối thế nào?",
                "answers": {
                    "good": {
                        "text": "Em đánh giá nhanh vị trí trống, phân lại việc theo thế mạnh từng người, tự nhảy vào hỗ trợ khâu nghẽn và rút gọn thao tác không cần thiết để giữ tốc độ ra món.",
                        "ai_reply": "Cảm ơn anh/chị, cách điều phối theo thế mạnh và sẵn sàng nhảy vào khâu nghẽn cho thấy tố chất lãnh đạo bếp rất rõ. Vậy là bạn vừa giữ tốc độ vừa giữ tinh thần đội. Sau ca đó, bạn làm gì để lần sau chủ động hơn với tình huống thiếu người?",
                    },
                    "fair": {
                        "text": "Em chia bớt việc cho người còn lại rồi cùng làm.",
                        "ai_reply": "Cảm ơn bạn đã chia sẻ. Chia việc và cùng làm là hợp lý. Theo bạn, nên phân theo thế mạnh từng người thế nào để khâu quan trọng không bị nghẽn?",
                    },
                    "weak": {
                        "text": "Thiếu người thì đành chịu chậm thôi.",
                        "ai_reply": "Mình hiểu thiếu người giữa cao điểm là rất khó. Nhưng ở vai trò bếp trưởng, bạn thử nghĩ xem có cách phân bổ nào để giảm bớt độ chậm cho khách không?",
                    },
                },
            },
        ],
    },
    {
        "id": "pastry_chef",
        "name": "Bếp bánh / Thợ làm bánh",
        "keywords": ["bếp bánh", "thợ làm bánh", "làm bánh", "bep banh", "tho lam banh", "lam banh", "pastry chef", "baker"],
        "question_bank": {
            "experience": [
                "Bạn từng làm nhóm bánh nào (bánh ngọt, bánh mì, bánh kem) và ở đâu?",
                "Bạn đảm bảo bánh ổn định về vị và hình thức qua từng mẻ thế nào?",
            ],
            "situation": [
                "Mẻ bánh không đạt (nở kém, cháy), bạn xử lý và tránh lặp lại ra sao?",
                "Đơn đặt bánh gấp số lượng lớn, bạn sắp xếp sản xuất kịp thế nào?",
            ],
            "operations": [
                "Bạn cân đong nguyên liệu và kiểm soát nhiệt độ/thời gian nướng ra sao?",
                "Bạn bảo quản bán thành phẩm và thành phẩm đúng cách thế nào?",
            ],
            "hygiene": [
                "Bạn giữ vệ sinh khu làm bánh và an toàn thực phẩm thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với bếp và quầy bán để cung ứng bánh kịp thời ra sao?",
            ],
            "service_attitude": [
                "Sự tỉ mỉ và thẩm mỹ trong làm bánh theo bạn quan trọng thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Mẻ bánh không đạt (nở kém, cháy), bạn xử lý và tránh lặp lại ra sao?",
                "answers": {
                    "good": {
                        "text": "Em rà lại công thức, nhiệt độ lò và thời gian, ghi nhật ký mẻ để tìm nguyên nhân, điều chỉnh và làm mẻ kiểm tra trước khi sản xuất tiếp.",
                        "ai_reply": "Cảm ơn em, việc ghi nhật ký mẻ để truy nguyên nhân cho thấy em làm bánh rất khoa học. Vậy là em không chỉ sửa mà còn phòng lặp lại. Yếu tố nào em thấy hay gây ra mẻ hỏng nhất và em kiểm soát nó thế nào?",
                    },
                    "fair": {
                        "text": "Hỏng thì em làm lại mẻ khác cẩn thận hơn.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Làm lại cẩn thận hơn là tốt. Theo em, ghi lại thông số mỗi mẻ có giúp tìm đúng nguyên nhân để không hỏng lần nữa không?",
                    },
                    "weak": {
                        "text": "Bánh hỏng là chuyện thường, bỏ rồi làm lại thôi.",
                        "ai_reply": "Mình hiểu đôi khi mẻ hỏng khó tránh. Nhưng nếu mình tìm ra lý do cụ thể thì sẽ đỡ lãng phí nguyên liệu, em thử nghĩ xem thường là do khâu nào nhỉ?",
                    },
                },
            },
        ],
    },
    {
        "id": "prep_cook",
        "name": "Sơ chế",
        "keywords": ["sơ chế", "nhân viên sơ chế", "so che", "nhan vien so che", "prep cook", "food prep"],
        "question_bank": {
            "experience": [
                "Bạn từng sơ chế nhóm nguyên liệu nào (thịt, cá, rau củ) và ở đâu?",
                "Bạn đảm bảo sơ chế đúng định lượng và đạt yêu cầu của bếp ra sao?",
            ],
            "situation": [
                "Nguyên liệu nhập về không tươi như mong đợi, bạn xử lý thế nào?",
                "Khối lượng sơ chế lớn mà sắp tới giờ mở bán, bạn sắp xếp ra sao?",
            ],
            "operations": [
                "Bạn sơ chế và bảo quản theo nguyên tắc nào để giữ tươi và an toàn?",
                "Bạn dán nhãn, phân loại và lưu kho nguyên liệu thế nào (FIFO)?",
            ],
            "hygiene": [
                "Bạn phòng nhiễm chéo giữa thực phẩm sống và chín khi sơ chế thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với bếp chính để sơ chế đúng nhu cầu từng ca ra sao?",
            ],
            "service_attitude": [
                "Theo bạn, khâu sơ chế ảnh hưởng tới chất lượng món cuối cùng thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Nguyên liệu nhập về không tươi như mong đợi, bạn xử lý thế nào?",
                "answers": {
                    "good": {
                        "text": "Em kiểm tra và tách riêng phần không đạt, báo bếp chính và bộ phận nhận hàng để đổi/trả, không đưa nguyên liệu kém vào chế biến.",
                        "ai_reply": "Cảm ơn em, em đặt an toàn thực phẩm lên trên hết, đó là điều rất đáng quý ở khâu sơ chế. Vậy là em kiên quyết loại phần không đạt và báo đúng người. Em dựa vào dấu hiệu nào để đánh giá nguyên liệu còn tươi hay không?",
                    },
                    "fair": {
                        "text": "Cái nào còn dùng được thì em dùng, hỏng thì bỏ.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Biết chọn lọc là tốt. Theo em, có nên báo bếp chính và bộ phận nhận hàng để đổi/trả phần kém chất lượng không?",
                    },
                    "weak": {
                        "text": "Nhập gì thì em làm nấy thôi.",
                        "ai_reply": "Mình hiểu là em muốn làm theo nguyên liệu có sẵn. Nhưng nếu nguyên liệu không tươi mà vẫn dùng thì món ăn và sức khoẻ khách sẽ ra sao, em nghĩ mình nên báo ai trong trường hợp đó?",
                    },
                },
            },
        ],
    },
    # ===================== VỆ SINH & HỖ TRỢ =====================
    {
        "id": "cleaner",
        "name": "Dọn dẹp / Tạp vụ",
        "keywords": ["tạp vụ", "dọn dẹp", "tap vu", "don dep", "cleaner", "cleaning staff", "janitor"],
        "question_bank": {
            "experience": [
                "Bạn từng làm tạp vụ/dọn dẹp ở quán/nhà hàng nào và phụ trách khu vực gì?",
                "Bạn duy trì khu vực luôn sạch trong suốt ca đông khách thế nào?",
            ],
            "situation": [
                "Khách làm đổ thức ăn/nước ra sàn giữa lúc đông, bạn xử lý ra sao?",
                "Nhà vệ sinh cần dọn gấp mà bạn đang dở việc khác, bạn ưu tiên thế nào?",
            ],
            "operations": [
                "Bạn lên lịch dọn dẹp các khu vực theo tần suất nào trong ca?",
                "Bạn sử dụng và pha hoá chất tẩy rửa đúng cách, an toàn ra sao?",
            ],
            "hygiene": [
                "Bạn đảm bảo vệ sinh khu vực ăn uống và nhà vệ sinh đạt chuẩn thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với phục vụ để dọn bàn nhanh, sẵn sàng đón khách mới ra sao?",
            ],
            "service_attitude": [
                "Theo bạn, sự sạch sẽ ảnh hưởng tới cảm nhận của khách thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Khách làm đổ thức ăn/nước ra sàn giữa lúc đông, bạn xử lý ra sao?",
                "answers": {
                    "good": {
                        "text": "Em đặt biển cảnh báo trơn trượt, lau khô ngay để tránh té ngã, làm nhẹ nhàng để không làm khách ngại, rồi kiểm tra lại khu vực.",
                        "ai_reply": "Cảm ơn em, em vừa đảm bảo an toàn vừa tinh tế giữ thể diện cho khách, rất chu đáo. Vậy là em ưu tiên cảnh báo trơn trượt và xử lý ngay. Em làm thế nào để vừa nhanh vừa không làm phiền các bàn xung quanh?",
                    },
                    "fair": {
                        "text": "Em lau sạch chỗ đổ rồi đi làm tiếp.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Lau sạch ngay là đúng. Theo em, có nên đặt biển cảnh báo trơn trượt trong lúc sàn còn ẩm để tránh khách té không?",
                    },
                    "weak": {
                        "text": "Em đợi vãn khách rồi lau cho tiện.",
                        "ai_reply": "Mình hiểu là em muốn chờ bớt đông cho dễ làm. Nhưng sàn ướt dễ gây trượt ngã, em thử nghĩ xem nên xử lý ngay thế nào để vừa an toàn vừa không cản trở khách?",
                    },
                },
            },
        ],
    },
    {
        "id": "dishwasher",
        "name": "Rửa chén / Steward",
        "keywords": ["rửa chén", "rửa bát", "rua chen", "rua bat", "dishwasher", "steward", "kitchen porter"],
        "question_bank": {
            "experience": [
                "Bạn từng rửa chén/steward ở bếp quy mô thế nào, dùng máy rửa hay rửa tay?",
                "Bạn đảm bảo đủ chén dĩa sạch cho bếp và phục vụ trong cao điểm ra sao?",
            ],
            "situation": [
                "Chén dĩa dồn ứ giữa cao điểm, bạn xử lý thế nào để không thiếu đồ?",
                "Máy rửa hỏng giữa ca, bạn xoay xở ra sao?",
            ],
            "operations": [
                "Bạn vận hành máy rửa và quy trình tráng/khử trùng đúng cách thế nào?",
                "Bạn sắp xếp, phân loại chén dĩa và dụng cụ sau khi rửa ra sao?",
            ],
            "hygiene": [
                "Bạn đảm bảo chén dĩa sạch đạt chuẩn vệ sinh và phòng nhiễm chéo thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với bếp và phục vụ để cung ứng dụng cụ kịp thời ra sao?",
            ],
            "service_attitude": [
                "Theo bạn, công việc rửa chén góp phần vào chất lượng phục vụ thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Chén dĩa dồn ứ giữa cao điểm, bạn xử lý thế nào để không thiếu đồ?",
                "answers": {
                    "good": {
                        "text": "Em ưu tiên rửa nhóm đồ đang thiếu nhất (ly, dĩa hay dùng), gom theo loại để rửa nhanh, vừa rửa vừa châm trả về cho bếp và phục vụ liên tục.",
                        "ai_reply": "Cảm ơn em, em biết ưu tiên đúng món đang thiếu nhất, cho thấy em nắm được nhịp của cả bếp lẫn phục vụ. Vậy là em xử lý theo nhu cầu thực tế chứ không rửa tuần tự. Em nhận biết món nào đang thiếu để ưu tiên bằng cách nào?",
                    },
                    "fair": {
                        "text": "Em ráng rửa nhanh hết đống đó.",
                        "ai_reply": "Cảm ơn em đã chia sẻ tinh thần đó. Rửa nhanh là cần. Theo em, nếu ưu tiên trước những thứ bếp/phục vụ đang cần gấp thì có đỡ thiếu đồ hơn không?",
                    },
                    "weak": {
                        "text": "Dồn nhiều quá thì em rửa từ từ thôi.",
                        "ai_reply": "Mình hiểu là đống chén nhiều sẽ ngợp. Nhưng nếu rửa từ từ mà bếp thiếu dĩa thì món bị nghẽn, em thử nghĩ xem nên ưu tiên rửa gì trước để cả dây chuyền không bị kẹt?",
                    },
                },
            },
        ],
    },
    {
        "id": "warehouse_assistant",
        "name": "Phụ kho / Nhận hàng",
        "keywords": ["phụ kho", "nhận hàng", "phu kho", "nhan hang", "warehouse assistant", "stock", "receiving staff"],
        "question_bank": {
            "experience": [
                "Bạn từng phụ kho/nhận hàng ở đâu và quản lý nhóm hàng gì?",
                "Bạn kiểm đếm và đối chiếu hàng nhập với đơn đặt ra sao?",
            ],
            "situation": [
                "Hàng giao thiếu hoặc sai so với đơn, bạn xử lý thế nào?",
                "Phát hiện hàng cận hạn/hỏng trong kho, bạn làm gì?",
            ],
            "operations": [
                "Bạn sắp xếp kho và xuất nhập theo nguyên tắc nào (FIFO/FEFO)?",
                "Bạn ghi nhận tồn kho và báo bổ sung khi nào?",
            ],
            "hygiene": [
                "Bạn bảo quản thực phẩm trong kho đúng nhiệt độ và vệ sinh thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với bếp và bộ phận đặt hàng để cung ứng kịp thời ra sao?",
            ],
            "service_attitude": [
                "Theo bạn, quản lý kho tốt giúp ích gì cho vận hành và chi phí của quán?",
            ],
        },
        "fewshot": [
            {
                "question": "Hàng giao thiếu hoặc sai so với đơn, bạn xử lý thế nào?",
                "answers": {
                    "good": {
                        "text": "Em đối chiếu phiếu giao với đơn đặt, ghi rõ phần thiếu/sai, chụp ảnh và báo nhà cung cấp cùng quản lý để bổ sung hoặc đổi trả kịp thời.",
                        "ai_reply": "Cảm ơn em, cách em đối chiếu và ghi nhận có bằng chứng cho thấy em rất chặt chẽ với khâu nhận hàng. Vậy là em xử lý minh bạch và báo đúng người. Em làm gì để việc thiếu hàng không ảnh hưởng tới ca bán hôm đó?",
                    },
                    "fair": {
                        "text": "Em báo quản lý là hàng bị thiếu.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Báo quản lý là đúng. Theo em, nếu ghi rõ thiếu món gì, số lượng bao nhiêu và có ảnh thì việc đổi/trả với nhà cung cấp có thuận lợi hơn không?",
                    },
                    "weak": {
                        "text": "Giao sao em nhận vậy chứ biết làm gì.",
                        "ai_reply": "Mình hiểu là em ngại làm phiền. Nhưng nếu nhận thiếu mà không đối chiếu thì quán chịu thiệt, em thử nghĩ xem nên kiểm tra và báo lại thế nào cho hợp lý?",
                    },
                },
            },
        ],
    },
    {
        "id": "security",
        "name": "Bảo vệ / Giữ xe",
        "keywords": ["bảo vệ", "giữ xe", "bao ve", "giu xe", "security", "security guard", "valet"],
        "question_bank": {
            "experience": [
                "Bạn từng làm bảo vệ/giữ xe ở quán/nhà hàng nào và phụ trách việc gì?",
                "Bạn sắp xếp và trông giữ xe cho khách trong giờ cao điểm ra sao?",
            ],
            "situation": [
                "Khách báo mất đồ/xe để ở khu bạn trông, bạn xử lý thế nào?",
                "Có khách gây rối hoặc xảy ra xô xát, bạn phản ứng ra sao?",
            ],
            "operations": [
                "Bạn kiểm soát ra vào và phát/giữ vé xe theo quy trình nào?",
                "Bạn quan sát và ghi nhận an ninh khu vực trong ca thế nào?",
            ],
            "hygiene": [
                "Bạn giữ khu vực để xe và lối ra vào gọn gàng, an toàn thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với quản lý và nhân viên khi có sự cố an ninh ra sao?",
            ],
            "service_attitude": [
                "Bạn chào đón và hỗ trợ khách thế nào để vừa an ninh vừa thân thiện?",
            ],
        },
        "fewshot": [
            {
                "question": "Có khách gây rối hoặc xảy ra xô xát, bạn phản ứng ra sao?",
                "answers": {
                    "good": {
                        "text": "Em giữ bình tĩnh, tách các bên ra, nói chuyện hạ nhiệt, đảm bảo an toàn cho khách xung quanh và báo quản lý; nếu nghiêm trọng thì gọi hỗ trợ.",
                        "ai_reply": "Cảm ơn em, em ưu tiên giữ an toàn và hạ nhiệt thay vì căng thẳng thêm, đó là cách xử lý rất chững chạc. Vậy là em vừa can thiệp vừa báo quản lý kịp thời. Em làm thế nào để giữ bình tĩnh khi tình huống nóng lên?",
                    },
                    "fair": {
                        "text": "Em can ngăn rồi báo quản lý.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Can ngăn và báo quản lý là hợp lý. Theo em, làm sao để can ngăn mà vẫn đảm bảo an toàn cho chính mình và khách xung quanh?",
                    },
                    "weak": {
                        "text": "Khách đánh nhau thì em đứng ngoài cho an toàn.",
                        "ai_reply": "Mình hiểu là em lo cho an toàn bản thân, điều đó chính đáng. Nhưng ở vai trò bảo vệ, em thử nghĩ xem có thể làm gì để hạ nhiệt và bảo vệ khách mà vẫn không tự đặt mình vào nguy hiểm?",
                    },
                },
            },
        ],
    },
    # ===================== GIAO HÀNG & NGOÀI QUÁN =====================
    {
        "id": "shipper",
        "name": "Shipper / Giao hàng",
        "keywords": ["shipper", "giao hàng", "giao hang", "tài xế giao hàng", "tai xe giao hang", "delivery", "delivery driver"],
        "question_bank": {
            "experience": [
                "Bạn từng giao đồ ăn cho quán/ứng dụng nào và trung bình bao nhiêu đơn mỗi ca?",
                "Bạn đảm bảo đồ ăn giao tới nơi còn nóng và nguyên vẹn ra sao?",
            ],
            "situation": [
                "Khách không nghe máy hoặc sai địa chỉ, bạn xử lý thế nào?",
                "Trời mưa/kẹt xe làm trễ đơn, bạn xử lý ra sao để khách thông cảm?",
            ],
            "operations": [
                "Bạn sắp xếp lộ trình giao nhiều đơn sao cho nhanh và tiết kiệm?",
                "Bạn kiểm tra món và hoá đơn trước khi rời quán theo bước nào?",
            ],
            "hygiene": [
                "Bạn giữ túi giao hàng và đồ ăn sạch sẽ, đúng nhiệt độ thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với quầy/đóng gói để nhận đúng đơn nhanh chóng ra sao?",
            ],
            "service_attitude": [
                "Bạn giao tiếp với khách lúc giao hàng thế nào để họ hài lòng?",
            ],
        },
        "fewshot": [
            {
                "question": "Khách không nghe máy hoặc sai địa chỉ, bạn xử lý thế nào?",
                "answers": {
                    "good": {
                        "text": "Em gọi và nhắn nhiều lần, chờ ở điểm gần nhất, đối chiếu lại địa chỉ trên đơn, nếu không liên lạc được thì báo quán/ứng dụng để có hướng xử lý đúng quy định.",
                        "ai_reply": "Cảm ơn em, em vừa kiên nhẫn liên hệ vừa làm đúng quy trình báo quán, rất trách nhiệm. Vậy là em không tự ý xử lý mà phối hợp để đúng quy định. Trong lúc chờ, em làm gì để món vẫn giữ được chất lượng tốt nhất?",
                    },
                    "fair": {
                        "text": "Em gọi vài lần không được thì mang về quán.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Mang về quán khi không liên lạc được là hợp lý. Theo em, có nên báo quán/ứng dụng trước khi quyết định để được hướng dẫn đúng quy định không?",
                    },
                    "weak": {
                        "text": "Không nghe máy thì em để đó rồi đi đơn khác.",
                        "ai_reply": "Mình hiểu là em muốn kịp các đơn khác. Nhưng nếu để đồ ăn lại mà không báo ai thì khách và quán đều thiệt, em thử nghĩ xem nên xử lý thế nào cho gọn mà vẫn đúng?",
                    },
                },
            },
        ],
    },
    {
        "id": "takeaway_packer",
        "name": "Đóng gói mang đi",
        "keywords": ["đóng gói mang đi", "đóng gói", "dong goi mang di", "dong goi", "takeaway packer", "packing", "takeaway"],
        "question_bank": {
            "experience": [
                "Bạn từng đóng gói đồ mang đi/giao đi ở quán nào và khối lượng mỗi ca ra sao?",
                "Bạn đảm bảo gói đúng, đủ món và phụ kiện (muỗng, đũa, tương) thế nào?",
            ],
            "situation": [
                "Đơn dồn nhiều cùng lúc, bạn đóng gói nhanh mà không nhầm món ra sao?",
                "Phát hiện món bị thiếu hoặc sai trước khi giao, bạn xử lý thế nào?",
            ],
            "operations": [
                "Bạn đối chiếu đơn với món trước khi niêm phong theo bước nào?",
                "Bạn chọn quy cách đóng gói phù hợp để món không đổ, không nguội ra sao?",
            ],
            "hygiene": [
                "Bạn đảm bảo vệ sinh khi đóng gói và phân tách món sống/chín, nóng/lạnh thế nào?",
            ],
            "teamwork": [
                "Bạn phối hợp với bếp và shipper để giao đúng đơn, đúng giờ ra sao?",
            ],
            "service_attitude": [
                "Theo bạn, một gói hàng gọn gàng, đầy đủ tác động tới khách thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Đơn dồn nhiều cùng lúc, bạn đóng gói nhanh mà không nhầm món ra sao?",
                "answers": {
                    "good": {
                        "text": "Em đóng từng đơn dứt điểm theo phiếu, dán nhãn rõ, đối chiếu lại món và phụ kiện trước khi niêm phong, tách khu vực đơn đã xong và đơn đang làm.",
                        "ai_reply": "Cảm ơn em, cách em làm dứt điểm từng đơn và tách khu vực rõ ràng cho thấy em rất cẩn thận, tránh nhầm lẫn. Vậy là em kiểm soát theo phiếu và đối chiếu trước khi niêm phong. Khi cực đông, em làm gì để vẫn giữ được sự chính xác đó?",
                    },
                    "fair": {
                        "text": "Em gói nhanh theo phiếu rồi giao ra.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Bám theo phiếu là tốt. Theo em, kiểm lại món và phụ kiện một lượt trước khi dán kín có giúp giảm nhầm lẫn không?",
                    },
                    "weak": {
                        "text": "Đông quá thì khó tránh nhầm lắm.",
                        "ai_reply": "Mình hiểu lúc đông rất dễ rối. Vậy là em thấy khó giữ chính xác khi gấp. Em thử nghĩ xem có cách sắp xếp nào để mỗi đơn được kiểm một lần trước khi giao không?",
                    },
                },
            },
        ],
    },
    # ===================== QUẢN LÝ & GIÁM SÁT =====================
    {
        "id": "shift_leader",
        "name": "Trưởng ca",
        "keywords": ["trưởng ca", "truong ca", "shift leader", "shift supervisor", "ca trưởng", "ca truong"],
        "question_bank": {
            "experience": [
                "Bạn từng làm trưởng ca quản lý bao nhiêu nhân viên và ở mô hình quán nào?",
                "Bạn mở ca, phân công và kết ca theo quy trình nào?",
            ],
            "situation": [
                "Giữa ca thiếu người và đông khách, bạn điều phối nhân sự ra sao?",
                "Có mâu thuẫn giữa hai nhân viên trong ca, bạn xử lý thế nào?",
            ],
            "operations": [
                "Bạn theo dõi doanh thu, tồn quỹ và bàn giao ca thế nào?",
                "Bạn đảm bảo tiêu chuẩn phục vụ và vệ sinh được tuân thủ trong ca ra sao?",
            ],
            "hygiene": [
                "Bạn giám sát vệ sinh ATTP và an toàn lao động trong ca thế nào?",
            ],
            "teamwork": [
                "Bạn tạo động lực và phân công để cả ca phối hợp nhịp nhàng ra sao?",
            ],
            "service_attitude": [
                "Bạn làm gương về thái độ phục vụ cho nhân viên trong ca thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Giữa ca thiếu người và đông khách, bạn điều phối nhân sự ra sao?",
                "answers": {
                    "good": {
                        "text": "Em đánh giá điểm nghẽn, điều người từ khâu nhẹ sang khâu đang quá tải, tự nhảy vào hỗ trợ, đồng thời trấn an khách đang chờ để giữ trải nghiệm.",
                        "ai_reply": "Cảm ơn em, em vừa điều phối linh hoạt vừa quan tâm trải nghiệm khách, đúng tố chất của một trưởng ca. Vậy là em ưu tiên giải toả điểm nghẽn và sẵn sàng làm cùng đội. Sau ca đó em rút ra điều gì để chủ động hơn với việc thiếu người?",
                    },
                    "fair": {
                        "text": "Em chia lại việc cho mọi người rồi cùng làm.",
                        "ai_reply": "Cảm ơn em đã chia sẻ. Chia việc và cùng làm là hợp lý. Theo em, làm sao để nhận ra khâu nào đang nghẽn nhất để dồn người vào đúng chỗ?",
                    },
                    "weak": {
                        "text": "Thiếu người thì để khách chờ lâu chút thôi.",
                        "ai_reply": "Mình hiểu thiếu người thì khó tránh chậm. Nhưng ở vai trò trưởng ca, em thử nghĩ xem có cách điều phối nào để khách bớt phải chờ và vẫn thấy được quan tâm không?",
                    },
                },
            },
        ],
    },
    {
        "id": "store_manager",
        "name": "Quản lý cửa hàng",
        "keywords": ["quản lý cửa hàng", "quản lý quán", "quan ly cua hang", "quan ly quan", "store manager", "restaurant manager", "outlet manager"],
        "question_bank": {
            "experience": [
                "Bạn từng quản lý cửa hàng F&B quy mô bao nhiêu nhân sự, doanh thu thế nào?",
                "Bạn chịu trách nhiệm những chỉ số nào (doanh thu, chi phí, chất lượng dịch vụ)?",
            ],
            "situation": [
                "Doanh thu giảm vài tháng liên tiếp, bạn phân tích và hành động ra sao?",
                "Có khiếu nại nghiêm trọng từ khách lan ra mạng xã hội, bạn xử lý thế nào?",
            ],
            "operations": [
                "Bạn quản lý nhân sự, lịch ca, tồn kho và chi phí vận hành ra sao?",
                "Bạn thiết lập và giám sát tiêu chuẩn dịch vụ, vệ sinh cho cửa hàng thế nào?",
            ],
            "hygiene": [
                "Bạn đảm bảo cửa hàng tuân thủ quy định vệ sinh ATTP và an toàn thế nào?",
            ],
            "teamwork": [
                "Bạn tuyển dụng, đào tạo và giữ chân đội ngũ ra sao?",
            ],
            "service_attitude": [
                "Bạn xây dựng văn hoá phục vụ lấy khách hàng làm trung tâm thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Doanh thu giảm vài tháng liên tiếp, bạn phân tích và hành động ra sao?",
                "answers": {
                    "good": {
                        "text": "Em xem số liệu theo khung giờ, món bán chạy/chậm, phản hồi khách và chi phí; tìm nguyên nhân rồi thử giải pháp cụ thể như điều chỉnh menu, khuyến mãi giờ thấp điểm và đo lại kết quả.",
                        "ai_reply": "Cảm ơn anh/chị, cách tiếp cận dựa trên dữ liệu rồi thử-đo của bạn rất bài bản. Vậy là bạn không đoán mò mà ra quyết định có cơ sở. Trong các giải pháp đã thử, điều gì mang lại hiệu quả rõ nhất và vì sao?",
                    },
                    "fair": {
                        "text": "Em sẽ làm thêm khuyến mãi để kéo khách lại.",
                        "ai_reply": "Cảm ơn bạn đã chia sẻ. Khuyến mãi có thể giúp ngắn hạn. Theo bạn, trước khi khuyến mãi thì xem dữ liệu để biết khách giảm ở khung giờ/món nào có giúp chọn đúng cách làm hơn không?",
                    },
                    "weak": {
                        "text": "Doanh thu giảm chắc do thị trường khó thôi.",
                        "ai_reply": "Mình hiểu yếu tố thị trường đúng là có ảnh hưởng. Nhưng ở vai trò quản lý, bạn thử nghĩ xem có những yếu tố nào trong tầm kiểm soát của cửa hàng mà mình có thể cải thiện không?",
                    },
                },
            },
        ],
    },
    {
        "id": "area_supervisor",
        "name": "Giám sát khu vực",
        "keywords": ["giám sát khu vực", "giám sát", "giam sat khu vuc", "giam sat", "area supervisor", "area manager", "district supervisor"],
        "question_bank": {
            "experience": [
                "Bạn từng giám sát bao nhiêu cửa hàng/khu vực và ở chuỗi F&B nào?",
                "Bạn đánh giá và so sánh hiệu quả giữa các cửa hàng ra sao?",
            ],
            "situation": [
                "Một cửa hàng trong khu vực liên tục không đạt chỉ tiêu, bạn vào cuộc thế nào?",
                "Phát hiện cửa hàng làm sai quy chuẩn thương hiệu, bạn xử lý ra sao?",
            ],
            "operations": [
                "Bạn xây dựng quy chuẩn và kiểm tra (audit) các cửa hàng theo cách nào?",
                "Bạn theo dõi các chỉ số vận hành và đưa ra hành động cải thiện thế nào?",
            ],
            "hygiene": [
                "Bạn giám sát việc tuân thủ vệ sinh ATTP đồng đều giữa các cửa hàng thế nào?",
            ],
            "teamwork": [
                "Bạn hỗ trợ và phát triển đội ngũ quản lý cửa hàng ra sao?",
            ],
            "service_attitude": [
                "Bạn đảm bảo trải nghiệm khách hàng nhất quán trên toàn khu vực thế nào?",
            ],
        },
        "fewshot": [
            {
                "question": "Một cửa hàng trong khu vực liên tục không đạt chỉ tiêu, bạn vào cuộc thế nào?",
                "answers": {
                    "good": {
                        "text": "Em xuống trực tiếp quan sát vận hành, xem dữ liệu và lắng nghe quản lý/nhân viên để tìm gốc rễ, cùng họ lập kế hoạch cải thiện có mốc đo và theo dõi sát.",
                        "ai_reply": "Cảm ơn anh/chị, việc xuống tận nơi và cùng đội xây kế hoạch có mốc đo cho thấy bạn giám sát theo hướng đồng hành chứ không chỉ phán xét. Vậy là bạn tìm gốc rễ trước khi hành động. Bạn cân bằng giữa hỗ trợ và yêu cầu trách nhiệm với quản lý cửa hàng thế nào?",
                    },
                    "fair": {
                        "text": "Em sẽ nhắc nhở quản lý cửa hàng đó cố gắng hơn.",
                        "ai_reply": "Cảm ơn bạn đã chia sẻ. Nhắc nhở là cần. Theo bạn, nếu cùng họ tìm ra nguyên nhân cụ thể và lập kế hoạch đo lường thì việc cải thiện có bền hơn không?",
                    },
                    "weak": {
                        "text": "Không đạt thì để quản lý cửa hàng tự lo thôi.",
                        "ai_reply": "Mình hiểu là bạn muốn trao quyền cho quản lý cửa hàng. Nhưng ở vai trò giám sát khu vực, bạn thử nghĩ xem sự hỗ trợ đúng lúc của mình có thể giúp cửa hàng xoay chuyển thế nào?",
                    },
                },
            },
        ],
    },
]


# ---------------------------------------------------------------------------
# Role_Resolver — ánh xạ tiêu đề công việc sang một FnbRole (an toàn tuyệt đối)
# ---------------------------------------------------------------------------


def _normalize_text(value: str) -> str:
    """Chuẩn hóa chuỗi để so khớp keyword.

    Các bước: trim khoảng trắng đầu/cuối, chuyển chữ thường, bỏ dấu tiếng Việt
    (tách tổ hợp Unicode NFD rồi loại bỏ các dấu kết hợp), và gộp các khoảng
    trắng liên tiếp thành một dấu cách. Hàm thuần, không side-effect.
    """
    if not value:
        return ""
    # NFD tách ký tự gốc và dấu kết hợp; loại bỏ các ký tự thuộc nhóm Mark (Mn).
    decomposed = unicodedata.normalize("NFD", value)
    without_marks = "".join(
        ch for ch in decomposed if unicodedata.category(ch) != "Mn"
    )
    # Xử lý riêng chữ đ/Đ vì không tách dấu qua NFD.
    without_marks = without_marks.replace("đ", "d").replace("Đ", "D")
    # Trim + lowercase + gộp khoảng trắng.
    return " ".join(without_marks.lower().split())


def get_role_for_title(job_title: str) -> FnbRole:
    """Ánh xạ ``job_title`` sang một :class:`FnbRole`.

    Quy tắc khớp:
    - Chuẩn hóa ``job_title`` (trim, lowercase, bỏ dấu) và từng keyword của role.
    - Một role được coi là khớp nếu một keyword (đã chuẩn hóa, không rỗng) là
      chuỗi con của ``job_title`` đã chuẩn hóa.
    - Khi nhiều role khớp: chọn role có keyword khớp DÀI NHẤT (theo số ký tự);
      nếu bằng nhau, giữ role xuất hiện TRƯỚC theo thứ tự định nghĩa trong
      ``FNB_ROLES`` (deterministic).
    - ``job_title`` là ``None``/rỗng/chỉ khoảng trắng, hoặc không role nào khớp,
      hoặc có bất kỳ lỗi không lường trước nào → trả ``GENERIC_FALLBACK_ROLE``.

    Hàm luôn trả về một FnbRole hợp lệ và KHÔNG BAO GIỜ ném ngoại lệ
    (Requirements 1.1–1.7).
    """
    try:
        if job_title is None:
            return GENERIC_FALLBACK_ROLE

        normalized_title = _normalize_text(job_title)
        if not normalized_title:
            return GENERIC_FALLBACK_ROLE

        best_role: Optional[FnbRole] = None
        best_len = 0

        # Duyệt theo thứ tự định nghĩa để bảo đảm tie-break ổn định.
        for role in FNB_ROLES:
            keywords = role.get("keywords") or []
            for keyword in keywords:
                normalized_keyword = _normalize_text(keyword)
                if not normalized_keyword:
                    continue
                if normalized_keyword in normalized_title:
                    # Chỉ thay thế khi tìm được keyword DÀI HƠN (strict),
                    # nhờ vậy khi bằng nhau role định nghĩa trước được giữ lại.
                    if len(normalized_keyword) > best_len:
                        best_len = len(normalized_keyword)
                        best_role = role

        if best_role is not None:
            return best_role

        return GENERIC_FALLBACK_ROLE
    except Exception:
        # Suy giảm an toàn: mọi lỗi không lường trước → fallback (Requirement 1.7).
        return GENERIC_FALLBACK_ROLE


# ---------------------------------------------------------------------------
# Prompt builders — render khối few-shot gọn cho prompt (an toàn tuyệt đối)
# ---------------------------------------------------------------------------

# Giới hạn hợp lệ cho số ví dụ few-shot mỗi lần dựng prompt (Requirement 2.2).
_FEWSHOT_MIN_EXAMPLES: int = 1
_FEWSHOT_MAX_EXAMPLES: int = 10

# Chú thích bắt buộc trong khối few-shot (Requirement 2.4): AI chỉ học phong cách,
# không lặp lại nguyên văn các ví dụ mẫu.
_FEWSHOT_DISCLAIMER: str = (
    "Lưu ý: Các đoạn hội thoại dưới đây CHỈ là ví dụ minh hoạ PHONG CÁCH "
    "(công nhận/đồng cảm → diễn giải lại ý → câu hỏi đào sâu). Hãy HỌC PHONG CÁCH, "
    "TUYỆT ĐỐI KHÔNG lặp lại nguyên văn câu hỏi hay câu trả lời mẫu."
)

# Nhãn hiển thị cho từng mức chất lượng câu trả lời.
_ANSWER_LEVEL_LABELS = (
    ("good", "Trả lời tốt"),
    ("fair", "Trả lời khá"),
    ("weak", "Trả lời yếu"),
)


def build_fewshot_block(role: dict, max_examples: int = 3) -> str:
    """Render khối ví dụ few-shot của ``role`` thành text gọn cho prompt.

    Hành vi (Requirements 2.2, 2.3, 2.4):
    - Hiển thị tối đa ``max_examples`` ví dụ (mặc định 3). ``max_examples`` được
      kẹp (clamp) vào phạm vi hợp lệ ``[1, 10]`` nếu nằm ngoài khoảng này.
    - Nếu role có ít ví dụ hơn ``max_examples`` thì chỉ render số ví dụ thực có,
      không báo lỗi.
    - Luôn kèm chú thích rằng AI chỉ học phong cách, không lặp lại nguyên văn.
    - Mỗi ví dụ được render dạng văn bản dễ đọc: câu hỏi cùng các mức trả lời
      good/fair/weak kèm ``ai_reply`` để mô hình học phong cách 3 bước.

    An toàn tuyệt đối: hàm không bao giờ ném ngoại lệ. Với ``role`` là ``None``,
    thiếu khóa ``fewshot``, hoặc dữ liệu dị dạng, hàm trả về chuỗi rỗng ``""``
    hoặc một khối tối thiểu an toàn.
    """
    try:
        # Clamp max_examples vào [1, 10]; xử lý cả input không phải int.
        try:
            limit = int(max_examples)
        except (TypeError, ValueError):
            limit = 3
        if limit < _FEWSHOT_MIN_EXAMPLES:
            limit = _FEWSHOT_MIN_EXAMPLES
        elif limit > _FEWSHOT_MAX_EXAMPLES:
            limit = _FEWSHOT_MAX_EXAMPLES

        if not isinstance(role, dict):
            return ""

        fewshot = role.get("fewshot")
        if not isinstance(fewshot, list) or not fewshot:
            return ""

        role_name = role.get("name")
        header = "VÍ DỤ HỘI THOẠI MẪU"
        if isinstance(role_name, str) and role_name.strip():
            header = f"VÍ DỤ HỘI THOẠI MẪU — vị trí {role_name.strip()}"

        rendered_examples: List[str] = []
        for example in fewshot:
            if len(rendered_examples) >= limit:
                break
            if not isinstance(example, dict):
                continue

            lines: List[str] = []
            question = example.get("question")
            if isinstance(question, str) and question.strip():
                lines.append(f"Câu hỏi: {question.strip()}")

            answers = example.get("answers")
            if isinstance(answers, dict):
                for level_key, level_label in _ANSWER_LEVEL_LABELS:
                    answer = answers.get(level_key)
                    if not isinstance(answer, dict):
                        continue
                    text = answer.get("text")
                    ai_reply = answer.get("ai_reply")
                    text_str = text.strip() if isinstance(text, str) else ""
                    reply_str = ai_reply.strip() if isinstance(ai_reply, str) else ""
                    if not text_str and not reply_str:
                        continue
                    lines.append(f"- {level_label} (ứng viên): {text_str}")
                    lines.append(f"  Phản hồi mẫu của AI: {reply_str}")

            # Bỏ qua ví dụ rỗng (không có nội dung hữu ích nào).
            if not lines:
                continue

            index = len(rendered_examples) + 1
            rendered_examples.append(f"Ví dụ {index}:\n" + "\n".join(lines))

        if not rendered_examples:
            return ""

        block_parts = [header, _FEWSHOT_DISCLAIMER, "", "\n\n".join(rendered_examples)]
        return "\n".join(block_parts)
    except Exception:
        # Suy giảm an toàn: bất kỳ lỗi không lường trước nào → trả chuỗi rỗng.
        return ""

# ---------------------------------------------------------------------------
# Prompt builders — gợi ý câu hỏi theo nhóm năng lực (an toàn tuyệt đối)
# ---------------------------------------------------------------------------

# Số gợi ý câu hỏi mỗi nhóm năng lực: từ 1 đến 5 (Requirement 2.5).
_HINTS_MIN_PER_GROUP: int = 1
_HINTS_MAX_PER_GROUP: int = 5

# Thứ tự hiển thị và nhãn tiếng Việt cho từng nhóm năng lực trong question_bank.
_QUESTION_GROUP_LABELS = (
    ("experience", "Kinh nghiệm"),
    ("situation", "Xử lý tình huống"),
    ("operations", "Quy trình/vận hành"),
    ("hygiene", "Vệ sinh an toàn thực phẩm"),
    ("teamwork", "Phối hợp nhóm"),
    ("service_attitude", "Thái độ phục vụ"),
)

# Chú thích bắt buộc: đây là gợi ý để AI BIẾN TẤU, không hỏi nguyên văn.
_HINTS_DISCLAIMER: str = (
    "Lưu ý: Đây CHỈ là gợi ý câu hỏi theo nhóm năng lực để bạn BIẾN TẤU, đặt câu "
    "hỏi phù hợp ngữ cảnh và câu trả lời của ứng viên. TUYỆT ĐỐI KHÔNG hỏi lại "
    "nguyên văn; hãy diễn đạt theo cách tự nhiên của riêng bạn và tránh lặp câu cố định."
)


def build_question_hints(role: dict) -> str:
    """Render gợi ý câu hỏi theo từng nhóm năng lực của ``role`` thành text.

    Hành vi (Requirement 2.5):
    - Với mỗi nhóm năng lực trong ``question_bank`` (experience, situation,
      operations, hygiene, teamwork, service_attitude), chọn từ 1 đến 5 câu hỏi
      gợi ý (lấy tối đa 5 câu đầu tiên một cách deterministic) để AI biến tấu thay
      vì lặp lại câu hỏi cố định.
    - Render dạng văn bản dễ đọc, gom theo nhóm năng lực, kèm chú thích rằng đây
      là gợi ý để biến tấu chứ không hỏi nguyên văn.
    - Bỏ qua các nhóm rỗng/thiếu một cách gọn gàng (không render nhóm không có
      câu hỏi hợp lệ nào).

    An toàn tuyệt đối: hàm KHÔNG BAO GIỜ ném ngoại lệ. Với ``role`` là ``None``,
    thiếu/khác kiểu khóa ``question_bank``, hoặc dữ liệu dị dạng, hàm trả về
    chuỗi rỗng ``""``.
    """
    try:
        if not isinstance(role, dict):
            return ""

        question_bank = role.get("question_bank")
        if not isinstance(question_bank, dict) or not question_bank:
            return ""

        role_name = role.get("name")
        header = "GỢI Ý CÂU HỎI THEO NHÓM NĂNG LỰC"
        if isinstance(role_name, str) and role_name.strip():
            header = f"GỢI Ý CÂU HỎI THEO NHÓM NĂNG LỰC — vị trí {role_name.strip()}"

        rendered_groups: List[str] = []
        for group_key, group_label in _QUESTION_GROUP_LABELS:
            questions = question_bank.get(group_key)
            if not isinstance(questions, list) or not questions:
                continue

            # Lọc câu hỏi hợp lệ rồi lấy tối đa 5 câu đầu tiên (deterministic).
            selected: List[str] = []
            for question in questions:
                if len(selected) >= _HINTS_MAX_PER_GROUP:
                    break
                if isinstance(question, str) and question.strip():
                    selected.append(question.strip())

            if len(selected) < _HINTS_MIN_PER_GROUP:
                continue

            lines = [f"{group_label}:"]
            lines.extend(f"- {question}" for question in selected)
            rendered_groups.append("\n".join(lines))

        if not rendered_groups:
            return ""

        block_parts = [header, _HINTS_DISCLAIMER, "", "\n\n".join(rendered_groups)]
        return "\n".join(block_parts)
    except Exception:
        # Suy giảm an toàn: mọi lỗi không lường trước → trả chuỗi rỗng.
        return ""


# ---------------------------------------------------------------------------
# Kiểm soát ngân sách token cho phần nội dung chèn thêm (Requirements 2.2, 2.7)
# ---------------------------------------------------------------------------

# Giới hạn token mặc định cho TOÀN BỘ phần nội dung chèn thêm vào prompt
# (style guide + few-shot + gợi ý câu hỏi). Có thể cấu hình qua tham số
# ``token_budget`` của ``build_dataset_prompt_block``.
DEFAULT_TOKEN_BUDGET: int = 2000

# Dấu phân tách giữa các khối khi lắp ráp phần chèn thêm.
_BLOCK_SEPARATOR: str = "\n\n"


def _estimate_tokens(text: str) -> int:
    """Ước lượng số token của ``text`` một cách thuần và deterministic.

    Heuristic (chỉ dùng thư viện chuẩn, KHÔNG dùng tokenizer ngoài):
    ước lượng token ≈ ceil(len(text) / 4). Quy ước phổ biến là trung bình mỗi
    token tương ứng khoảng 4 ký tự đối với văn bản tự nhiên; ở đây dùng phép
    chia nguyên có làm tròn lên ``(len + 3) // 4`` để tránh ước lượng thấp.

    Tính chất:
    - Thuần (pure) và deterministic: cùng input → cùng output, không side-effect.
    - An toàn: input không phải chuỗi → coi như độ dài 0 (trả về 0).
    """
    if not isinstance(text, str) or not text:
        return 0
    return (len(text) + 3) // 4


def build_dataset_prompt_block(
    role: dict,
    max_examples: int = 3,
    token_budget: int = DEFAULT_TOKEN_BUDGET,
) -> str:
    """Lắp ráp phần nội dung chèn thêm vào prompt trong giới hạn ngân sách token.

    Phần chèn thêm gồm 3 thành phần, theo thứ tự:
        1. ``COMMUNICATION_STYLE_GUIDE`` (style guide)
        2. ``build_fewshot_block(role, max_examples)`` (khối few-shot)
        3. ``build_question_hints(role)`` (gợi ý câu hỏi theo nhóm năng lực)

    Cơ chế kiểm soát ngân sách (Requirements 2.2, 2.7):
    - Nếu tổng ước lượng token <= ``token_budget``: chèn cả ba thành phần.
    - Nếu vượt giới hạn: CẮT GIẢM theo thứ tự FEW-SHOT TRƯỚC rồi đến HINTS:
        a) Giảm dần ``max_examples`` của few-shot (về tới 1), tái ước lượng sau
           mỗi lần giảm; giữ nguyên hints trong bước này.
        b) Nếu vẫn vượt: BỎ HẲN few-shot, chỉ giữ style guide + hints.
        c) Nếu vẫn vượt: BỎ luôn hints, chỉ giữ style guide.
    - ``COMMUNICATION_STYLE_GUIDE`` LUÔN được giữ lại, kể cả khi riêng nó đã vượt
      ngân sách (suy giảm an toàn, không bao giờ trả về chuỗi rỗng).

    Tham số:
    - ``role``: FnbRole (dict). ``None``/dị dạng vẫn an toàn — vì style guide độc
      lập với role nên hàm vẫn trả về ít nhất style guide.
    - ``max_examples``: số ví dụ few-shot tối đa (mặc định 3); được kẹp về [1, 10]
      bởi ``build_fewshot_block``.
    - ``token_budget``: ngân sách token cấu hình được (mặc định ``DEFAULT_TOKEN_BUDGET``).

    An toàn tuyệt đối: KHÔNG BAO GIỜ ném ngoại lệ. Mọi lỗi không lường trước →
    trả về tối thiểu ``COMMUNICATION_STYLE_GUIDE``.
    """
    try:
        style = COMMUNICATION_STYLE_GUIDE

        # Chuẩn hóa token_budget về số nguyên không âm; lỗi → mặc định.
        try:
            budget = int(token_budget)
        except (TypeError, ValueError):
            budget = DEFAULT_TOKEN_BUDGET
        if budget < 0:
            budget = DEFAULT_TOKEN_BUDGET

        # Chuẩn hóa max_examples về [1, 10] để điều khiển vòng giảm few-shot.
        try:
            start_examples = int(max_examples)
        except (TypeError, ValueError):
            start_examples = 3
        if start_examples < _FEWSHOT_MIN_EXAMPLES:
            start_examples = _FEWSHOT_MIN_EXAMPLES
        elif start_examples > _FEWSHOT_MAX_EXAMPLES:
            start_examples = _FEWSHOT_MAX_EXAMPLES

        # Hints không phụ thuộc max_examples; tính một lần.
        hints = build_question_hints(role)

        def _assemble(parts: List[str]) -> str:
            return _BLOCK_SEPARATOR.join(part for part in parts if part)

        # (1)+(a) Thử giữ cả ba thành phần, giảm dần số ví dụ few-shot.
        for n in range(start_examples, _FEWSHOT_MIN_EXAMPLES - 1, -1):
            fewshot = build_fewshot_block(role, n)
            candidate = _assemble([style, fewshot, hints])
            if _estimate_tokens(candidate) <= budget:
                return candidate

        # (b) Vẫn vượt: bỏ hẳn few-shot, giữ style guide + hints.
        candidate = _assemble([style, hints])
        if _estimate_tokens(candidate) <= budget:
            return candidate

        # (c) Vẫn vượt: bỏ luôn hints, chỉ giữ style guide (luôn được bảo toàn).
        return style
    except Exception:
        # Suy giảm an toàn: luôn trả về ít nhất style guide.
        return COMMUNICATION_STYLE_GUIDE
