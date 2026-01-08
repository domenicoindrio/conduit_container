import environ
from .settings import *

env = environ.Env()


SECRET_KEY = env("SECRET_KEY")
DEBUG = False

CORS_ORIGIN_WHITELIST = env.list("CORS_ORIGIN_WHITELIST", default=[])
CORS_ALLOW_CREDENTIALS = True


ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=[])

DJANGO_HOST = env("DJANGO_HOST")
if DJANGO_HOST:
    ALLOWED_HOSTS.append(DJANGO_HOST)


DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': env('POSTGRES_DB'),
        'USER': env('POSTGRES_USER'),
        'PASSWORD': env('POSTGRES_PASSWORD'),
        'HOST': env('DB_HOST'),
        'PORT': env('DB_PORT'),
    }
}
