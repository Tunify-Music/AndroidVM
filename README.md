# Cloud Hosted Android-x86 Virtual Machine

Adaptive, lightweight x86_64 Android system running inside a standalone container layer, complete with streaming interactive HTML5 interface access.

## 🚀 How to Deploy via Google Cloud Shell

Paste these commands into your Cloud Shell terminal workspace:

```bash
# 1. Pull down repository files
git clone [https://github.com/Tunify-Music/AndroidVM](https://github.com/Tunify-Music/AndroidVM)
cd AndroidVM

# 2. Build deployment target image
docker build -t cloud-android .

# 3. Fire up background runtime engine
docker run -d -p 8080:8080 --name android-instance cloud-android
