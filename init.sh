python manage.py migrate
python manage.py collectstatic --noinput --clear
python manage.py compilemessages

# Save service token to DB
python manage.py initial_token_setup

python manage.py create_superadmin --username ${DJANGO_SUPERUSER_USERNAME} --email ${DJANGO_SUPERUSER_EMAIL}

indicator_category_count=$(echo "from apps.decision_engine.models.indicator import IndicatorCategory; print(IndicatorCategory.objects.all().count())" | ./manage.py shell);
if (( $indicator_category_count < 1 )); then
  echo "Load indicator categories";
  python manage.py loaddata indicator_category 
else
  echo "Predefined indicator categories already exists";
fi

indicators_count=$(echo "from apps.decision_engine.models.indicator import Indicator; print(Indicator.objects.all().count())" | ./manage.py shell);
if (( $indicators_count < 1 )); then
  echo "Load indicators";
  python manage.py loaddata indicator 
else
  echo "Predefined indicators already exists";
fi

gunicorn --config gunicorn-cfg.py core.wsgi
