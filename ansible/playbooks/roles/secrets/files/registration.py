"""
Generates the RegisterData fields required for Vaultwarden. 
Reads JSON from stdin to integrate with Ansible:
{"password":, "...", "email": "...", "kdf_iterations": "..."}
Emits JSON: {"masterpasswordHash", "key", "publicKey", "encryptedPrivateKey"}

Included here because `bitwardentools` is not actively maintained,
and `python-vaultwarden` is more challenging to maintain as a dependency -
when only this registration part is necessary. 
"""
import sys, json, os, base64
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand
from cryptography.hazmat.primitives import hashes, hmac, serialization
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.padding import PKCS7

def b64(b): return base64.b64encode(b).decode()

def pbkdf2(pw, salt, iters, length=32):
    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=length, salt=salt, iterations=iters)
    return kdf.derive(pw)

def hkdf_expand(prk, info, length):
    return HKDFExpand(algorithm=hashes.SHA256(), length=length, info=info.encode()).derive(prk)

def encstring_type2(plaintext, enc_key, mac_key):
    iv = os.urandom(16)
    padder = PKCS7(128).padder()
    padded = padder.update(plaintext) + padder.finalize()
    encryptor = Cipher(algorithms.AES(enc_key), modes.CBC(iv)).encryptor()
    ct = encryptor.update(padded) + encryptor.finalize()
    h = hmac.HMAC(mac_key, hashes.SHA256()); h.update(iv + ct)
    mac = h.finalize()
    return f"2.{b64(iv)}|{b64(ct)}|{b64(mac)}"

def main():
    d = json.load(sys.stdin)
    pw = d["password"].encode("utf-8")
    email = d["email"].strip().lower().encode("utf-8")
    iters = int(d["kdf_iterations"])

    master_key = pbkdf2(pw, email, iters, 32)
    master_pw_hash = b64(pbkdf2(master_key, pw, 1, 32))

    # Stretch master key → 32B enc + 32B mac (HKDF-Expand, no extract)
    stretched_enc = hkdf_expand(master_key, "enc", 32)
    stretched_mac = hkdf_expand(master_key, "mac", 32)

    # User key: 64 random bytes (32 enc + 32 mac used by the vault)
    user_key = os.urandom(64)
    protected_key = encstring_type2(user_key, stretched_enc, stretched_mac)

    # RSA keypair; private key wrapped under the user key halves
    rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_der = rsa_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo)
    private_pkcs8 = rsa_key.private_bytes(
        serialization.Encoding.DER,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption())
    enc_private = encstring_type2(private_pkcs8, user_key[:32], user_key[32:])

    print(json.dumps({
        "masterPasswordHash": master_pw_hash,
        "key": protected_key,
        "publicKey": b64(public_der),
        "encryptedPrivateKey": enc_private,
    }))

if __name__ == "__main__":
    main()
