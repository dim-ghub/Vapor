import asyncio
import httpx
import aiofiles
import os
import zipfile
from pathlib import Path
from colorama import Fore
from Crypto.Cipher import AES
from Crypto.Protocol.KDF import PBKDF2
from Crypto.Random import get_random_bytes
import base64
import json

client = httpx.AsyncClient(verify=False)
SOURCE_DIR = Path.cwd()

async def save_api_key(api_key: str, password: str | None = None):
    """
    Save API key encrypted with AES-256 when password is provided.
    Store plaintext when password is empty.
    """
    key_path = SOURCE_DIR / "morrenus_key.enc"

    if not password:
        async with aiofiles.open(key_path, "w") as f:
            await f.write(api_key)
        return key_path

    salt = get_random_bytes(16)
    aes_key = PBKDF2(password, salt, dkLen=32, count=200000)

    iv = get_random_bytes(16)
    cipher = AES.new(aes_key, AES.MODE_CBC, iv)

    pad_len = 16 - (len(api_key) % 16)
    padded = api_key + chr(pad_len) * pad_len

    ciphertext = cipher.encrypt(padded.encode())

    data = {
        "encrypted": True,
        "salt": base64.b64encode(salt).decode(),
        "iv": base64.b64encode(iv).decode(),
        "cipher": base64.b64encode(ciphertext).decode()
    }

    async with aiofiles.open(key_path, "w") as f:
        await f.write(json.dumps(data))

    return key_path


async def load_api_key() -> str | None:
    """
    Load API key. If encrypted, ask for password and decrypt.
    If plaintext, return raw content.
    """
    key_path = SOURCE_DIR / "morrenus_key.enc"
    if not key_path.exists():
        return None

    async with aiofiles.open(key_path, "r") as f:
        content = await f.read()

    if content.strip().startswith("{"):
        data = json.loads(content)
        if not data.get("encrypted"):
            return None

        salt = base64.b64decode(data["salt"])
        iv = base64.b64decode(data["iv"])
        ciphertext = base64.b64decode(data["cipher"])

        from getpass import getpass
        password = getpass("Enter password to decrypt Morrenus key: ")

        aes_key = PBKDF2(password, salt, dkLen=32, count=200000)
        cipher = AES.new(aes_key, AES.MODE_CBC, iv)

        decrypted = cipher.decrypt(ciphertext)

        pad_len = decrypted[-1]
        decrypted = decrypted[:-pad_len]

        return decrypted.decode()

    return content

async def check_health() -> bool:
    url = "https://manifest.morrenus.xyz/api/v1/health"
    try:
        r = await client.get(url, timeout=10)
        if r.status_code == 200:
            data = r.json()
            return data.get("status") == "healthy"
    except Exception:
        return False
    return False

async def get_usage(api_key: str):
    url = "https://manifest.morrenus.xyz/api/v1/user/stats"
    headers = {"Authorization": f"Bearer {api_key}"}
    r = await client.get(url, headers=headers)
    if r.status_code == 401:
        return "unauthorized"
    data = r.json()
    uses_left = data.get("daily_limit", 0) - data.get("daily_usage", 0)
    return uses_left

async def check_appid(api_key: str, app_id: str) -> bool:
    url = f"https://manifest.morrenus.xyz/api/v1/status/{app_id}"
    headers = {"Authorization": f"Bearer {api_key}"}
    r = await client.get(url, headers=headers)
    if r.status_code == 401:
        return "unauthorized"
    if r.status_code == 200:
        return r.json().get("status") == "available"
    return False

async def download_manifest(api_key: str, app_id: str):
    url = f"https://manifest.morrenus.xyz/api/v1/manifest/{app_id}"
    headers = {"Authorization": f"Bearer {api_key}"}
    r = await client.get(url, headers=headers)
    if r.status_code != 200:
        return False
    zip_path = SOURCE_DIR / f"{app_id}.zip"
    async with aiofiles.open(zip_path, "wb") as f:
        await f.write(r.content)

    with zipfile.ZipFile(zip_path, "r") as zf:
        for member in zf.namelist():
            target_path = SOURCE_DIR / member
            if target_path.exists():
                if target_path.is_dir():
                    for file in target_path.iterdir():
                        file.unlink()
                    target_path.rmdir()
                else:
                    target_path.unlink()
            zf.extract(member, SOURCE_DIR)
    zip_path.unlink()
    return True

async def morrenus_fetch(app_id: str) -> bool:
    api_key = await load_api_key()

    if not api_key:
        api_key = input("Enter your Morrenus API key (leave empty to skip Morrenus): ").strip()
        if not api_key:
            print(f"{Fore.YELLOW}Skipping Morrenus as no API key provided.")
            return False

        from getpass import getpass
        password = getpass("Enter password to encrypt API key (leave empty to store plaintext): ")
        await save_api_key(api_key, password)

    if not await check_health():
        print(f"{Fore.RED}Morrenus API is down. Falling back to local repos.")
        return False

    uses_left = await get_usage(api_key)
    if uses_left == "unauthorized":
        print(f"{Fore.RED}API key unauthorized. Please enter a new key.")
        os.remove(SOURCE_DIR / "morrenus_key.enc")
        return await morrenus_fetch(app_id)

    print(f"Morrenus uses left today: {uses_left}")

    status = await check_appid(api_key, app_id)
    if status == "unauthorized":
        print(f"{Fore.RED}API key unauthorized. Please enter a new key.")
        os.remove(SOURCE_DIR / "morrenus_key.enc")
        return await morrenus_fetch(app_id)

    if status:
        print(f"{Fore.GREEN}AppID {app_id} is available on Morrenus. Downloading...")
        success = await download_manifest(api_key, app_id)
        return success
    else:
        print(f"{Fore.YELLOW}AppID {app_id} not available on Morrenus. Falling back to repos.")
        return False
