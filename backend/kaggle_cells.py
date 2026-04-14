# ╔═══════════════════════════════════════════════════════════════╗
# ║  GHOST COACH - KAGGLE NOTEBOOK                              ║
# ║  Copy each section into a SEPARATE Kaggle notebook cell.    ║
# ║  You need 3 cells total. Run them in order.                 ║
# ╚═══════════════════════════════════════════════════════════════╝


# ══════════════════════════════════════════════════════════════
# ██  CELL 1 OF 3: INSTALL DEPENDENCIES
# ══════════════════════════════════════════════════════════════
# Paste everything between the ═══ lines into Kaggle Cell 1.
# This installs pyngrok, ultralytics, and manually downloads
# the ngrok binary to bypass the HTTP 403 Forbidden error.
# ══════════════════════════════════════════════════════════════

!pip install pyngrok ultralytics --quiet

# Manually download ngrok binary (bypasses 403 Forbidden on Kaggle)
import os
if not os.path.exists("/usr/local/bin/ngrok"):
    !curl -s -L -o /tmp/ngrok.tgz https://bin.ngrok.com/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    !tar -xzf /tmp/ngrok.tgz -C /tmp/
    !chmod +x /tmp/ngrok
    !mv /tmp/ngrok /usr/local/bin/
    !rm -f /tmp/ngrok.tgz
    print("✅ ngrok binary installed successfully")
else:
    print("✅ ngrok binary already installed")


# ══════════════════════════════════════════════════════════════
# ██  CELL 2 OF 3: WRITE SERVER CODE
# ══════════════════════════════════════════════════════════════
# Paste your ENTIRE server.py file (which starts with
# %%writefile server.py) into Kaggle Cell 2.
#
# You already have this — it's the file at:
#   backend/server.py
#
# Just copy-paste the ENTIRE contents of that file as Cell 2.
# It will write server.py to the Kaggle filesystem.
# ══════════════════════════════════════════════════════════════


# ══════════════════════════════════════════════════════════════
# ██  CELL 3 OF 3: LAUNCH SERVER + NGROK TUNNEL
# ══════════════════════════════════════════════════════════════
# Paste everything below into Kaggle Cell 3.
# ⚠️ IMPORTANT: Replace YOUR_NGROK_TOKEN_HERE with your
#    actual token from https://dashboard.ngrok.com
# ══════════════════════════════════════════════════════════════

import os, time, threading
from datetime import datetime
from pyngrok import ngrok, conf
import uvicorn

# ── Step 1: Clean up any previous runs ──
print("🧹 Cleaning up previous sessions...")
try:
    ngrok.kill()
except:
    pass
os.system("fuser -k 8000/tcp > /dev/null 2>&1")
time.sleep(2)  # Give OS time to fully release the port

# ── Step 2: Configure ngrok to use our manually installed binary ──
pyngrok_config = conf.PyngrokConfig(ngrok_path="/usr/local/bin/ngrok")
conf.set_default(pyngrok_config)

# ── Step 3: Set your ngrok auth token ──
# ⚠️⚠️⚠️ REPLACE THIS WITH YOUR ACTUAL TOKEN ⚠️⚠️⚠️
NGROK_TOKEN = "3BGCvuDP2zRCvE6cMXS3NEdUgjm_3HMMe5CZ68f6rpgHYPcKT"
ngrok.set_auth_token(NGROK_TOKEN)

# ── Step 4: Start the ngrok tunnel ──
try:
    public_url = ngrok.connect(8000)
    print(f"\n{'='*60}")
    print(f"🚀 GHOST COACH API IS LIVE!")
    print(f"📡 Public URL: {public_url}")
    print(f"🔗 Copy this URL into your Flutter app's Server URL setting")
    print(f"⏰ Started at: {datetime.now().strftime('%H:%M:%S')}")
    print(f"{'='*60}\n")
except Exception as e:
    print(f"❌ Ngrok tunnel failed: {e}")
    print("Try restarting the notebook kernel and running all cells again.")

# ── Step 5: Start the FastAPI server ──
def run_server():
    print("🔋 Loading AI models (YOLOv8 + V-JEPA 2)... This takes ~60 seconds.")
    uvicorn.run("server:app", host="0.0.0.0", port=8000, log_level="info")

server_thread = threading.Thread(target=run_server, daemon=True)
server_thread.start()

# ── Step 6: Keep the cell alive (required for "Save Version" runs) ──
print("📟 Server thread started. Waiting for models to load...")
print("   You'll see '✅ Application startup complete' when ready.\n")
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("\n🛑 Server stopped by user.")
