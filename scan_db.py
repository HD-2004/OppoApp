import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('StandardApplications')
response = table.scan()
items = response.get('Items', [])

active_apps = [item for item in items if item.get('status') in ['accepted', 'completed_pending_candidate']]

print(f"Total active applications: {len(active_apps)}")
for app in active_apps:
    out = [
        f"CandidateId: {app.get('candidateId')}",
        f"  AppId: {app.get('applicationId')}",
        f"  status: {app.get('status')}",
        f"  jobId: {app.get('jobId')}",
        f"  jobTitle: {app.get('jobTitle')}",
        f"  employerId: {app.get('employerId')}",
        f"  employerName: {app.get('employerName')}"
    ]
    for line in out:
        print(line.encode('ascii', errors='backslashreplace').decode('ascii'))
    print("")
