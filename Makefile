#!/usr/bin/make -f

start:
	docker-compose \
		up \
		--build \
		--remove-orphans