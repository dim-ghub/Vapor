import sys
import os
import re
import traceback
import time
import logging
import asyncio
import aiofiles
import colorlog
import httpx
import ujson as json
import vdf
import base64
import zlib
import struct
import pygob
import collections
from typing import Any
from pathlib import Path
from colorama import init, Fore, Back, Style
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad
from modules import morrenus

init()
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

lock = asyncio.Lock()
client = httpx.AsyncClient(trust_env=True, verify=False)

DEPOTDOWNLOADER = "DepotDownloaderMod"
DEPOTDOWNLOADER_ARGS = "-max-downloads 256 -verify-all"

DEFAULT_CONFIG = {
    "Github_Personal_Token": "",
    "Custom_Steam_Path": "",
    "QA1": "Friendly reminder: Github_Personal_Token can be found in Github settings at the bottom developer options, see tutorial for details",
    "Tutorial": "https://ikunshare.com/Onekey_tutorial"
}

LOG_FORMAT = '%(log_color)s%(message)s'
LOG_COLORS = {
    'INFO': 'cyan',
    'WARNING': 'yellow',
    'ERROR': 'red',
    'CRITICAL': 'purple',
}


def init_log(level=logging.DEBUG) -> logging.Logger:
    """ Initialize logging module """
    logger = logging.getLogger('Onekey')
    logger.setLevel(level)

    stream_handler = logging.StreamHandler()
    stream_handler.setLevel(level)

    fmt = colorlog.ColoredFormatter(LOG_FORMAT, log_colors=LOG_COLORS)
    stream_handler.setFormatter(fmt)

    if not logger.handlers:
        logger.addHandler(stream_handler)

    return logger


log = init_log()


def init():
    """ Output initialization information """
    log.info('DepotDownloadermod')
    log.info('Original author: oureveryday | Edited by: DiM')
    log.warning('This project is licensed under the GNU General Public License v3 open-source license and may not be used for commercial purposes.')

def stack_error(exception: Exception) -> str:
    """ Process error stack trace """
    stack_trace = traceback.format_exception(
        type(exception), exception, exception.__traceback__)
    return ''.join(stack_trace)


async def gen_config_file():
    """ Generate configuration file """
    try:
        async with aiofiles.open("./config.json", mode="w", encoding="utf-8") as f:
            await f.write(json.dumps(DEFAULT_CONFIG, indent=2, ensure_ascii=False, escape_forward_slashes=False))

        log.info('This may be the first run or configuration reset, please fill in the configuration file and restart the program')
    except KeyboardInterrupt:
        log.info("Program exited")
    except Exception as e:
        log.error(f'Configuration file generation failed, {stack_error(e)}')


async def load_config():
    """ Load configuration file """
    if not os.path.exists('./config.json'):
        await gen_config_file()
        sys.exit()

    try:
        async with aiofiles.open("./config.json", mode="r", encoding="utf-8") as f:
            config = json.loads(await f.read())
            return config
    except KeyboardInterrupt:
        log.info("Program exited")
    except Exception as e:
        log.error(f"Configuration file loading failed, reason: {stack_error(e)}, resetting configuration file...")
        os.remove("./config.json")
        await gen_config_file()
        sys.exit()

config = asyncio.run(load_config())


async def check_github_api_rate_limit(headers):
    """ Check Github request limit """

    if headers != None:
        log.info(f"You have configured Github Token")

    url = 'https://api.github.com/rate_limit'
    try:
        r = await client.get(url, headers=headers)
        r_json = r.json()
        if r.status_code == 200:
            rate_limit = r_json.get('rate', {})
            remaining_requests = rate_limit.get('remaining', 0)
            reset_time = rate_limit.get('reset', 0)
            reset_time_formatted = time.strftime(
                '%Y-%m-%d %H:%M:%S', time.localtime(reset_time))
            log.info(f'Number of requests remaining: {remaining_requests}')
            if remaining_requests == 0:
                log.warning(f'GitHub API request limit exhausted, will reset at {reset_time_formatted}, it is recommended to generate one and fill it in the configuration file')
        else:
            log.error('Github request limit check failed, network error')
    except KeyboardInterrupt:
        log.info("Program exited")
    except httpx.ConnectError as e:
        log.error(f'Failed to check Github API request limit, {stack_error(e)}')
    except httpx.ConnectTimeout as e:
        log.error(f'Timeout checking Github API request limit: {stack_error(e)}')
    except Exception as e:
        log.error(f'An error occurred: {stack_error(e)}')
    
def csharp_gzip(b64_string):
    # Base64 decode
    compressed_data = base64.b64decode(b64_string)
    

    if len(compressed_data) <= 18:
        raise ValueError("Data too short to be gzip format")
        
    decompressor = zlib.decompressobj(-zlib.MAX_WBITS)
    # skip gz header
    decompressed_data = decompressor.decompress(compressed_data[10:])
    decompressed_data += decompressor.flush()
    
    return decompressed_data.decode('utf-8')

async def get(sha: str, path: str, repo: str):
    url_list = [
        f'https://raw.githubusercontent.com/{repo}/{sha}/{path}'
    ]
    retry = 3
    while retry > 0:
        for url in url_list:
            try:
                r = await client.get(url, timeout=30)
                if r.status_code == 200:
                    return r.read()
                else:
                    log.error(f'Fetch failed: {path} - Status code: {r.status_code}')
            except KeyboardInterrupt:
                log.info("Program exited")
            except httpx.ConnectError as e:
                log.error(f'Fetch failed: {path} - Connection error: {str(e)}')
            except httpx.ConnectTimeout as e:
                log.error(f'Connection timeout: {url} - Error: {str(e)}')

        retry -= 1
        log.warning(f'Retries remaining: {retry} - {path}')

    log.error(f'Exceeded maximum retry attempts: {path}')
    raise Exception(f'Unable to download: {path}')

async def get_manifest(app_id: str, sha: str, path: str, repo: str) -> list:
    collected_depots = []
    depot_cache_path = Path(os.getcwd())
    try:
        if path.endswith('.manifest'):
            save_path = depot_cache_path / path
            if save_path.exists():
                log.warning(f'Manifest already exists: {save_path}')
                return collected_depots
            content = await get(sha, path, repo)
            log.info(f'Manifest downloaded: {path}')
            async with aiofiles.open(save_path, 'wb') as f:
                await f.write(content)
        elif path == 'Key.vdf' or path == 'key.vdf':
            content = await get(sha, path, repo)
            log.info(f'Key downloaded: {path}')
            depots_config = vdf.loads(content.decode('utf-8'))
            if depots_config:
                async with aiofiles.open(depot_cache_path / f"{app_id}.key", 'w', encoding="utf-8") as f:
                    for depot_id, depot_info in depots_config['depots'].items():
                        if (repo == 'sean-who/ManifestAutoUpdate'):
                            decryptedkey = await xor_decrypt(b"Scalping dogs, I'll fuck you",bytearray.fromhex(depot_info["DecryptionKey"]))
                            await f.write(f'{depot_id};{decryptedkey.decode("utf-8")}\n')
                        else:
                            await f.write(f'{depot_id};{depot_info["DecryptionKey"]}\n')
    except KeyboardInterrupt:
        log.info("Program exited")
    except Exception as e:
        log.error(f'Processing failed: {path} - {stack_error(e)}')
        raise
    return collected_depots

async def get_data(app_id: str, path: str, repo: str) -> list:
    AppInfo = collections.namedtuple('AppInfo', ['Appid','Licenses', 'App', 'Depots', 'EncryptedAppTicket', 'AppOwnershipTicket'])
    collected_depots = []
    depot_cache_path = Path(os.getcwd())
    try:
        content = await get('main', path, repo)
        content_dec = await symmetric_decrypt(b" s  t  e  a  m  ", content)
        content_dec = await xor_decrypt(b"hail",content_dec)
        content_gob = pygob.load_all(bytes(content_dec))
        app_info = AppInfo._make(*content_gob)
        keyfile = await aiofiles.open(depot_cache_path / f"{app_id}.key", 'w', encoding="utf-8")
        for depot in app_info.Depots:
            filename = f"{depot.Id}_{depot.Manifests.Id}.manifest"
            save_path = depot_cache_path / filename
            if save_path.exists():
                log.warning(f'Manifest already exists: {save_path}')
            else:
                async with aiofiles.open(save_path, 'wb') as f:
                    await f.write(depot.Manifests.Data)
            await keyfile.write(f'{depot.Id};{depot.Decryptkey.hex()}\n')
            collected_depots.append(filename)
        keyfile.close()
    except KeyboardInterrupt:
        log.info("Program exited")
    except Exception as e:
        log.error(f'Processing failed: {path} - {stack_error(e)}')
        raise
    return collected_depots

async def get_data_local(app_id: str) -> list:
    collected_depots = []
    depot_cache_path = Path(os.getcwd())
    try:
        lua_file_path = depot_cache_path / f"{app_id}.lua"
        st_file_path = depot_cache_path / f"{app_id}.st"
        if not lua_file_path.exists() and not st_file_path.exists():
            log.error(f'Lua file not found: {lua_file_path} or st file: {st_file_path}')
            raise FileNotFoundError
        if lua_file_path.exists():
            luafile = await aiofiles.open(lua_file_path, 'r', encoding="utf-8")
            content = await luafile.read()
            await luafile.close()

        if st_file_path.exists():
            stfile = await aiofiles.open(st_file_path, 'rb')
            content = await stfile.read()
            await stfile.close()
            # Parse header
            header = content[:12]
            xorkey, size, xorkeyverify = struct.unpack('III', header)
            xorkey ^= 0xFFFEA4C8
            xorkey &= 0xFF
            # Parse data
            data = bytearray(content[12:12+size])
            for i in range(len(data)):
                data[i] = data[i] ^ xorkey
            # Read data
            decompressed_data = zlib.decompress(data)
            content = decompressed_data[512:].decode('utf-8')
            

        keyfile = await aiofiles.open(depot_cache_path / f"{app_id}.key", 'w', encoding="utf-8")
        # Parse addappid and setManifestid
        addappid_pattern = re.compile(r'addappid\(\s*(\d+)\s*(?:,\s*\d+\s*,\s*"([0-9a-f]+)"\s*)?\)')
        setmanifestid_pattern = re.compile(r'setManifestid\(\s*(\d+)\s*,\s*"(\d+)"\s*(?:,\s*\d+\s*)?\)')

        for match in addappid_pattern.finditer(content):
            depot_id = match.group(1)
            decrypt_key = match.group(2) if match.group(2) else None
            if decrypt_key:
                log.info(f'Parsed addappid: depot_id={depot_id}, decrypt_key={decrypt_key}')
                await keyfile.write(f'{depot_id};{decrypt_key}\n')

        for match in setmanifestid_pattern.finditer(content):
            depot_id = match.group(1)
            manifest_id = match.group(2)
            filename = f"{depot_id}_{manifest_id}.manifest"
            save_path = depot_cache_path / filename
            log.info(f'Parsed setManifestid: depot_id={depot_id}, manifest_id={manifest_id}')
            if save_path.exists():
                log.info(f'Manifest exists: {save_path}')
                collected_depots.append(filename)
            else:
                log.info(f'Manifest not found: {save_path}')
            
    except KeyboardInterrupt:
        log.info("Program exited")
    except Exception as e:
        log.error(f'Processing failed: {stack_error(e)}')
        raise
    return collected_depots

async def depotdownloadermod_add(app_id: str, manifests: list) -> bool:
    async with lock:
        log.info(f'DepotDownloaderMod download script generation: {app_id}.sh')
        try:
            async with aiofiles.open(f'{app_id}.sh', mode="w", encoding="utf-8") as sh_file:
                # Shebang for Linux
                await sh_file.write("#!/usr/bin/env bash\n\n")
                for manifest in manifests:
                    depot_id = manifest[0:manifest.find('_')]
                    manifest_id = manifest[manifest.find('_') + 1:manifest.find('.')]
                    await sh_file.write(f'{DEPOTDOWNLOADER} -app {app_id} -depot {depot_id} -manifest {manifest_id} -manifestfile {manifest} -depotkeys {app_id}.key {DEPOTDOWNLOADER_ARGS}\n')
        except Exception as e:
            log.error(f'Error generating script: {e}')
            return False

    # Make the .sh executable
    os.chmod(f'{app_id}.sh', 0o755)
    return True

async def fetch_info(url, headers) -> str | None:
    try:
        r = await client.get(url, headers=headers)
        return r.json()
    except KeyboardInterrupt:
        log.info("Program exited")
    except Exception as e:
        log.error(f'Failed to fetch information: {stack_error(e)}')
        return None
    except httpx.ConnectTimeout as e:
        log.error(f'Timeout fetching information: {stack_error(e)}')
        return None
    
async def get_pro_token():
    try:
        r = await client.get("https://gitee.com/pjy612/sai/raw/master/free")
        return csharp_gzip(r.text)
    except KeyboardInterrupt:
        log.info("Program exited")
    except Exception as e:
        log.error(f'Failed to fetch information: {stack_error(e)}')
        return None
    except httpx.ConnectTimeout as e:
        log.error(f'Timeout fetching information: {stack_error(e)}')
        return None
    
async def symmetric_decrypt(key, ciphertext):
    """
    Decrypt data using AES
    key: AES key byte string
    ciphertext: Byte string to be decrypted, including IV
    """
    try:
    # Separate IV and encrypted data
        iv = ciphertext[:AES.block_size]
        data = ciphertext[AES.block_size:]
        
        # Decrypt IV using ECB mode
        cipher_ecb = AES.new(key, AES.MODE_ECB)
        iv = cipher_ecb.decrypt(iv)
        
        # Decrypt data using CBC mode with decrypted IV
        cipher_cbc = AES.new(key, AES.MODE_CBC, iv)
        decrypted = cipher_cbc.decrypt(data)
        
        # Remove PKCS7 padding
        return unpad(decrypted, AES.block_size)
    except Exception as e:
        log.error(f'Decryption failed: {stack_error(e)}')
        return None

async def xor_decrypt(key, ciphertext):
    """
    Decrypt data using XOR
    key: XOR key byte string
    ciphertext: Byte string to be decrypted
    """
    try:
        decrypted = bytearray(len(ciphertext))
        for i in range(len(ciphertext)):
            decrypted[i] = ciphertext[i] ^ key[i % len(key)]
        return bytes(decrypted)
    except Exception as e:
        log.error(f'Decryption failed: {stack_error(e)}')
        return None

async def get_latest_repo_info(repos: list, app_id: str, headers) -> Any | None:
    if len(repos) == 1:
        return repos[0], None
        
    latest_date = None
    selected_repo = None
    for repo in repos:
        if repo == "luckygametools/steam-cfg" or repo == "Steam tools .lua/.st script (Local file)":
            continue
            
        url = f'https://api.github.com/repos/{repo}/branches/{app_id}'
        r_json = await fetch_info(url, headers)
        if r_json and 'commit' in r_json:
            date = r_json['commit']['commit']['author']['date']
            if (latest_date is None) or (date > latest_date):
                latest_date = date
                selected_repo = repo

    return selected_repo, latest_date

async def printedwaste_download(app_id: str) -> bool:
    url = f"https://api.printedwaste.com/gfk/download/{app_id}"
    headers = {
        "Authorization": "Bearer dGhpc19pcyBhX3JhbmRvbV90b2tlbg=="
    }
    depot_cache_path = Path(os.getcwd())
    try:
        r = await client.get(url, headers=headers, timeout=60)
        r.raise_for_status()
        content = await r.aread()  # Asynchronously read all content
        
        import io, zipfile
        zip_mem = io.BytesIO(content)
        with zipfile.ZipFile(zip_mem) as zf:
            for file in zf.namelist():
                if file.endswith(('.st', '.lua', '.manifest')):
                    file_content = zf.read(file)
                    log.info(f"Extracting file: {file}, size: {len(file_content)} bytes")    
                    async with aiofiles.open(depot_cache_path / Path(file).name, 'wb') as f:
                        await f.write(file_content)        
        return True
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            log.error("Manifest not found")
            return False
        else:
            log.error(f'Processing failed: {stack_error(e)}')
            raise
    except KeyboardInterrupt:
        log.info("Program exited")
    except Exception as e:
        log.error(f'Processing failed: {stack_error(e)}')
        raise

async def main(app_id: str, repos: list) -> bool:
    app_id_list = list(filter(str.isdecimal, app_id.strip().split('-')))
    if not app_id_list:
        log.error(f'Invalid App ID')
        return False
    app_id = app_id_list[0]
    github_token = config.get("Github_Personal_Token", "")
    headers = {'Authorization': f'Bearer {github_token}'} if github_token else None
    # selected_repo, latest_date = await get_latest_repo_info(repos, app_id, headers)
    for selected_repo in repos:
        try:
            if (selected_repo):
                log.info(f'Selected Repo: {selected_repo}')
            if selected_repo == 'Steam tools .lua/.st script (Local file)':
                manifests = await get_data_local(app_id)
                await depotdownloadermod_add(app_id, manifests)
                log.info('Download files have been added.')
                # log.info(f'Manifest last updated: {latest_date}')
                log.info(f'Import successful: {app_id}')
                await client.aclose()
                return True
            elif selected_repo == 'PrintedWaste':
                if(await printedwaste_download(app_id)):
                    manifests = await get_data_local(app_id)
                    await depotdownloadermod_add(app_id, manifests)
                    log.info('Download files have been added.')
                    log.info(f'Import successful: {app_id}')
                    await client.aclose()
                    return True
            elif selected_repo == 'steambox.gdata.fun':
                if(await gdata_download(app_id)):
                    manifests = await get_data_local(app_id)
                    await depotdownloadermod_add(app_id, manifests)
                    log.info('Download files have been added.')
                    log.info(f'Import successful: {app_id}')
                    await client.aclose()
                    return True
            elif selected_repo == 'cysaw.top':
                if(await cysaw_download(app_id)):
                    manifests = await get_data_local(app_id)
                    await depotdownloadermod_add(app_id, manifests)
                    log.info('Download files have been added.')
                    log.info(f'Import successful: {app_id}')
                    await client.aclose()
                    return True
            elif selected_repo == 'luckygametools/steam-cfg': 
                await check_github_api_rate_limit(headers)
                url = f'https://api.github.com/repos/{selected_repo}/contents/steamdb2/{app_id}'
                r_json = await fetch_info(url, headers)
                if (r_json) and (isinstance(r_json, list)):
                    path = [item['path'] for item in r_json if item['name'] == '00000encrypt.dat'][0]
                    manifests = await get_data(app_id, path, selected_repo)
                    await depotdownloadermod_add(app_id, manifests)
                    log.info('Download files have been added.')
                    log.info(f'Import successful: {app_id}')
                    await client.aclose()
                    return True
            else:
                await check_github_api_rate_limit(headers)
                url = f'https://api.github.com/repos/{selected_repo}/branches/{app_id}'
                r_json = await fetch_info(url, headers)
                if (r_json) and ('commit' in r_json):
                    sha = r_json['commit']['sha']
                    url = r_json['commit']['commit']['tree']['url']
                    r2_json = await fetch_info(url, headers)
                    if (r2_json) and ('tree' in r2_json):
                        manifests = [item['path'] for item in r2_json['tree'] if item['path'].endswith('.manifest')]
                        for item in r2_json['tree']:
                            await get_manifest(app_id, sha, item['path'], selected_repo)
                        await depotdownloadermod_add(app_id, manifests)
                        log.info('Download files have been added.')
                        log.info(f'Import successful: {app_id}')
                        await client.aclose()
                        return True
        except Exception as e:
            log.error(f'Processing failed: {stack_error(e)}')
        log.error(f'Manifest not found: {app_id}')
    log.error(f'Manifest download or generation failed: {app_id}')
    await client.aclose()
    return False

def select_repo(repos):
    print(f"\n{Fore.YELLOW}{Back.BLACK}{Style.BRIGHT}Please select the repository to use:{Style.RESET_ALL}")
    print(f"{Fore.GREEN}1. All repositories{Style.RESET_ALL}")
    for i, repo in enumerate(repos, 2):
        print(f"{Fore.GREEN}{i}. {repo}{Style.RESET_ALL}")
    
    while True:
        try:
            choice = int(input(f"\n{Fore.CYAN}Please enter a number to select: {Style.RESET_ALL}"))
            if 1 <= choice <= len(repos) + 1:
                if choice == 1:
                    return repos
                else:
                    return [repos[choice-2]]
            else:
                print(f"{Fore.RED}Invalid selection, please try again{Style.RESET_ALL}")
        except ValueError:
            print(f"{Fore.RED}Please enter a valid number{Style.RESET_ALL}")

if __name__ == '__main__':
    init()
    try:
        repos = [
            'ikun0014/ManifestHub',
            'Auiowu/ManifestAutoUpdate',
            'tymolu233/ManifestAutoUpdate',
            'SteamAutoCracks/ManifestHub',
            'PrintedWaste',
            'steambox.gdata.fun',
            'cysaw.top',
#            'P-ToyStore/SteamManifestCache_Pro'
            'sean-who/ManifestAutoUpdate',
            'luckygametools/steam-cfg',
            'Steam tools .lua/.st script (Local file)'
        ]

        import sys
        if len(sys.argv) < 2:
            log.error("Please provide game AppID, for example: ./downloaddepot.sh 123456")
            sys.exit(1)

        app_id = sys.argv[1].strip()

        if asyncio.run(morrenus.morrenus_fetch(app_id)):
            manifests = asyncio.run(get_data_local(app_id))
            asyncio.run(depotdownloadermod_add(app_id, manifests))
            log.info(f"Import successful: {app_id} (from Morrenus)")
            sys.exit(0)  # exit after success

        selected_repos = repos
        asyncio.run(main(app_id, selected_repos))

    except KeyboardInterrupt:
        log.info("Program exited")
    except SystemExit:
        sys.exit()
