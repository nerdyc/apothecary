require 'spec_helper'

describe 'Apothecary::Session' do

  let(:root) { Dir.mktmpdir('apothecarySpecs') }
  let(:project) { Apothecary::Project.new(root) }
  let(:session) { project.default_session }

  # ===== REQUESTS =====================================================================================================

  describe '#perform_request!' do

    context 'when the request exists' do

      before(:each) do
        project.write_context_yaml 'api', <<-YAML
          base_url: https://api.communique.dev
          message: Hello, World!
          user_agent: Apothecary
        YAML

        project.write_request_yaml 'messages/post', <<-YAML
            path:   /messages
            method: POST
            headers:
              User-Agent: "{{user_agent}}"
              X-Greek:
                - Alpha
                - Beta
            json_body:
              type: text
              text: "{{message}}"
        YAML

        stub_request(:post,
                     "https://api.communique.dev/messages")
            .with(headers: { 'Content-Type' => 'application/json',
                             'User-Agent' => 'Apothecary' },
                  body: { type: 'text', text: 'Hello, World!' })
            .to_return(status: 200,
                       body: '[]',
                       headers: { 'Content-Type' => 'application/json',
                                  'Content-Length' => 2 })

        session.perform_request! 'messages/post'
      end

      it 'sends the request' do
        expect(WebMock).to have_requested(:post, 'https://api.communique.dev/messages')
      end

      it 'updates request statistics' do
        expect(session.request_count).to eq(1)
        expect(session.total_received).to eq(2)
      end

      # Note:
      # Testing that the request and response are written to disk proved difficult/impossible since the implementation
      # depends on curb/libcurl callbacks that aren't fired when mocked.

    end

    context "when the request doesn't exist" do

      it "raises an exception if the request doesn't exist" do
        expect { session.perform_request! 'messages/not_found' }.to raise_error
      end

    end

    context "when the request defines output variables" do

      it 'updates the session after executing the request' do
        stub_request(:get, "https://api.communique.dev/profile")
            .to_return(status: 200,
                       body: JSON.generate(:profile => {
                                :first_name => 'Amelia',
                                :last_name => 'Grey',
                                :photo_url => 'https://api.communique.dev/content/photo.jpeg' }
                             ))

        session.perform_request!('scheme' => 'https',
                                 'host' => 'api.communique.dev',
                                 'path' => '/profile',
                                 'output' => {
                                     'user_photo_url' => '{{profile.photo_url}}'
                                 })

        expect(session.evaluate('user_photo_url')).to eq('https://api.communique.dev/content/photo.jpeg')
      end

    end

  end

end