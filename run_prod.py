import os
from app import app, socketio

port = int(os.environ.get("PORT", 5000))
socketio.run(app, host="0.0.0.0", port=port, debug=False, allow_unsafe_werkzeug=False)
