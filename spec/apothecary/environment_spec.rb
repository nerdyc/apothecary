require 'spec_helper'

describe 'Apothecary::Environment' do

  let(:environment) { Apothecary::Environment.new('base_url' => 'http://api.communique.dev',
                                                  'email' => 'amelia@communique.dev',
                                                  'given_name' => 'Amelia',
                                                  'family_name' => 'Grey',
                                                  'labels' => %w[friend foe],
                                                  'company' => {
                                                      'name' => 'Communiqué',
                                                      'url' => 'http://communique.dev'
                                                  })
                    }

  # ===== VARIABLES ====================================================================================================

  describe '#evaluate' do

    context 'when the variable is defined' do

      it 'returns the value' do
        expect(environment.evaluate('base_url')).to eq('http://api.communique.dev')
      end

    end

    context 'when the variable isn\'t defined' do

      it 'returns nil' do
        expect(environment.evaluate('not_a_thing')).to be_nil
      end

    end

  end

  # ===== INTERPOLATION ==============================================================================================

  describe '#interpolate' do

    context 'when provided a string value' do

      it 'returns variables directly when it spans the entire string' do
        # returning the raw value allows hashes and arrays to be expanded, not just strings
        expect(environment.interpolate('{{labels}}')).to eq(%w[friend foe])
      end

      it 'replaces references within the string' do
        expect(environment.interpolate('Amelia Grey <{{email}}>')).to eq("Amelia Grey <amelia@communique.dev>")
      end

      it 'replaces multiple references' do
        expect(environment.interpolate('{{given_name}} {{family_name}} <{{email}}>')).to eq("Amelia Grey <amelia@communique.dev>")
      end

      it 'replaces unknown values with the empty string' do
        expect(environment.interpolate('{{given_name}} {{last_name}} <{{email}}>')).to eq("Amelia  <amelia@communique.dev>")
      end

      it 'supports dot syntax to navigate hashes' do
        expect(environment.interpolate("{{company.name}}")).to eq('Communiqué')
        expect(environment.interpolate("{{organization.name}}")).to be_nil
      end

    end

    context 'when provided a hash value' do

      it 'traverses the hash and interpolates each value' do
        hash_value = {
            'email' => '{{email}}',
            'name' => {
                'given' => '{{given_name}}',
                'family' => '{{family_name}}'
            }
        }

        interpolated_value = {
            'email' => 'amelia@communique.dev',
            'name' => {
                'given' => 'Amelia',
                'family' => 'Grey'
            }
        }

        expect(environment.interpolate(hash_value)).to eq(interpolated_value)
      end

    end

    context 'when provided an array of values' do

      it 'interpolates each member of the array' do
        array_value = [ 'Email:', '{{email}}', 'Given:', '{{given_name}}', 'Family:', '{{family_name}}' ]
        interpolated_value = [ 'Email:', 'amelia@communique.dev', 'Given:', 'Amelia', 'Family:', 'Grey' ]

        expect(environment.interpolate(array_value)).to eq(interpolated_value)
      end

    end

  end

  # ===== URI ==========================================================================================================

  describe "#uri_from_value" do

    context "when provided a string" do

      it 'returns the parsed URI' do
        uri = URI.parse("http://api.communique.dev/groups")
        expect(environment.uri_from_value("http://api.communique.dev/groups")).to eq(uri)
      end

    end

    context "when provided a URI" do

      it 'returns the same URI' do
        uri = URI.parse("http://api.communique.dev/groups")
        expect(environment.uri_from_value(uri)).to equal(uri)
      end

    end

    context "when provided a hash" do

      it 'constructs a URI from a hash of values' do
        absolute_uri = environment.uri_from_hash('scheme' => 'https',
                                                 'host'   => 'some-api.communique.dev',
                                                 'port'   => 4321,
                                                 'path'   => '/messages')

        expect(absolute_uri).to eq(URI.parse('https://some-api.communique.dev:4321/messages'))

        relative_uri = environment.uri_from_value('path'   => '/messages')
        expect(relative_uri).to eq(URI.parse('/messages'))
      end

      it 'defaults to https if host given, but no scheme' do
        uri = environment.uri_from_value('host'   => 'some-api.communique.dev',
                                         'path'   => '/messages')

        expect(uri).to eq(URI.parse('https://some-api.communique.dev/messages'))
      end
    end

  end

  describe "#resolve_uri" do

    context 'when a base url is defined' do

      it 'resolves the uri against the base URL' do
        e = Apothecary::Environment.new('base_url' => 'http://api.communique.dev/v2/')
        expect(e.resolve_uri("messages/unread")).to eq(URI.parse('http://api.communique.dev/v2/messages/unread'))

      end

    end


    context 'when a base url is not defined' do

      it 'resolves the uri against the base URL' do
        e = Apothecary::Environment.new({})
        expect(e.resolve_uri("messages/unread")).to eq(URI.parse('messages/unread'))
      end

    end

  end

end
