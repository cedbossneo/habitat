INSPEC_PACKAGE=metadave/inspec
RUBY_PACKAGE=core/ruby
BUNDLER_PACKAGE=core/bundler

INSPEC=hab pkg exec ${INSPEC_PACKAGE} inspec

SPEC_OPTS=--color --require spec_helper --format documentation

all: setup
	pkill hab-sup | /bin/true # TODO
	mkdir -p ./logs
	${INSPEC} exec ./hab_inspec/controls/clean_env.rb
	${INSPEC} exec ./spec/basic.rb
	${INSPEC} exec ./spec/plan_build.rb

# TODO
setup:
	export INSPEC_DATA_PATH="/hab/svc/inspec/data"
	#export GEM_HOME="${RAILS_SAMPLE_DATA}/dist/vendor/bundle/ruby/2.3.0"
	export GEM_HOME="${INSPEC_DATA_PATH}/dist/vendor/bundle/ruby/2.3.0"
	export GEM_PATH="$(hab pkg path core/ruby)/lib/ruby/gems/2.3.0:$(hab pkg path core/bundler):$GEM_HOME"
	export LD_LIBRARY_PATH="$(hab pkg path core/gcc-libs)/lib"
	export PATH="$PATH:${INSPEC_DATA_PATH}/dist/bin"
	hab pkg install ${BUNDLER_PACKAGE}
	hab pkg install ${INSPEC_PACKAGE}
	hab pkg binlink ${INSPEC_PACKAGE} coderay     
	hab pkg binlink ${INSPEC_PACKAGE} htmldiff    
	hab pkg binlink ${INSPEC_PACKAGE} inspec      
	hab pkg binlink ${INSPEC_PACKAGE} pry         
	hab pkg binlink ${INSPEC_PACKAGE} rwinrm      
	hab pkg binlink ${INSPEC_PACKAGE} thor
	hab pkg binlink ${INSPEC_PACKAGE} erubis      
	hab pkg binlink ${INSPEC_PACKAGE} httpclient  
	hab pkg binlink ${INSPEC_PACKAGE} ldiff       
	hab pkg binlink ${INSPEC_PACKAGE} rspec       
	hab pkg binlink ${INSPEC_PACKAGE} rwinrmcp
	hab pkg binlink ${RUBY_PACKAGE} erb
	hab pkg binlink ${RUBY_PACKAGE} irb
	hab pkg binlink ${RUBY_PACKAGE} rdoc
	hab pkg binlink ${RUBY_PACKAGE} ruby
	hab pkg binlink ${RUBY_PACKAGE} gem
	hab pkg binlink ${RUBY_PACKAGE} rake
	hab pkg binlink ${RUBY_PACKAGE} ri
	hab pkg binlink ${RUBY_PACKAGE} update_rubygems
	hab pkg binlink ${BUNDLER_PACKAGE} bundler


#dirs = $(shell ls)
#clean:
#    @$(foreach dir,$(dirs),echo $(dir);)

specs:
	mkdir -p ./logs
	${INSPEC} exec ./spec/basic.rb
	${INSPEC} exec ./spec/plan_build.rb

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
