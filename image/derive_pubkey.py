"""Derive the Nostr x-only pubkey (hex) from an nsec/hex private key on stdin.
Self-test: BIP340 vector (d=3). Pure stdlib; used by the pod entrypoint to
set git user.signingkey for git-sign-nostr."""
import sys

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

def bech32_decode(s):
    s = s.strip().lower()
    pos = s.rfind("1")
    data = [CHARSET.find(c) for c in s[pos+1:]]
    if -1 in data:
        raise ValueError("bad bech32 char")
    bits, acc, out = 0, 0, []
    for v in data[:-6]:  # strip checksum
        acc = (acc << 5) | v
        bits += 5
        if bits >= 8:
            bits -= 8
            out.append((acc >> bits) & 0xFF)
    return bytes(out)

P = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G = (0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
     0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8)

def _add(a, b):
    if a is None: return b
    if b is None: return a
    if a[0] == b[0] and (a[1] + b[1]) % P == 0: return None
    if a == b:
        l = (3 * a[0] * a[0]) * pow(2 * a[1], P - 2, P) % P
    else:
        l = (b[1] - a[1]) * pow(b[0] - a[0], P - 2, P) % P
    x = (l * l - a[0] - b[0]) % P
    return (x, (l * (a[0] - x) - a[1]) % P)

def pubkey_x(d):
    if not 0 < d < N: raise ValueError("key out of range")
    r, q = None, G
    while d:
        if d & 1: r = _add(r, q)
        q = _add(q, q); d >>= 1
    return "%064x" % r[0]

assert pubkey_x(3) == "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"

if __name__ == "__main__":
    raw = sys.stdin.read().strip()
    d = int.from_bytes(bech32_decode(raw), "big") if raw.startswith("nsec1") else int(raw, 16)
    print(pubkey_x(d))
