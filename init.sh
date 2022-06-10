python manage.py migrate
python manage.py collectstatic --noinput
python manage.py compilemessages
python manage.py createsuperuser --noinput --email ${DJANGO_SUPERUSER_EMAIL}
gunicorn --config gunicorn-cfg.py core.wsgi
