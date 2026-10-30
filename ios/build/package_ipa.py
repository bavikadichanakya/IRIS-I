import os
import shutil
import zipfile

device_dir = 'a:/iOS Assistant/ios/build/Device'
payload_dir = 'a:/iOS Assistant/ios/build/Payload'
app_dir = os.path.join(payload_dir, 'IRIS-I.app')
ipa_path = 'a:/iOS Assistant/ios/build/IRIS-I.ipa'

if os.path.exists(payload_dir):
    shutil.rmtree(payload_dir)
os.makedirs(app_dir, exist_ok=True)

# Copy all files from Device into Payload/IRIS-I.app
for item in os.listdir(device_dir):
    s = os.path.join(device_dir, item)
    d = os.path.join(app_dir, item)
    if os.path.isdir(s):
        shutil.copytree(s, d)
    else:
        shutil.copy2(s, d)

print(f'Copied app into {app_dir}')

# Zip Payload into IRIS-I.ipa
if os.path.exists(ipa_path):
    os.remove(ipa_path)

with zipfile.ZipFile(ipa_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(payload_dir):
        for file in files:
            full_path = os.path.join(root, file)
            # Store relative to build/ so root entry in zip is Payload/...
            rel_path = os.path.relpath(full_path, 'a:/iOS Assistant/ios/build')
            zipf.write(full_path, rel_path)

shutil.rmtree(payload_dir)
print(f'Created IPA at {ipa_path} ({os.path.getsize(ipa_path)} bytes)')

