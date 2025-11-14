# morrenus.py
import asyncio
import httpx
import aiofiles
import json
import os
import zipfile
from pathlib import Path
from colorama import Fore
from getpass import getpass

client = httpx.AsyncClient(verify=False)
SOURCE_DIR = Path.cwd()

async def save_api_key(api_key: str, password: str | None):
    """Save API key, optionally encrypted."""
    key_path = SOURCE_DIR / "morrenus_key.enc"
    if password:
        from Crypto.Cipher import AES
        from Crypto.Util.Padding import pad
        iv = os.urandom(16)
        cipher = AES.new(password.encode('utf-8').ljust(32, b'\0')[:32], AES.MODE_CBC, iv)
        ciphertext = cipher.encrypt(pad(api_key.encode('utf-8'), AES.block_size))
        async with aiofiles.open(key_path, "wb") as f:
            await f.write(iv + ciphertext)
    else:
        async with aiofiles.open(key_path, "w") as f:
            await f.write(api_key)
    return key_path

async def load_api_key(password: str | None) -> str | None:
    key_path = SOURCE_DIR / "morrenus_key.enc"
    if not key_path.exists():
        return None
    if password:
        from Crypto.Cipher import AES
        from Crypto.Util.Padding import unpad
        async with aiofiles.open(key_path, "rb") as f:
            data = await f.read()
        iv = data[:16]
        ciphertext = data[16:]
        cipher = AES.new(password.encode('utf-8').ljust(32, b'\0')[:32], AES.MODE_CBC, iv)
        return unpad(cipher.decrypt(ciphertext), AES.block_size).decode('utf-8')
    else:
        async with aiofiles.open(key_path, "r") as f:
            return await f.read()

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
    # Extract and remove old contents
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
    password = getpass("Enter password to encrypt API key (leave empty to store plaintext): ")
    api_key = await load_api_key(password)
    if not api_key:
        api_key = input("Enter your Morrenus API key: ").strip()
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
