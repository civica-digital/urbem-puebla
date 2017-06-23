.PHONY: all deploy \
	build push set-compose set-env pull setup-db \
	shell logs \
	backup-db

#################
#    GENERAL    #
#################
all: docker-compose.override.yml .envrc tmp log config/database.yml
	docker-compose run --rm web bundle install
	docker-compose run --rm web rake db:create db:setup
	docker-compose up -d

################
#    DEPLOY    #
################
HOST ?= urbem-puebla
HOST_DIR ?= /www/sitios/EvaluatuTramite
REMOTE_COMPOSE = docker-compose -f $(HOST_DIR)/docker-compose.yml

deploy: build push set-compose set-env pull up setup-db

build: docker-compose.production.yml
	docker-compose -f docker-compose.production.yml build web

push: docker-compose.production.yml
	docker-compose -f docker-compose.production.yml push web

set-compose: docker-compose.production.yml
	scp docker-compose.production.yml $(HOST):$(HOST_DIR)/docker-compose.yml

set-env: .env
	scp .env $(HOST):~/.env
	scp .env $(HOST):$(HOST_DIR)/.env

pull:
	ssh $(HOST) $(REMOTE_COMPOSE) pull web

up:
	ssh $(HOST) $(REMOTE_COMPOSE) up -d

setup-db:
	ssh $(HOST) $(REMOTE_COMPOSE) run --rm web rake db:setup

#############
#    SSH    #
#############
SERVICE ?= web

shell:
	ssh -t $(HOST) $(REMOTE_COMPOSE) exec --rm $(SERVICE) bash

logs:
	ssh -t $(HOST) $(REMOTE_COMPOSE) logs --follow $(SERVICE)

##################
#    DATABASE    #	PENDING
##################
#DATE = $(shell date +%d-%m-%Y"_"%H_%M_%S)
#backup-db: dump-db upload-dump-to-s3
#
#dump-db:
#	ssh -t $(HOST) $(REMOTE_COMPOSE) exec db \
#		pg_dumpall -c -U postgres > dump_$(DATE).sql
#	
#upload-dump-to-s3:
#	scp
#	ssh -t $(HOST) cat dump_$(DATE).sql \
#		| docker exec -i your-db-container psql -U postgres

###############
#    FILES    #
###############
docker-compose.override.yml:
	cp docker-compose.override.yml.example docker-compose.override.yml
ifeq ($(shell uname), Linux)
	sed -i "s/{{user}}/$(shell id -u):$(shell id -g)/g" docker-compose.override.yml
else
	sed -i "/user/d" docker-compose.override.yml
endif

config/database.yml:
	cp config/database.yml.example config/database.yml
	sed -i '2 a\  host: db' config/database.yml
	sed -i '3 a\  username: postgres' config/database.yml

tmp:
	mkdir tmp

log:
	mkdir log

.envrc:
	echo 'PATH_add docker/shims' > .envrc
