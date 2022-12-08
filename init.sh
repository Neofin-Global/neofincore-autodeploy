python manage.py migrate
python manage.py collectstatic --noinput --clear
python manage.py compilemessages

# Save service token to DB
python manage.py initial_token_setup

python manage.py create_superadmin --username ${DJANGO_SUPERUSER_USERNAME} --email ${DJANGO_SUPERUSER_EMAIL}

python3 manage.py loaddata indicator_category
python3 manage.py load_decision_engine_indicators

gunicorn --config gunicorn-cfg.py core.wsgi
