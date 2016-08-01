require 'open3'
require 'pathname'
require 'securerandom'
require 'time'

module HabTesting

	module Utils
		def self.parse_last_build
			results = {}
			## TODO: we should have a test root dir var
			File.open("results/last_build.env", "r") do |f|
				f.each_line do |line|
					chunks = line.split("=")
					results[chunks[0].strip()] = chunks[1].strip()
				end
			end
			return results
		end
	end

	class Platform
		attr_accessor :hab_bin;
		attr_accessor :hab_key_cache;
		attr_accessor :hab_org;
		attr_accessor :hab_origin;
		attr_accessor :hab_pkg_path;
		attr_accessor :hab_plan_build;
		attr_accessor :hab_ring;
		attr_accessor :hab_root_path;
		attr_accessor :hab_service_group;
		attr_accessor :hab_studio_root;
		attr_accessor :hab_sup_bin;
		attr_accessor :hab_user;

		attr_accessor :log_dir;
		attr_accessor :log_name;

		# if there is an example failure, don't cleanup the state on
		# disk if @cleanup is set to false
		attr_accessor :cleanup;
		def unique_name()
			SecureRandom.uuid
		end

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
	end

	class LinuxPlatform < Platform
		def initialize
			@hab_root_path = Dir.mktmpdir("hab_test_root")

			@hab_bin="/src/components/hab/target/debug/hab"
			@hab_key_cache = "#{@hab_root_path}/hab/cache/keys"
			@hab_org = "org_#{unique_name()}"
			@hab_origin = "origin_#{unique_name()}"
			@hab_plan_build = "/src/components/plan-build/bin/hab-plan-build.sh"
			@hab_pkg_path = "/hab/pkgs"
			@hab_ring = "ring_#{unique_name()}"
			# todo
			@hab_service_group = "service_group_#{unique_name()}"
			@hab_studio_root = Dir.mktmpdir("hab_test_studio")
			@hab_sup_bin = "/src/components/sup/target/debug/hab-sup"
			@hab_user = "user_#{unique_name()}"

			@log_name = "hab_test-#{Time.now.utc.iso8601.gsub(/\:/, '-')}.log"
			@log_dir = "./logs"

			@cleanup = true
		end

		def cmd(cmdline, debug=false)
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
			Process.wait pid
			return $?
		end

		def wait_for_cmd_output(cmdline, desired_output, debug = false, timeout = 10)
			if debug then
				puts "X" * 80
				puts `env`
				puts "X" * 80
			end

			fullcmdline = "#{@hab_bin} #{cmdline} | tee -a #{log_file_name()} 2>&1"
			# record the command we'll be running in the log file
			`echo #{fullcmdline} >> #{log_file_name()}`
			puts "Running: #{fullcmdline}"

			begin
				Open3.popen3(fullcmdline) do |stdin, stdout, stderr, wait_thread|
					puts "Started child process"
					found = false
					begin
						Timeout::timeout(timeout) do
							loop do
								line = stdout.readline()
								puts line if debug
								if line.include?(desired_output) then
									Process.kill('TERM', wait_thread.pid)
									found = true
									break
								end
							end
						end
					rescue EOFError
						puts "Process finished without finding desired output"
						return false
					rescue Timeout::Error
						puts "Timeout"
						Process.kill('TERM', wait_thread.pid)
						puts "Child process killed"
						return false
					end

					if found == true then
						puts "Found: #{desired_output}"
						return true
					else
						return false
					end
				end
			end
		end

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
			raise "Windows platform not implemented"
		end
	end

end # module HabTesting
