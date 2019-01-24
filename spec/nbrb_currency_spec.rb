require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'yaml'

describe 'NbrbCurrency' do
  def test_rate(currency, amount = default_amount)
    exchange_rates['currencies'][currency].to_f * 100 * amount
  end

  let(:bank) { NbrbCurrency.new }
  let(:cache_path) { File.expand_path(File.dirname(__FILE__) + '/exchange_rates.xml') }
  let(:yml_cache_path) { File.expand_path(File.dirname(__FILE__) + '/exchange_rates.yml') }
  let(:tmp_cache_path) { File.expand_path(File.dirname(__FILE__) + '/tmp/exchange_rates.xml') }
  let(:exchange_rates) { YAML.load_file(yml_cache_path) }
  let(:default_amount) { 100 }

  after(:each) do
    File.delete(tmp_cache_path) if File.exist?(tmp_cache_path)
  end

  it 'should save the xml file from nbrb given a file path' do
    bank.save_rates(tmp_cache_path)
    expect(File.exist?(tmp_cache_path)).to be true
  end

  it 'should raise an error if an invalid path is given to save_rates' do
    expect { bank.save_rates(nil) }.to raise_error(InvalidCache)
  end

  it 'should update itself with exchange rates from nbrb website' do
    allow(OpenURI::OpenRead).to receive(:open).with(NbrbCurrency::NBRB_RATES_URL) { cache_path }
    bank.update_rates
    NbrbCurrency::CURRENCIES.each do |currency|
      expect(bank.get_rate(currency, 'BYN')).to be > 0
      expect(bank.get_rate(currency, 'BYR')).to be > 0
    end
  end

  it 'should update itself with exchange rates from cache' do
    bank.update_rates(cache_path)
    NbrbCurrency::CURRENCIES.each do |currency|
      expect(bank.get_rate(currency, 'BYN')).to be > 0
      expect(bank.get_rate(currency, 'BYR')).to be > 0
    end
  end

  it 'should return the correct exchange rates using exchange' do
    bank.update_rates(cache_path)
    NbrbCurrency::CURRENCIES.each do |currency|
      subunit = Money::Currency.wrap(currency).subunit_to_unit.to_f

      expected_byn = test_rate(currency).round
      expect(bank.exchange(default_amount * subunit, currency, 'BYN').cents).to eq(expected_byn)

      expected_byr = (test_rate(currency) * NbrbCurrency::DENOMINATION_RATE / 100).round
      expect(bank.exchange(default_amount * subunit, currency, 'BYR').cents).to eq(expected_byr)
    end
  end

  it 'should return the correct exchange rates using exchange_with' do
    bank.update_rates(cache_path)
    NbrbCurrency::CURRENCIES.each do |currency|
      subunit = Money::Currency.wrap(currency).subunit_to_unit.to_f

      expected_byn = test_rate(currency).round
      expect(bank.exchange_with(Money.new(default_amount * subunit, currency), 'BYN').cents).to eq(expected_byn)

      expected_byr = (test_rate(currency) * NbrbCurrency::DENOMINATION_RATE / 100).round
      expect(bank.exchange_with(Money.new(default_amount * subunit, currency), 'BYR').cents).to eq(expected_byr)
    end
  end

  # in response to #4
  it 'should exchange btc' do
    bank.add_rate('USD', 'BTC', 1 / 13.7603)
    bank.add_rate('BTC', 'USD', 13.7603)

    subunit = Money::Currency.wrap('BTC').subunit_to_unit.to_f
    expect(bank.exchange(10 * subunit, 'BTC', 'USD').to_f).to eq(137.6)
  end
end
