require 'net/ssh'
require 'net/scp'
require 'fileutils'

namespace "explorify" do
  @facter_dir = "/Users/whopper/Documents/Coding/facter"
  @log_dir    = "/Users/whopper/Documents/Coding/explorify_logs"
  @local_vm_facter_path = "/home/whopper/facter"
  @local_vm_facter_feature_path = "/home/whopper/zfacter"

  desc "Exploratory testing on all Unix platforms"
  task :all, :branch do |t, args|
    system("rm -rf #{@log_dir}/*")

    get_vcloud_vm_list.each do |vm|
      Rake::Task["explorify:vcloud"].invoke(args[:branch])
    end

    get_local_vm_list.each do |vm|
      Rake::Task["explorify:local"].invoke(args[:branch])
    end
  end

  desc "Exploratory testing on Vcloud VMs"
  task :vcloud, :branch do |t, args|
    get_vcloud_vm_list.each do |vm|
      puts "preparing #{vm} with #{args[:branch]}"
    end
  end

  desc "Exploratory testing on local VMs"
  task :local, :branch do |t, args|
    system("rm -rf #{@log_dir}/*")
    get_local_vm_list.each do |vm|
      puts "preparing #{vm} with master and #{args[:branch]}"
      if vm == "openbsd"
        @rubycmd = "/usr/local/bin/ruby19"
      else
        @rubycmd = "ruby"
      end

      Net::SSH.start("#{vm}", "whopper", :password => "puppet") do |ssh|
         ssh.exec!("rm -rf #{@local_vm_facter_path}")
         ssh.close
      end

      Net::SCP.start("#{vm}", "whopper", :password => "puppet") do |scp|
        system("cd #{@facter_dir} && git co master")
        scp.upload!("#{@facter_dir}", "/home/whopper/facter", :recursive => true)
      end

      Net::SCP.start("#{vm}", "whopper", :password => "puppet") do |scp|
        system("cd #{@facter_dir} && git co #{args[:branch]}")
        scp.upload!("#{@facter_dir}", "/home/whopper/zfacter", :recursive => true)
      end

      Net::SSH.start("#{vm}", "whopper", :password => "puppet") do |ssh|
        system("mkdir -p #{@log_dir}/#{vm}")
        m = ssh.exec!("#{@rubycmd} -I #{@local_vm_facter_path}/lib #{@local_vm_facter_path}/bin/facter")
        File.open("#{@log_dir}/#{vm}/master", 'w') { |file| file.write(m) }
        b = ssh.exec!("#{@rubycmd} -I #{@local_vm_facter_feature_path}/lib #{@local_vm_facter_feature_path}/bin/facter")
        File.open("#{@log_dir}/#{vm}/feature", 'w') { |file| file.write(b) }
        ssh.close
      end
    end
  end

  desc "Send feature branch to Win helper host"
  task :win, :branch do |t, args|
    puts "Sending master and #{args[:branch]} to #{get_windows_helper_host}"
    # execute scp -r facter whopper@rita:~whopper
  end
end

namespace "teardown" do
  desc "Teardown exploratory testing VMs"
  task :destroy do
    puts "Tearing down VM!"
  end

  desc "Delete Facter directory on Win helper host"
  task :clear_win_helper do
    puts "Deleting"
  end
end

def get_vcloud_vm_list
  [ 'amazon-201403-x86_64',
    'centos-5-x86_64',
    'centos-6-x86_64',
    'centos-7-x86_64',
    'debian-6-x86_64',
    'debian-7-x86_64',
    'fedora-19-x86_64',
    'fedora-20-x86_64',
    'opensuse-11-x86_64',
    'oracle-6-x86_64',
    'osx-109-x86_64',
    'redhat-6-x86_64',
    'redhat-7-x86_64',
    'scientific-6-x86_64',
    'sles-11-x86_64',
    'sles-12-x86_64',
    'solaris-11-x86_64',
    'ubuntu-1004-x86_64',
    'ubuntu-1204-x86_64',
    'ubuntu-1404-x86_64',
  ]
end

def get_local_vm_list
  #[ 'openbsd',
  #  'kfreebsd',
  #  'freebsd' ]
  [ '192.168.0.24',
    '192.168.0.25',
    '192.168.0.23' ]
end

def get_windows_vm_list
  [ 'win-2003-x86_64',
    'win-2008-x86_64' ]
end

def get_windows_helper_host
  'rita.cat.pdx.edu'
end
