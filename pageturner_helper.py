#!/usr/bin/env python3
# PageTurner-Helfer: liefert PDFs aus <Projektordner>/skripte und speichert Änderungen zurück.
# Start:  python pageturner_helper.py E:/Audio [Port] [--keep]
# Beendet sich selbst, wenn Reapers Web-Interface (Port 8080) nicht mehr erreichbar ist; --keep schaltet das ab.
import os, sys, json, shutil, time, socket, threading
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
KEEP = "--keep" in sys.argv
if not ARGS:
    sys.exit("Aufruf: python pageturner_helper.py <Wurzelordner> [Port] [--keep]")
ROOT = os.path.abspath(ARGS[0])
PORT = int(ARGS[1]) if len(ARGS) > 1 else 8081
SUB, REAPER_PORT = "skripte", "8080"

def inside(p):
    try:
        return os.path.commonpath([os.path.abspath(p), ROOT]) == ROOT
    except ValueError:
        return False

def is_pdf(p):
    return inside(p) and p.lower().endswith(".pdf")

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):  # keine Konsolenausgabe (nötig für pythonw)
        pass

    def origin_ok(self):  # nur Anfragen von der Reaper-Seite (Port 8080) zulassen
        o = self.headers.get("Origin")
        return o is None or o.rsplit(":", 1)[-1] == REAPER_PORT

    def send(self, code, body=b"", ctype="text/plain"):
        self.send_response(code)
        o = self.headers.get("Origin")
        if o:
            self.send_header("Access-Control-Allow-Origin", o)
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Range")
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send(204)

    def do_GET(self):
        if not self.origin_ok():
            return self.send(403)
        u = urlparse(self.path); q = parse_qs(u.query)
        if u.path == "/ping":
            return self.send(200, b"ok")
        if u.path == "/list":
            d = os.path.join(q.get("dir", [""])[0], SUB)
            if not inside(d) or not os.path.isdir(d):
                return self.send(200, b"[]", "application/json")
            files = sorted(f for f in os.listdir(d) if f.lower().endswith(".pdf"))
            return self.send(200, json.dumps(files).encode(), "application/json")
        if u.path == "/file":
            p = q.get("path", [""])[0]
            if not is_pdf(p) or not os.path.isfile(p):
                return self.send(404)
            with open(p, "rb") as f:
                return self.send(200, f.read(), "application/pdf")
        self.send(404)

    def do_POST(self):
        if not self.origin_ok():
            return self.send(403)
        u = urlparse(self.path); q = parse_qs(u.query)
        p = q.get("path", [""])[0]
        if u.path != "/save" or not is_pdf(p) or not os.path.isfile(p):
            return self.send(404)
        data = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if not data.startswith(b"%PDF"):
            return self.send(400)
        bdir = os.path.join(os.path.dirname(p), "_backup")
        os.makedirs(bdir, exist_ok=True)
        base = os.path.splitext(os.path.basename(p))[0]
        shutil.copy2(p, os.path.join(bdir, f"{base}_{time.strftime('%Y-%m-%d_%H-%M-%S')}.pdf"))
        for f in sorted(x for x in os.listdir(bdir) if x.startswith(base + "_"))[:-20]:
            os.remove(os.path.join(bdir, f))   # nur die letzten 20 Sicherungen behalten
        with open(p + ".tmp", "wb") as f:
            f.write(data)
        os.replace(p + ".tmp", p)
        self.send(200, b"saved")

def listening(port):
    try:
        socket.create_connection(("127.0.0.1", port), 0.5).close()
        return True
    except OSError:
        return False

def watch():  # beendet den Helfer, wenn Reaper bzw. dessen Web-Interface weg ist
    fails = 0
    while True:
        time.sleep(5)
        fails = 0 if listening(int(REAPER_PORT)) else fails + 1
        if fails >= 3:
            os._exit(0)

if listening(PORT):
    sys.exit("PageTurner-Helfer läuft bereits.")
if not KEEP:
    threading.Thread(target=watch, daemon=True).start()
print(f"PageTurner-Helfer läuft auf Port {PORT}, Wurzelordner: {ROOT}")
ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
