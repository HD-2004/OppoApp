import boto3
import json
from decimal import Decimal
from boto3.dynamodb.conditions import Attr


class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


dynamodb = boto3.resource('dynamodb', region_name='ap-southeast-1')
table = dynamodb.Table('CandidateProfiles')

response = table.scan(
    FilterExpression=Attr('email').eq('duypl2310@gmail.com')
)
items = response.get('Items', [])
while 'LastEvaluatedKey' in response:
    response = table.scan(
        FilterExpression=Attr('email').eq('duypl2310@gmail.com'),
        ExclusiveStartKey=response['LastEvaluatedKey']
    )
    items.extend(response.get('Items', []))

print(f"Total records found for duypl2310@gmail.com: {len(items)}")
for item in items:
    uid = item.get('userId', '')
    print(f"userId: {uid}")
    print(f"  prefix: {uid[:8]}")
    print(f"  fullName: {item.get('fullName')}")
    print(f"  phone: {item.get('phone')}")
    print(f"  createdAt: {item.get('createdAt')}")
    print(f"  updatedAt: {item.get('updatedAt')}")
    print(f"  kycCompleted: {item.get('kycCompleted')}")
    print(f"  profileCompleted: {item.get('profileCompleted')}")
    print(f"  bio: {item.get('bio')}")
    cvlist = item.get('cvList')
    if isinstance(cvlist, list):
        print(f"  cvList count: {len(cvlist)}")
    elif isinstance(cvlist, dict):
        print(f"  cvList keys: {list(cvlist.keys())}")
    else:
        print(f"  cvList: {cvlist}")
    print(f"  skills: {item.get('skills')}")
    print(f"  verificationStatus: {item.get('verificationStatus')}")
    print()

print("=== FULL JSON ===")
print(json.dumps(items, cls=DecimalEncoder, ensure_ascii=False, indent=2))
