#!/usr/bin/env python3
"""TLS front on :18082 for dal-login-us.heitaoglobal.com after iptables/hosts redirect."""
from __future__ import annotations

import os
import ssl
from http.server import ThreadingHTTPServer

from http_server import Handler, log

PORT = int(os.environ.get("DAL_HTTPS_PORT", "18082"))
DIR = os.path.dirname(os.path.abspath(__file__))


class TLSServer(ThreadingHTTPServer):
    def get_request(self):
        sock, addr = super().get_request()
        try:
            return self.ctx.wrap_socket(sock, server_side=True), addr
        except Exception as e:
            log("TLS handshake fail %s %r" % (addr, e))
            try:
                sock.close()
            except Exception:
                pass
            raise


def main() -> None:
    httpd = TLSServer(("0.0.0.0", PORT), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    try:
        ctx.set_ciphers("ALL:@SECLEVEL=0")
    except ssl.SSLError:
        pass
    ctx.load_cert_chain(os.path.join(DIR, "certs", "cert.pem"),
                        os.path.join(DIR, "certs", "key.pem"))
    httpd.ctx = ctx
    log("HTTPS login front :%d" % PORT)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
