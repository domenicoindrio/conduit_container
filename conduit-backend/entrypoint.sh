#!/bin/sh

set -e

echo "Waiting for postgres to connect and be ready..."
while ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$POSTGRES_USER"; do
  sleep 1
done
echo "PostgreSQL is active and ready"


python manage.py migrate
python manage.py collectstatic --noinput
echo "Postgresql migrations finished"

# Handle Superuser Creation
echo "Checking superuser requirements..."
if [ -z "$DJANGO_SUPERUSER_USERNAME" ] || [ -z "$DJANGO_SUPERUSER_EMAIL" ] || [ -z "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo "IMPORTANT: One or more DJANGO_SUPERUSER variables are missing. Skipping auto-creation."
else
    echo "Attempting to create superuser..."
    python manage.py createsuperuser --no-input --username "$DJANGO_SUPERUSER_USERNAME" --email "$DJANGO_SUPERUSER_EMAIL"
fi

# Start server
echo "Starting Gunicorn for production..."
gunicorn conduit.wsgi:application --bind 0.0.0.0:8000 --access-logfile - --error-logfile - --workers 3 

