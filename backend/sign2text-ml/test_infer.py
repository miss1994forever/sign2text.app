import urllib.request
import json
import torch
import os
import sys

# Update path to import local modules correctly
sys.path.append(os.getcwd())
from app.keypoints import get_expected_keypoint_count

print("Loading runtime...")
try:
    req = urllib.request.Request("http://127.0.0.1:6006/api/v1/runtime/load", data=b"{}", headers={'Content-Type': 'application/json'})
    resp = urllib.request.urlopen(req)
    print("Runtime Load API HTTP", resp.getcode())
except Exception as e:
    print("Load Error:", getattr(e, 'read', lambda: str(e))())

print("Generating dummy tensors...")
# Use the same keypoint components as in the yaml config
K = get_expected_keypoint_count(['pose', 'mouth_half', 'hand'])
# Use enough frames to satisfy the sliding window (e.g., 24 frames > 16 window size)
video_tensor = torch.zeros((1, 24, 3, 224, 224))
keypoint_tensor = torch.zeros((1, 24, K, 3))

v_path = os.path.abspath("dummy_video.pt")
k_path = os.path.abspath("dummy_keypoint.pt")
torch.save(video_tensor, v_path)
torch.save(keypoint_tensor, k_path)

print("Calling infer-tensors endpoint...")
req_data = json.dumps({
    "videoTensorPath": v_path,
    "keypointTensorPath": k_path
}).encode('utf-8')

req = urllib.request.Request("http://127.0.0.1:6006/api/v1/debug/infer-tensors", data=req_data, headers={'Content-Type': 'application/json'})
try:
    resp = urllib.request.urlopen(req)
    print("Infer Result:\n", json.dumps(json.loads(resp.read().decode()), indent=2, ensure_ascii=False))
except urllib.error.HTTPError as e:
    print("Infer HTTP Error:", e.code, e.read().decode())

