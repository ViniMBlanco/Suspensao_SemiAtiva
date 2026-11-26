#!/usr/bin/env python3
"""Abre o laboratório 3D local; requer apenas Python 3 e navegador com WebGL 2."""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
import webbrowser


class LocalHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def log_message(self, *_args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765, help="Porta local (padrão: 8765)")
    parser.add_argument("--no-browser", action="store_true", help="Não abrir navegador automaticamente")
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error("A porta deve estar entre 0 e 65535.")
    directory = Path(__file__).resolve().parent / "simulador3d"
    handler = partial(LocalHandler, directory=str(directory))
    server = None
    for port in range(args.port, min(args.port + 10, 65536)):
        try:
            server = ThreadingHTTPServer(("127.0.0.1", port), handler)
            break
        except OSError as error:
            if error.errno not in (48, 98, 10048):
                raise
    if server is None:
        parser.exit(1, "As portas locais estão ocupadas. Use --port com outra porta.\n")
    url = "http://127.0.0.1:" + str(server.server_address[1]) + "/"
    print("\nSuspensão Lab — Simulador 3D", flush=True)
    print("Abra: " + url, flush=True)
    print("Mantenha este terminal aberto. Ctrl+C encerra o simulador.\n", flush=True)
    if not args.no_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nSimulador encerrado.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

