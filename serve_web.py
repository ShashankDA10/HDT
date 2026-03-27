#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

PORT = 9090
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DIRECTORY = os.path.join(SCRIPT_DIR, "build/web")

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

if __name__ == "__main__":
    if not os.path.exists(DIRECTORY):
        print(f"Error: Directory {DIRECTORY} does not exist!")
        print("Please run 'flutter build web' first.")
        sys.exit(1)
    
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"Server running at http://0.0.0.0:{PORT}/")
        print(f"Access from your phone: http://93.127.195.245:{PORT}/")
        print("Press Ctrl+C to stop the server")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped")

