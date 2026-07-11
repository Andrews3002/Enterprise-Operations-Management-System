import base64
import os
import zipfile
from pathlib import Path
import oracledb
from dotenv import load_dotenv

load_dotenv()

def setup_wallet():
    # Cloud production environment that will use the wallet from environment variables
    encoded_wallet = os.getenv("BASE64_WALLET_ZIP")
    if encoded_wallet:
        wallet_dir = Path("/tmp/oracle_wallet")
        zip_path = Path("/tmp/wallet.zip")
        
        if not wallet_dir.exists():
            wallet_dir.mkdir(parents=True, exist_ok=True)
            with open(zip_path, "wb") as f:
                f.write(base64.b64decode(encoded_wallet))
            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                zip_ref.extractall(wallet_dir)
            zip_path.unlink()
        return str(wallet_dir)
        
    # Local development environment to fallback to that uses the direct path to my oracle database wallet (which will not be pushed to github)
    local_path = Path("./oracle_wallet")
    if local_path.exists():
        return str(local_path.resolve())
        
    raise ValueError("No Oracle wallet configuration found.")

WALLET_PATH = setup_wallet()

pool = oracledb.create_pool(
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    dsn=os.getenv("DB_DSN"),
    min=2,
    max=10,
    increment=1,
    config_dir=WALLET_PATH,
    wallet_location=WALLET_PATH
)

def get_connection():
    return pool.acquire()