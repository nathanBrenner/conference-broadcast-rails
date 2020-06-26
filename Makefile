.PHONY: install serve-setup serve

install:
	bundle install; \
	npm install;

serve-setup:
	bundle exec rails db:migrate

serve:
	bundle exec rails server -b 0.0.0.0
