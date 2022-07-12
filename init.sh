python manage.py migrate
python manage.py collectstatic --noinput
python manage.py compilemessages

superusers_count=$(echo "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.filter(email='${DJANGO_SUPERUSER_EMAIL}').count())" | ./manage.py shell);
if (( $superusers_count < 1 )); then
  echo "Create superuser ${DJANGO_SUPERUSER_EMAIL}";
  python manage.py createsuperuser --noinput --email ${DJANGO_SUPERUSER_EMAIL}
else
  echo "Superuser ${DJANGO_SUPERUSER_EMAIL} exists";
fi

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
