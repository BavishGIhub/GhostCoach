# ──────────────────────────────────────────────
# KAGGLE NOTEBOOK CELL 1: INSTALL (RUN ONCE)
# ──────────────────────────────────────────────
# !pip install pyngrok ultralytics --quiet
# Only run manual install if ngrok is missing to save time
# !if [ ! -f "/usr/local/bin/ngrok" ]; then \
#    curl -s -L -o ngrok.tgz https://bin.ngrok.com/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz && \
#    tar -xvzf ngrok.tgz && \
#    chmod +x ngrok && \
#    mv ngrok /usr/local/bin/ && \
#    rm ngrok.tgz; \
# fi

# ──────────────────────────────────────────────
# KAGGLE NOTEBOOK CELL 2: START SERVER
# ──────────────────────────────────────────────
import os, time, torch, threading
from datetime import datetime
from pyngrok import ngrok, conf
import uvicorn

# 1. PRE-START CLEANUP (Essential for "Save Version" stability)
print("🧹 Cleaning up existing tunnels and ports...")
ngrok.kill()
os.system("fuser -k 8000/tcp > /dev/null 2>&1") # Kill any existing server on 8000
time.sleep(1) # Wait for OS to release port

# 2. NGROK CONFIGURATION
# Point to the manually installed binary to bypass 403 errors
pyngrok_config = conf.PyngrokConfig(ngrok_path="/usr/local/bin/ngrok")
conf.set_default(pyngrok_config)

# INSERT YOUR TOKEN FROM: https://dashboard.ngrok.com/get-started/your-authtoken
NGROK_TOKEN = "YOUR_NGROK_TOKEN_HERE"
ngrok.set_auth_token(NGROK_TOKEN)

# 3. START TUNNEL
try:
    public_url = ngrok.connect(8000)
    print(f"\n{'='*60}")
    print(f"🚀 GHOST COACH API IS LIVE!")
    print(f"📡 Public URL: {public_url}")
    print(f"🔗 Update your Flutter app setting to this URL")
    print(f"⏰ Started at: {datetime.now().strftime('%H:%M:%S')}")
    print(f"{'='*60}\n")
except Exception as e:
    print(f"❌ FAILED TO START NGROK: {e}")

# 4. RUN SERVER
# We use a thread so the notebook cell doesn't block indefinitely 
# if you are in interactive mode, but it stays alive for 'Save Version'
def run_server():
    print("🔋 Initializing AI Models (YOLOv8 + V-JEPA)...")
    uvicorn.run("server:app", host="0.0.0.0", port=8000, log_level="info")

# Start server in background thread
server_thread = threading.Thread(target=run_server, daemon=True)
server_thread.start()

# Keep cell alive if running as 'Save Version' / 'Run All'
# This prevents the notebook job from finishing and killing the server
print("📟 Server is running. Monitor logs for incoming requests.")
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("🛑 Server stopped by user.")
