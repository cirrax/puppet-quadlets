# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'quadlets_secret' do
  context 'with a selection of secrets for theuser' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        include quadlets

        # systemd-logind is masked on almalinux, enable it because it is needed
        # for user containers
        service{'systemd-logind.service':
          ensure => true,
          enable => true,
        }
        if $facts['os']['family'] != 'Debian' {
          exec{'setcap_newgidmap':
            command => '/usr/sbin/setcap cap_setgid=ep /usr/bin/newgidmap',
            unless  => '/usr/sbin/getcap /usr/bin/newgidmap | grep -q cap_setgid=ep',
            before  => User['theuser'],
          }
          exec{'setcap_newuidmap':
            command => '/usr/sbin/setcap cap_setuid=ep /usr/bin/newuidmap',
            unless  => '/usr/sbin/getcap /usr/bin/newuidmap | grep -q cap_setuid=ep',
            before  => User['theuser'],
          }
        }
        # end hacks to make it work on rootless in rootless container

        quadlets::user{ 'theuser':
          subuid => [20000,5000],
          subgid => [20000,5000],
        }

        quadlets_secret{'theuser:asecret':
          secret => 'whoknows',
        }

        quadlets_secret{'theuser:anothersecret':
          secret => 'justguess',
          labels => {
            label1 => 'one',
            label2 => 'two',
          },
        }

        quadlets_secret{'theuser:withpath':
          secret   => 'Idonottellyou;)',
          doptions => {
            path => '/tmp/withpathsecret',
          },
        }
        PUPPET
      end
    end

    it 'theuser:asecret exists' do
      result = command("su theuser -c 'podman secret ls --filter Name=asecret -n --format \"{{.Name}}\"'")
      expect(result.stdout.strip).to eq('asecret'.encode('US-ASCII'))
    end

    it 'theuser:anothersecret has labels' do
      result = command("su theuser -c 'podman secret inspect anothersecret --format \"{{.Spec.Labels}}\"'")
      expect(result.stdout.strip).to eq('map[label1:one label2:two]'.encode('US-ASCII'))
    end

    describe 'directories for secret with path set' do
      describe file('/tmp/withpathsecret') do
        it { is_expected.to be_directory }
        it { is_expected.to be_owned_by 'theuser' }
        it { is_expected.to be_grouped_into 'theuser' }
      end
    end

    describe 'file for secret with path set' do
      describe file('/tmp/withpathsecret/secretsdata.json') do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'theuser' }
        it { is_expected.to be_grouped_into 'theuser' }
      end
    end
  end
end
