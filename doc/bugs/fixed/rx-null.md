# null in XMPP logs

The logs frequently report both sending and receiving "null". Possible causes might be receiving whitespace, though this seems unlikely given the frequency.

On rarer occasions, the logs show two apparently random ASCII characters, such as "52" or "-M'."

## Resolution
- Cancel the plaintext socket listener before switching to TLS so encrypted bytes are not decoded/logged.
