require 'mixlib/shellout'
require 'open3'
require 'pathname'
require 'securerandom'
require 'singleton'
require 'time'
require 'timeout'

module HabTesting

    module Utils

        # parse a ./results/last_build.env file, split lines on `=`
        # and return a hash containing all key/values
        def self.parse_last_build
            results = {}
            ## TODO: should we have a test root dir var?
            File.open("results/last_build.env", "r") do |f|
                f.each_line do |line|
                    chunks = line.split("=")
                    results[chunks[0].strip()] = chunks[1].strip()
                end
            end
            return results
        end
    end


    # The intent of the Platform class is to store any platform-independent
    # variables.
    class Platform
        include Singleton
        # path to the `hab` command
        attr_accessor :hab_bin;
        # TODO: unusued
        attr_accessor :hab_key_cache;
        # A unique testing organization
        attr_accessor :hab_org;
        # A unique testing origin
        attr_accessor :hab_origin;
        # The path to installed packages, (ex: /hab/pkgs on Linux)
        attr_accessor :hab_pkg_path;
        # TODO: path to the build command
        attr_accessor :hab_plan_build;
        # A unique testing ring name
        attr_accessor :hab_ring;
        # TODO: The root location of Habitat data, HAB_ROOT_PATH
        attr_accessor :hab_root_path;
        # A unique testing service group
        attr_accessor :hab_service_group;
        # TODO: the location of the studio root
        attr_accessor :hab_studio_root;
        # path to the `hab-sup` command
        attr_accessor :hab_sup_bin;
        # A unique testing user
        attr_accessor :hab_user;

        # command output logs are stored in this directory
        attr_accessor :log_dir;
        # The filename currently be used to log command output.
        # This file is stored in @log_dir
        attr_accessor :log_name;

        # if true, display command output
        attr_accessor :cmd_debug;
        # default timeout for child processes before failing
        attr_accessor :cmd_timeout_seconds;

        # if there is an example failure, don't cleanup the state on
        # disk if @cleanup is set to false
        attr_accessor :cleanup;

        # for any command that spawn child processes, we can use
        # all_pids to store pid info to see if we're leaving any
        # processes running after tests have completed
        attr_accessor :all_pids;

        # generate a unique name for use in testing
        def unique_name()
            SecureRandom.uuid
        end

        # return a list of HAB_ environment vars
        def env_vars()
            #TODO: share these between Inspec and Rspec?
            return %w(HAB_AUTH_TOKEN
                    HAB_CACHE_KEY_PATH
                    HAB_DEPOT_URL
                    HAB_ORG
                    HAB_ORIGIN
                    HAB_ORIGIN_KEYS
                    HAB_RING
                    HAB_RING_KEY
                    HAB_ROOT_PATH
                    HAB_STUDIOS_HOME
                    HAB_STUDIO_ROOT
                    HAB_USER)
        end

        # display testing parameters upon startup
        def banner()
            puts "-" * 80
            puts "Test params:"
            self.instance_variables.sort.each do |k|
                puts "#{k[1..-1]} = #{self.instance_variable_get(k)}"
            end
            puts "Logging command output to #{self.log_file_name()}"
            puts "-" * 80
        end


        # Common setup for tests, including setting a test origin
        # and key generation.
        # # TODO: move to base class
        def common_setup
            ENV['HAB_ORIGIN'] = @hab_origin
            cmd_expect("origin key generate #{@hab_origin}",
                       "Generated origin key pair #{@hab_origin}")
            cmd_expect("user key generate #{@hab_user}",
                       "Generated user key pair #{@hab_user}")
            cmd_expect("ring key generate #{@hab_ring}",
                       "Generated ring key pair #{@hab_ring}")
            # remove the studio if it already exists
            cmd("studio rm #{@hab_origin}")
            #puts "Creating new studio, this may take a few minutes"
            #ctx.cmd("studio -k #{ctx.hab_origin} new")
            #puts "Setup complete"
            puts "-" * 80
        end

        # Common teardown for tests
        def common_teardown
            if @cmd_debug
                @all_pids.each do |pidinfo|
                    puts "PID INFO: #{pidinfo}"
                end
            end

            if @cleanup
                puts "Clearing test environment"
                ENV.delete('HAB_ORIGIN')
                # TODO
                #`rm -rf ./results`
                # TODO: kill the studio only if all tests pass?
            else
                puts "WARNING: not cleaning up testing environment"
            end
        end

    end

    class LinuxPlatform < Platform
        def initialize
            @all_pids = []
            @hab_root_path = Dir.mktmpdir("hab_test_root")

            @hab_bin="/src/components/hab/target/debug/hab"
            #@hab_key_cache = "#{@hab_root_path}/hab/cache/keys"
            @hab_org = "org_#{unique_name()}"
            @hab_origin = "origin_#{unique_name()}"
            #@hab_plan_build = "/src/components/plan-build/bin/hab-plan-build.sh"
            @hab_pkg_path = "/hab/pkgs"
            @hab_ring = "ring_#{unique_name()}"
            # todo
            @hab_service_group = "service_group_#{unique_name()}"
            #@hab_studio_root = Dir.mktmpdir("hab_test_studio")
            @hab_sup_bin = "/src/components/sup/target/debug/hab-sup"
            @hab_user = "user_#{unique_name()}"

            @log_name = "hab_test-#{Time.now.utc.iso8601.gsub(/\:/, '-')}.log"
            @log_dir = "./logs"

            @cleanup = true
            @cmd_debug = false
            @cmd_timeout_seconds = 30
            banner()
        end


        # execute a `hab` subcommand and wait for the process to finish
        def cmd(cmdline, **cmd_options)
            debug = cmd_options[:debug] || @cmd_debug

            if debug then
                puts "X" * 80
                puts `env`
                puts "X" * 80
            end

            fullcmdline = "#{@hab_bin} #{cmdline} | tee -a #{log_file_name()} 2>&1"
            # record the command we'll be running in the log file
            `echo #{fullcmdline} >> #{log_file_name()}`
            puts "Running: #{fullcmdline}"
            pid = spawn(fullcmdline)
            @all_pids << [cmdline, pid]
            Process.wait pid
            return $?
        end

        def show_env()
            puts "X" * 80
            puts `env`
            puts "X" * 80
        end

        # execute a possibly long-running process and wait for a particular string
        # in it's output. If the output is found, kill the process and return
        # it's exit status. Otherwise, raise an exception so specs fail quickly.
        def cmd_expect(cmdline, desired_output, **cmd_options)
            puts "X" * 80 if @cmd_debug
            puts cmd_options if @cmd_debug
            debug = cmd_options[:debug] || @cmd_debug

            timeout = cmd_options[:timeout_seconds] || @cmd_timeout_seconds
            kill_when_found = cmd_options[:kill_when_found] || false
            show_env() if debug
            # passing output to | tee
            #fullcmdline = "#{@hab_bin} #{cmdline} | tee -a #{log_file_name()} 2>&1"
            fullcmdline = "#{@hab_bin} #{cmdline}"
            # record the command we'll be running in the log file
            `echo #{fullcmdline} >> #{log_file_name()}`
            puts "Running: #{fullcmdline}"

            output_log = open(log_file_name(), 'a')
            begin
                Open3.popen3(fullcmdline) do |stdin, stdout, stderr, wait_thread|
                    @all_pids << [fullcmdline, wait_thread.pid]
                    puts "Started child process id #{wait_thread[:pid]}" if debug
                    found = false
                    begin
                        Timeout::timeout(timeout) do
                            loop do
                                line = stdout.readline()
                                output_log.puts line
                                puts line if debug
                                if line.include?(desired_output) then
                                    if kill_when_found then
                                        puts "Sending a KILL to child process #{wait_thread.pid}" if debug
                                        Process.kill('KILL', wait_thread.pid)
                                        found = true
                                        break
                                    else
                                        puts "Output found but not sending signal to child" if debug
                                        # let the process finish, or timeout
                                        found = true
                                    end
                                end
                            end
                        end
                    rescue EOFError
                        if found then
                            puts "Found value as process finished" if debug
                            return wait_thread.value
                        else
                            raise "Process finished without finding desired output: #{desired_output}"
                        end
                    rescue Timeout::Error
                        # TODO: do timeouts always return failure?
                        puts "Timeout" if debug
                        Process.kill('KILL', wait_thread.pid)
                        puts "Child process killed" if debug
                        raise "Proces timeout waiting for desired output: #{desired_output}"
                    ensure
                        output_log.close()
                    end

                    if found == true then
                        puts "\tFound: #{desired_output}" if debug
                        return wait_thread.value
                    else
                        raise "Output not found: #{desired_output}"
                    end
                end
            end
        end

        # generate a unique log file name in the given log_dir
        def log_file_name()
            File.join(@log_dir, @log_name)
        end

        def mk_temp_dir()
            # TODO: remove temp directory before creating
            # TODO: keep track of temp files and remove them upon success?
            dir = Dir.mktmpdir("hab_test")
            puts "Temp dir = #{dir}"
            return dir
        end

    end

    class WindowsPlatform
        def initialize
            # :-(
            raise "Windows platform not implemented"
        end
    end

end # module HabTesting
