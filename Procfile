web: bundle exec puma -t 5:5 -p ${PORT:-3000} -e ${RACK_ENV:-development}

dev_web: bundle exec rackup config.ru -p $PORT