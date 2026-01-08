#!/bin/sh

set -e

echo "Waiting for postgres to connect and be ready..."
while ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER"; do
  sleep 1
done
echo "PostgreSQL is active and ready"

python manage.py makemigrations
python manage.py migrate
python manage.py collectstatic --noinput
echo "Postgresql migrations finished"

# Credential check, stop early if something is missing
if [ -z "$DJANGO_SUPERUSER_USERNAME" ] || [ -z "$DJANGO_SUPERUSER_EMAIL" ] || [ -z "$DJANGO_SUPERUSER_PASSWORD" ]; then
  echo "Superuser data is not provided/fully provided. Please re-check the .env file or runtime env variable"
  exit 1
fi

python manage.py createsuperuser --no-input --username "$DJANGO_SUPERUSER_USERNAME" --email "$DJANGO_SUPERUSER_EMAIL" || true

# Start server based on .env value or overridden at runtime
echo "Starting Gunicorn for production..."
gunicorn conduit.wsgi:application --bind 0.0.0.0:8000 --workers 3
