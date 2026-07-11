import oracledb
import os
from dotenv import load_dotenv

load_dotenv()

pool = oracledb.create_pool(
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    dsn=os.getenv("DB_DSN"),
    min=2,
    max=10,
    increment=1
)

def get_connection():
    return pool.acquire()