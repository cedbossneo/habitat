require 'pathname'
require 'securerandom'
require 'time'

# TODO: should I rename this?
require_relative 'platform'

ctx = HabTesting::LinuxPlatform.new()

# to see all command output:
# ctx.cmd_debug = true

describe "Habitat CLI" do

    before(:all) do
        # ensure we are starting with an empty set of env vars
        # this _could_ be a test, but since we also set env vars in the
        # before() block, it makes a chicken/egg issue.
        #ctx.env_vars.each do |e|
        #    raise "#{e} is currently set, please clear the value and try again" \
        #        unless ENV[e].nil?
        #end
		ctx.common_setup()
    end

    after(:all) do
		ctx.common_teardown()
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
            ctx.cmd_expect("studio build fixtures/simple_service",
                                   "I love it when a plan.sh comes together",
                                   :debug => true,
                                   :timeout => 60)

			last_build = HabTesting::Utils::parse_last_build()
			#puts last_build
			expect(last_build["pkg_origin"]).to eq ctx.hab_origin
			expect(last_build["pkg_name"]).to eq "simple_service"
			expect(last_build["pkg_version"]).to eq "0.0.1"

			built_artifact = Pathname.new("results").join(last_build["pkg_artifact"])
			expect(File.exist?(built_artifact)).to be true
			ctx.cmd_expect("pkg install ./results/#{last_build["pkg_artifact"]}",
                "Install of #{ctx.hab_origin}/simple_service/0.0.1/#{last_build["pkg_release"]} complete with 1 packages installed")

    		installed_path = Pathname.new(ctx.hab_pkg_path).join(
								ctx.hab_origin,
								last_build["pkg_name"],
								last_build["pkg_version"],
								last_build["pkg_release"])

			expect(File.exist?(installed_path)).to be true

			ctx.cmd_expect("start #{ctx.hab_origin}/simple_service", "Shipping out to Boston")
        end
    end
end

