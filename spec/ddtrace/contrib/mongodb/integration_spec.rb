# typed: ignore
require 'ddtrace/contrib/support/spec_helper'

require 'ddtrace/contrib/action_pack/integration'

RSpec.describe Datadog::Contrib::MongoDB::Integration do
  extend ConfigurationHelpers

  let(:integration) { described_class.new(:mongodb) }

  describe '.version' do
    subject(:version) { described_class.version }

    context 'when the "mongo" gem is loaded' do
      include_context 'loaded gems', mongo: described_class::MINIMUM_VERSION
      it { is_expected.to be_a_kind_of(Gem::Version) }
    end

    context 'when "mongo" gem is not loaded' do
      include_context 'loaded gems', mongo: nil
      it { is_expected.to be nil }
    end
  end

  describe '.loaded?' do
    subject(:loaded?) { described_class.loaded? }

    context 'when Mongo::Monitoring::Global is defined' do
      before { stub_const('Mongo::Monitoring::Global', Class.new) }

      it { is_expected.to be true }
    end

    context 'when Mongo::Monitoring::Global is not defined' do
      before { hide_const('Mongo::Monitoring::Global') }

      it { is_expected.to be false }
    end
  end

  describe '.compatible?' do
    subject(:compatible?) { described_class.compatible? }

    context 'when "mongo" gem is loaded with a version' do
      context 'that is less than the minimum' do
        include_context 'loaded gems', mongo: decrement_gem_version(described_class::MINIMUM_VERSION)
        it { is_expected.to be false }
      end

      context 'that meets the minimum version' do
        include_context 'loaded gems', mongo: described_class::MINIMUM_VERSION
        it { is_expected.to be true }
      end
    end

    context 'when gem is not loaded' do
      include_context 'loaded gems', mongo: nil
      it { is_expected.to be false }
    end
  end

  describe '#auto_instrument?' do
    subject(:auto_instrument?) { integration.auto_instrument? }

    it { is_expected.to be(true) }
  end

  describe '#default_configuration' do
    subject(:default_configuration) { integration.default_configuration }

    it { is_expected.to be_a_kind_of(Datadog::Contrib::MongoDB::Configuration::Settings) }
  end

  describe '#patcher' do
    subject(:patcher) { integration.patcher }

    it { is_expected.to be Datadog::Contrib::MongoDB::Patcher }
  end
end
