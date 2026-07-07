"""
Script merge + cleanup CandidateProfiles cho email duypl2310@gmail.com
Thứ tự: BACKUP -> MERGE -> DELETE -> VERIFY
"""
import boto3
import json
import datetime
from decimal import Decimal
from boto3.dynamodb.conditions import Attr


class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


REGION = 'ap-southeast-1'
TABLE_NAME = 'CandidateProfiles'
TARGET_ID = '69fae5bc-0011-7015-e750-04361ec50d5e'
SOURCE_ID = '79fa651c-b0f1-7005-de3d-fea1f3bfb4ed'
EMAIL = 'duypl2310@gmail.com'

dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(TABLE_NAME)


def scan_all_by_email(email):
    response = table.scan(FilterExpression=Attr('email').eq(email))
    items = response.get('Items', [])
    while 'LastEvaluatedKey' in response:
        response = table.scan(
            FilterExpression=Attr('email').eq(email),
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        items.extend(response.get('Items', []))
    return items


def get_item(user_id):
    resp = table.get_item(Key={'userId': user_id})
    return resp.get('Item')


# ─── BƯỚC 1: BACKUP ───────────────────────────────────────────────────────────
print("=" * 60)
print("BƯỚC 1: BACKUP")
print("=" * 60)

items = scan_all_by_email(EMAIL)
today = datetime.date.today().strftime('%Y%m%d')
backup_path = f'infra/backups/duypl2310-profile-backup-{today}.json'

import os
os.makedirs('infra/backups', exist_ok=True)

with open(backup_path, 'w', encoding='utf-8') as f:
    json.dump(items, f, cls=DecimalEncoder, ensure_ascii=False, indent=2)

print(f"Đã backup {len(items)} records ra: {backup_path}")
for item in items:
    print(f"  - {item.get('userId')} | fullName={item.get('fullName')} | createdAt={item.get('createdAt')}")

print()

# ─── BƯỚC 2: MERGE ────────────────────────────────────────────────────────────
print("=" * 60)
print("BƯỚC 2: MERGE DỮ LIỆU")
print("=" * 60)

target = get_item(TARGET_ID)
source = get_item(SOURCE_ID)

if not target:
    print(f"LỖI: Không tìm thấy target record {TARGET_ID}")
    exit(1)

if not source:
    print(f"LỖI: Không tìm thấy source record {SOURCE_ID}")
    exit(1)

print(f"Target (69fae5bc): fullName={target.get('fullName')}, phone={target.get('phone')}, bio={target.get('bio')}")
print(f"Source (79fa651c): ekycStatus={source.get('ekycStatus')}, kycCompleted={source.get('kycCompleted')}, "
      f"cvList count={len(source.get('cvList', []))}, skills={source.get('skills')}")

# Các trường cần merge từ source vào target:
# - ekycStatus (eKYC verified status)
# - kycCompleted
# - cvList
# - skills
# Giữ nguyên target: fullName, phone
# bio: xóa trắng

update_expression = (
    "SET ekycStatus = :ekycStatus, "
    "kycCompleted = :kycCompleted, "
    "cvList = :cvList, "
    "skills = :skills, "
    "bio = :bio, "
    "updatedAt = :updatedAt"
)

expression_values = {
    ':ekycStatus': source.get('ekycStatus', ''),
    ':kycCompleted': source.get('kycCompleted', False),
    ':cvList': source.get('cvList', []),
    ':skills': source.get('skills', []),
    ':bio': '',  # Xóa trắng bio
    ':updatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
}

print()
print("Cập nhật record target với:")
print(f"  ekycStatus: {expression_values[':ekycStatus']}")
print(f"  kycCompleted: {expression_values[':kycCompleted']}")
print(f"  cvList: {len(expression_values[':cvList'])} CVs")
print(f"  skills: {expression_values[':skills']}")
print(f"  bio: '{expression_values[':bio']}' (xóa trắng)")

resp = table.update_item(
    Key={'userId': TARGET_ID},
    UpdateExpression=update_expression,
    ExpressionAttributeValues=expression_values,
    ReturnValues='ALL_NEW',
)

updated = resp.get('Attributes', {})
print()
print("✓ Merge thành công. Record sau khi cập nhật:")
print(f"  userId: {updated.get('userId')}")
print(f"  fullName: {updated.get('fullName')}")
print(f"  phone: {updated.get('phone')}")
print(f"  bio: '{updated.get('bio')}'")
print(f"  ekycStatus: {updated.get('ekycStatus')}")
print(f"  kycCompleted: {updated.get('kycCompleted')}")
print(f"  cvList count: {len(updated.get('cvList', []))}")
print(f"  skills: {updated.get('skills')}")
print(f"  updatedAt: {updated.get('updatedAt')}")

print()

# ─── BƯỚC 3: XÓA 5 RECORD RÁC ────────────────────────────────────────────────
print("=" * 60)
print("BƯỚC 3: XÓA 5 RECORD RÁC")
print("=" * 60)

# Lấy danh sách tất cả userId trừ target
all_items = scan_all_by_email(EMAIL)
to_delete = [item['userId'] for item in all_items if item['userId'] != TARGET_ID]

print(f"Sẽ xóa {len(to_delete)} records:")
for uid in to_delete:
    print(f"  - {uid}")

for uid in to_delete:
    table.delete_item(Key={'userId': uid})
    print(f"  ✓ Đã xóa: {uid}")

print()

# ─── BƯỚC 4: VERIFY ───────────────────────────────────────────────────────────
print("=" * 60)
print("BƯỚC 4: VERIFY — Kiểm tra lại record còn lại")
print("=" * 60)

remaining = scan_all_by_email(EMAIL)
print(f"Số record còn lại cho email {EMAIL}: {len(remaining)}")

if len(remaining) == 1 and remaining[0]['userId'] == TARGET_ID:
    r = remaining[0]
    print()
    print("✓ PASS — Chỉ còn đúng 1 record:")
    print(f"  userId: {r.get('userId')}")
    print(f"  fullName: {r.get('fullName')}")
    print(f"  phone: {r.get('phone')}")
    print(f"  bio: '{r.get('bio')}'")
    print(f"  ekycStatus: {r.get('ekycStatus')}")
    print(f"  kycCompleted: {r.get('kycCompleted')}")
    print(f"  cvList count: {len(r.get('cvList', []))}")
    print(f"  skills: {r.get('skills')}")
else:
    print("✗ FAIL — Kết quả không như kỳ vọng!")
    for r in remaining:
        print(f"  - {r.get('userId')}")

print()
print(f"File backup đã lưu tại: {backup_path}")
print("Hoàn thành.")
