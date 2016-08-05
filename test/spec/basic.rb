require 'pathname'

# TODO: .rspec file doesn't seem to be honored, so we need
# to manually include the spec_helper here
require_relative 'spec_helper'

describe "Habitat CLI" do
    # TODO: maybe extract this into a module in the future
    before(:all) do
        platform.common_setup()
        #to see all command output:
        #platform.cmd_debug = true
    end

    after(:all) do
        platform.common_teardown()
    end

    after(:each) do |example|
        if example.exception
            puts "Detected failed examples, keeping environment"
            platform.cleanup = false
        end
    end

    # these are in RSpec instead of Inspec because we
    # keep some platform independent paths inside the platform.
    # Perhaps this could be shared in the future.
    context "core cli binaries" do
        it "hab command should be compiled" do
            expect(File.exist?(platform.hab_bin)).to be true
            expect(File.executable?(platform.hab_bin)).to be true
        end

        it "hab-sup command should be compiled" do
            expect(File.exist?(platform.hab_sup_bin)).to be true
            expect(File.executable?(platform.hab_sup_bin)).to be true
        end
    end

    context "package functionality" do
        # this is example is somewhat larger than desired, however, it exercises
        # build/install/start with a simple package, instead of downloading a
        # prebuilt one from the Depot
        it "should build, install and start a simple service without failure" do

            # TODO: this test WILL FAIL if a supervisor is already running.
            # The core/inspec Hab package is broken, so detecting open ports doesn't
            # seem to work unless the control is run remotely.

            # building a package can take quite awhile, let's bump the timeout to
            # 60 seconds to be sure we finish in time.
            result = platform.cmd_expect("studio build fixtures/simple_service",
                                         "I love it when a plan.sh comes together",
                                         :timeout_seconds => 60)
            expect(result.exited?).to be true
            expect(result.exitstatus).to eq 0

            last_build = HabTesting::Utils::parse_last_build()
            puts last_build if platform.cmd_debug
            expect(last_build["pkg_origin"]).to eq platform.hab_origin
            expect(last_build["pkg_name"]).to eq "simple_service"
            expect(last_build["pkg_version"]).to eq "0.0.1"

            built_artifact = Pathname.new("results").join(last_build["pkg_artifact"])
            expect(File.exist?(built_artifact)).to be true
            result = platform.cmd_expect("pkg install ./results/#{last_build["pkg_artifact"]}",
                                         "Install of #{platform.hab_origin}/simple_service/0.0.1/"\
                                         "#{last_build["pkg_release"]} complete with 1 packages installed",
                                         :kill_when_found => false)
            expect(result.exited?).to be true
            expect(result.exitstatus).to eq 0

            installed_path = Pathname.new(platform.hab_pkg_path).join(
                platform.hab_origin,
                last_build["pkg_name"],
                last_build["pkg_version"],
                last_build["pkg_release"])
            expect(File.exist?(installed_path)).to be true

            # this should start relatively quickly, so we'll use the default timeout
            # This is a long running process, so kill it when we've found the output
            # that we're looking for.
            result = platform.cmd_expect("start #{platform.hab_origin}/simple_service",
                                         "Shipping out to Boston",
                                         :kill_when_found => true)
            # don't check the process status here, we killed it!
        end
    end

end

