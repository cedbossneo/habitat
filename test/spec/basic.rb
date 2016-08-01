require 'pathname'
require 'securerandom'
require 'time'

# TODO: should I rename this?
require_relative 'platform'

ctx = HabTesting::LinuxPlatform.new()

puts "-" * 80
puts "Test params:"
ctx.instance_variables.sort.each do |k|
	puts "#{k[1..-1]} = #{ctx.instance_variable_get(k)}"
end
puts "Logging command output to #{ctx.log_file_name()}"
puts "-" * 80

describe "Habitat CLI" do

    before(:all) do
        # ensure we are starting with an empty set of env vars
        # this _could_ be a test, but since we also set env vars in the
        # before() block, it makes a chicken/egg issue.
        #ctx.env_vars.each do |e|
        #    raise "#{e} is currently set, please clear the value and try again" \
        #        unless ENV[e].nil?
        #end

        ENV['HAB_ORIGIN'] = ctx.hab_origin
        #ENV['HAB_CACHE_KEY_PATH'] = ctx.hab_key_cache
        #ENV['HAB_ROOT_PATH'] = ctx.hab_root_path

        ctx.cmd("origin key generate #{ctx.hab_origin}")
        ctx.cmd("user key generate #{ctx.hab_user}")
        ctx.cmd("ring key generate #{ctx.hab_ring}")
        # remove the studio if it already exists
        ctx.cmd("studio rm #{ctx.hab_origin}")
        #puts "Creating new studio, this may take a few minutes"
        #ctx.cmd("studio -k #{ctx.hab_origin} new")
        #puts "Setup complete"
        puts "-" * 80
    end

    after(:all) do
		if ctx.cleanup
			puts "Clearing test environment"
			#ENV.delete('HAB_CACHE_KEY_PATH')
			ENV.delete('HAB_ORIGIN')
			# TODO
			#`rm -rf ./results`
			#ENV.delete('HAB_ROOT_PATH')
			#FileUtils.remove_entry(Hab.hab_key_cache)
			# TODO: kill the studio only if all tests pass?
			#ctx.cmd("studio rm")
		else
			puts "WARNING: not cleaning up testing environment"
		end
    end

	after(:each) do |example|
		if example.exception
			puts "Detected failed examples, keeping environment"
			ctx.cleanup = false
		end
	end

    # these are in RSpec instead of Inspec because we
    # keep some platform independent paths inside the ctx.
    # Perhaps this could be shared in the future.
    context "core cli binaries" do
        it "hab command should be compiled" do
            expect(File.exist?(ctx.hab_bin)).to be true
            expect(File.executable?(ctx.hab_bin)).to be true
        end

        it "hab-sup command should be compiled" do
            expect(File.exist?(ctx.hab_sup_bin)).to be true
            expect(File.executable?(ctx.hab_sup_bin)).to be true
        end
    end

    context "studio build of a package" do
		# this is example is somewhat larger than desired, however, it exercises
		# build/install/start with a simple package, instead of downloading a
		# prebuilt one from the Depot
        it "should build, install and start a simple service without failure" do
            # TODO: error handling with paths
            result = ctx.cmd("studio build fixtures/simple_service")
            expect(result).not_to be_nil
            expect(result.success?).to be true

			last_build = HabTesting::Utils::parse_last_build()
			#puts last_build
			expect(last_build["pkg_origin"]).to eq ctx.hab_origin
			expect(last_build["pkg_name"]).to eq "simple_service"
			expect(last_build["pkg_version"]).to eq "0.0.1"

			built_artifact = Pathname.new("results").join(last_build["pkg_artifact"])
			expect(File.exist?(built_artifact)).to be true
			result = ctx.cmd("pkg install ./results/#{last_build["pkg_artifact"]}")
    		installed_path = Pathname.new(ctx.hab_pkg_path).join(
								ctx.hab_origin,
								last_build["pkg_name"],
								last_build["pkg_version"],
								last_build["pkg_release"])

			expect(File.exist?(installed_path)).to be true

			result = ctx.wait_for_cmd_output("start #{ctx.hab_origin}/simple_service", "Shipping out to Boston")
			expect(result).to be true
        end
    end
end

