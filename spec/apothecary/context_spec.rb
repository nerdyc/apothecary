require 'spec_helper'

describe 'Apothecary::Context' do

  let(:context) { Apothecary::Context.new({'base_url' => 'http://api.communique.dev',
                                              'email' => 'amelia@communique.dev',
                                              'given_name' => 'Amelia',
                                              'family_name' => 'Grey',
                                              'labels' => %w[friend foe]},
                                          [ Apothecary::Context.new(
                                              'company' => {
                                                  'legal_name' => 'Communiqué',
                                                  'url' => 'http://communique.dev'
                                              }) ])
                    }

  # ===== VARIABLES ====================================================================================================

  describe '#evaluate' do

    context 'when the variable is defined' do

      it 'returns the value' do
        expect(context.evaluate('base_url')).to eq('http://api.communique.dev')
      end

    end

    context 'when the variable isn\'t defined' do

      it 'returns nil' do
        expect(context.evaluate('not_a_thing')).to be_nil
      end

    end

  end

  # ===== INTERPOLATION ==============================================================================================

  describe '#interpolate' do

    context 'when provided a string value' do

      it 'returns variables directly when it spans the entire string' do
        # returning the raw value allows hashes and arrays to be expanded, not just strings
        expect(context.interpolate('{{labels}}')).to eq(%w[friend foe])
      end

      it 'replaces references within the string' do
        expect(context.interpolate('Amelia Grey <{{email}}>')).to eq("Amelia Grey <amelia@communique.dev>")
      end

      it 'replaces multiple references' do
        expect(context.interpolate('{{given_name}} {{family_name}} <{{email}}>')).to eq("Amelia Grey <amelia@communique.dev>")
      end

      it 'replaces unknown values with the empty string' do
        expect(context.interpolate('{{given_name}} {{last_name}} <{{email}}>')).to eq("Amelia  <amelia@communique.dev>")
      end

      it 'supports dot syntax to navigate hashes' do
        expect(context.interpolate("{{company.legal_name}}")).to eq('Communiqué')
        expect(context.interpolate("{{organization.name}}")).to be_nil
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

        expect(context.interpolate(hash_value)).to eq(interpolated_value)
      end

    end

    context 'when provided an array of values' do

      it 'interpolates each member of the array' do
        array_value = [ 'Email:', '{{email}}', 'Given:', '{{given_name}}', 'Family:', '{{family_name}}' ]
        interpolated_value = [ 'Email:', 'amelia@communique.dev', 'Given:', 'Amelia', 'Family:', 'Grey' ]

        expect(context.interpolate(array_value)).to eq(interpolated_value)
      end

    end

  end


end
