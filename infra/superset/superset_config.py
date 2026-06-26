import os

SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]
SQLALCHEMY_DATABASE_URI = os.environ["DATABASE_URL"]

# Cache + resultados con Redis
REDIS_HOST = os.environ.get("REDIS_HOST", "superset-redis")
CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": 6379,
    "CACHE_KEY_PREFIX": "superset_",
}
DATA_CACHE_CONFIG = CACHE_CONFIG

FEATURE_FLAGS = {
    "DASHBOARD_RBAC": True,
    "EMBEDDED_SUPERSET": True,
    "ALERT_REPORTS": True,
}
SQLLAB_TIMEOUT = 300
WEBDRIVER_BASEURL = "http://superset:8088/"
