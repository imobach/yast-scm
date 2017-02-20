#!/usr/bin/env rspec

require_relative "../../spec_helper"
require "cm/configurators/salt"

describe Yast::CM::Configurators::Salt do
  subject(:configurator) { Yast::CM::Configurators::Salt.new(config) }

  let(:master) { "myserver" }
  let(:config_url) { "https://yast.example.net/myconfig.tgz" }
  let(:keys_url) { "https://yast.example.net/keys" }
  let(:tmpdir) { Pathname.new("/tmp") }

  let(:config) do
    { master: master, config_url: config_url, keys_url: keys_url }
  end

  describe "#packages" do
    context "when running in client mode" do
      it "returns a list containing 'salt' and 'salt-minion' package" do
        expect(configurator.packages).to eq("install" => ["salt", "salt-minion"])
      end
    end

    context "when running in masterless mode" do
      let(:master) { nil }

      it "returns a list containing only 'salt' package" do
        expect(configurator.packages).to eq("install" => ["salt"])
      end
    end
  end

  describe "#prepare" do
    before do
      allow(configurator).to receive(:config_tmpdir).and_return(tmpdir)
    end

    context "when running in client mode" do
      let(:minion_config) { double("minion", load: true, save: true) }
      let(:key_finder) { double("key_finder", fetch_to: true) }

      before do
        allow(Yast::CM::CFA::Minion).to receive(:new).and_return(minion_config)
        allow(minion_config).to receive(:master=)
        allow(Yast::CM::KeyFinder).to receive(:new).and_return(key_finder)
      end

      it "updates the configuration file" do
        expect(minion_config).to receive(:master=).with(master)
        configurator.prepare
      end

      it "retrieves authentication keys" do
        expect(key_finder).to receive(:fetch_to)
          .with(Pathname("/etc/salt/pki/minion/minion.pem"),
            Pathname("/etc/salt/pki/minion/minion.pub"))
        configurator.prepare
      end
    end

    context "when neither master server nor url is specified through the configuration" do
      let(:master) { nil }
      let(:config_url) { nil }

      it "does not update the configuration file" do
        expect(Yast::CM::CFA::Minion).to_not receive(:new)
        configurator.prepare
      end
    end
  end
end
