# frozen_string_literal: true

module SimpleLogstashCookbook
  class LogstashServiceUpstart < LogstashServiceBase
    resource_name :logstash_service_upstart

    provides :logstash_service, platform: 'debian' do |node| # ~FC005
      node['platform_version'].to_f <= 7.0
    end

    provides :logstash_service, platform: 'ubuntu' do |node|
      node['platform_version'].to_f <= 14.04
    end

    provides :logstash_service, platform: %w[redhat centos scientific oracle] do |node|
      node['platform_version'].to_f <= 6.0
    end

    provides :logstash_service, platform: 'fedora'
    provides :logstash_service_systemd, os: 'linux'

    action_class do
      def whyrun_supported?
        true
      end

      def env_file
        find_resource(:file, "/etc/default/#{new_resource.instance_name}") do
          content new_resource.env.map { |k, v| "#{k}=#{v}" }.join("\n")
          owner 'root'
          group 'root'
          mode '0644'
        end
      end

      # DRY: generate service resource for the further reuse
      def service_resource
        find_resource(:file, "/etc/init/#{new_resource.instance_name}") do
          content(
            """
            description     \"Logstash service\"
            start on filesystem or runlevel [2345]
            stop on runlevel [!2345]

            respawn
            umask 022
            chroot /
            chdir /
            #limit msgqueue <softlimit> <hardlimit>
            #limit nice <softlimit> <hardlimit>
            #limit rtprio <softlimit> <hardlimit>
            #limit sigpending <softlimit> <hardlimit>
            setuid #{new_resource.user}
            setgid #{new_resource.group}


            script
              # When loading default and sysconfig files, we use `set -a` to make
              # all variables automatically into environment variables.
              set -a
              [ -r /etc/default/#{new_resource.instance_name} ] && . /etc/default/#{new_resource.instance_name}
              [ -r /etc/sysconfig/#{new_resource.instance_name} ] && . /etc/sysconfig/#{new_resource.instance_name}
              set +a
              exec #{new_resource.daemon_path} #{new_resource.logstash_args}
            end script
            """)

          action :nothing
        end
      end
    end

    action :start do
      env_file.notifies :restart, service_resource, :delayed
      service_resource.action += [:create]
    end

    action :stop do
      service_resource.action += [:delete]
    end

    action :restart do
      service_resource.action += [:create]
    end
  end
end
