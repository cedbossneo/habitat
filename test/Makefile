INSPEC=hab pkg exec core/inspec inspec

all:
	pkill hab-sup | /bin/true # TODO
	mkdir -p ./logs
	hab pkg install core/inspec
	${INSPEC} exec ./hab_inspec/controls/clean_env.rb
	${INSPEC} exec ./spec/basic.rb


specs:
	mkdir -p ./logs
	${INSPEC} exec ./spec/basic.rb

unset_all:
	unset HAB_AUTH_TOKEN
	unset HAB_CACHE_KEY_PATH
	unset HAB_DEPOT_URL
	unset HAB_ORG
	unset HAB_ORIGIN
	unset HAB_ORIGIN_KEYS
	unset HAB_RING
	unset HAB_RING_KEY
	unset HAB_ROOT_PATH
	unset HAB_STUDIOS_HOME
	unset HAB_STUDIO_ROOT
	unset HAB_USER
