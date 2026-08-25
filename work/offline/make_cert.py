#!/usr/bin/env python3
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID

out = Path(__file__).resolve().parent / "certs"
out.mkdir(exist_ok=True)
key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
host = "dal-login-us.heitaoglobal.com"
name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, host)])
now = datetime.now(timezone.utc)
cert = (
    x509.CertificateBuilder()
    .subject_name(name)
    .issuer_name(name)
    .public_key(key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(now - timedelta(days=1))
    .not_valid_after(now + timedelta(days=3650))
    .add_extension(x509.SubjectAlternativeName([
        x509.DNSName(host),
        x509.DNSName("localhost"),
        x509.IPAddress(__import__("ipaddress").IPv4Address("127.0.0.1")),
    ]), critical=False)
    .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
    .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
    .sign(key, hashes.SHA256())
)
(out / "key.pem").write_bytes(key.private_bytes(
    serialization.Encoding.PEM,
    serialization.PrivateFormat.TraditionalOpenSSL,
    serialization.NoEncryption(),
))
(out / "cert.pem").write_bytes(cert.public_bytes(serialization.Encoding.PEM))
# android system CA hash
der = cert.public_bytes(serialization.Encoding.DER)
import hashlib
h = hashlib.md5(der).hexdigest()  # not the android hash
# Android uses subject_hash_old
print("wrote", out)
print("subject", host)
