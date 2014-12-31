require 'spec_helper'

describe 'Apothecary::Session' do

  let(:root) { Dir.mktmpdir('apothecarySpecs') }
  let(:project) { Apothecary::Project.new(root) }

  # ===== URI ==========================================================================================================

  describe "#uri_from_value" do

    let(:session) { project.session_with_variables('base_url' => 'http://api.communique.dev',
                                                   'email' => 'amelia@communique.dev',
                                                   'given_name' => 'Amelia',
                                                   'family_name' => 'Grey',
                                                   'labels' => %w[friend foe],
                                                   'company' => {
                                                       'name' => 'Communiqué',
                                                       'url' => 'http://communique.dev'
                                                   })
    }

    context "when provided a string" do

      it 'returns the parsed URI' do
        uri = URI.parse("http://api.communique.dev/groups")
        expect(session.uri_from_value("http://api.communique.dev/groups")).to eq(uri)
      end

    end

    context "when provided a URI" do

      it 'returns the same URI' do
        uri = URI.parse("http://api.communique.dev/groups")
        expect(session.uri_from_value(uri)).to equal(uri)
      end

    end

    context "when provided a hash" do

      it 'constructs a URI from a hash of values' do
        absolute_uri = session.uri_from_hash('scheme' => 'https',
                                             'host'   => 'some-api.communique.dev',
                                             'port'   => 4321,
                                             'path'   => '/messages')

        expect(absolute_uri).to eq(URI.parse('https://some-api.communique.dev:4321/messages'))

        relative_uri = session.uri_from_value('path'   => '/messages')
        expect(relative_uri).to eq(URI.parse('/messages'))
      end

      it 'defaults to https if host given, but no scheme' do
        uri = session.uri_from_value('host'   => 'some-api.communique.dev',
                                     'path'   => '/messages')

        expect(uri).to eq(URI.parse('https://some-api.communique.dev/messages'))
      end
    end

  end

  describe "#resolve_uri" do

    context 'when a base url is defined' do

      it 'resolves the uri against the base URL' do
        e = project.session_with_variables('base_url' => 'http://api.communique.dev/v2/')
        expect(e.resolve_uri("messages/unread")).to eq(URI.parse('http://api.communique.dev/v2/messages/unread'))

      end

    end

    context 'when a base url is not defined' do

      it 'resolves the uri against the base URL' do
        e = project.session_with_variables({})
        expect(e.resolve_uri("messages/unread")).to eq(URI.parse('messages/unread'))
      end

    end

  end

  # ===== REQUESTS =====================================================================================================

  describe '#perform_request!' do

    let(:session) { project.default_session }

    context 'when the request exists' do

      before(:each) do
        project.write_environment_yaml 'api', <<-YAML
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
                             ),
                       headers: {
                           'Content-Type' => 'application/json'
                       })

        session.perform_request!('scheme' => 'https',
                                 'host' => 'api.communique.dev',
                                 'path' => '/profile',
                                 'outputs' => {
                                     'user_photo_url' => '{{profile.photo_url}}'
                                 })

        expect(session.evaluate('user_photo_url')).to eq('https://api.communique.dev/content/photo.jpeg')
      end

    end

  end

  # ===== PERSISTENCE ==================================================================================================

  describe '#save!' do

    before(:each) do
      project.write_environment_yaml 'api', <<-YAML
          base_url: https://api.communique.dev
          message: Hello, World!
          user_agent: Apothecary
      YAML

      project.write_environment_yaml 'api/staging', <<-YAML
          base_url: https://staging.communique.dev
          message: Hello, Test!
      YAML

      session.variables.merge!('token' => 'abc123')
      session.save!
    end

    let(:session) { project.create_session('my_session',
                                           environments:%w[api/staging]) }

    it "writes the session data to disk" do
      expect(File.exists?(session.configuration_path)).to be_truthy
      expect(YAML.load(File.read(session.configuration_path))).to eq('environments' => %w[api/staging],
                                                                     'variables' => { 'token' => 'abc123' })
    end

  end

  # ===== FLOWS ========================================================================================================

  describe '#perform_flow!' do

    before(:each) do
      project.write_environment_yaml 'api', <<-YAML
          base_url: https://api.communique.dev
      YAML

      project.write_environment_yaml 'profile', <<-YAML
          profile_username: amelia
          profile_first_name: Amelia
          profile_last_name: Grey
      YAML

      project.write_flow_yaml 'authorization', <<-YAML
          requests:
            - path: /sessions
              method: POST
              json_body:
                session:
                  username: "{{profile_username}}"
              outputs:
                session_id: "{{session.id}}"

            - path: "/sessions/{{session_id}}/verification"
              method: POST
              json_body:
                verification:
                  code: 1234
              outputs:
                verification_access_token: "{{verification.token}}"

            - path: "/profile"
              method: PUT
              username: "{{profile_username}}"
              password: "{{verification_access_token}}"
              json_body:
                profile:
                  first_name: "{{profile_first_name}}"
                  last_name: "{{profile_last_name}}"
      YAML

      stub_request(:post, "https://api.communique.dev/sessions")
        .with(:body => {
                  session: {
                      username: "amelia"
                  }
              })
        .to_return(
            status: 201,
            body: JSON.generate(session: { id: 456 }),
            headers: {
                'Content-Type' => 'application/json'
            }
        )

      stub_request(:post, "https://api.communique.dev/sessions/456/verification")
          .with(:body => {
                    verification: {
                        code: 1234
                    }
                })
          .to_return(
              status: 201,
              body: JSON.generate(verification: { id: 789, token: "abcdef123456" }),
              headers: {
                  'Content-Type' => 'application/json'
              }
          )

      stub_request(:put, "https://amelia:abcdef123456@api.communique.dev/profile")
          .with(:body => {
                    profile: {
                        first_name: "Amelia",
                        last_name: "Grey"
                    }
                })
          .to_return(
              status: 200,
              body: JSON.generate(profile: { first_name: "Amelia",
                                             last_name: "Grey" }),
              headers: {
                  'Content-Type' => 'application/json'
              }
          )
    end

    let(:session) { project.default_session }

    it "executes the flow of requests" do
      expect { session.perform_flow!('authorization') }.not_to raise_error

      expect(WebMock).to have_requested(:post, 'https://api.communique.dev/sessions')
      expect(WebMock).to have_requested(:post, 'https://api.communique.dev/sessions/456/verification')
      expect(WebMock).to have_requested(:put, 'https://amelia:abcdef123456@api.communique.dev/profile')

      expect(session.variables).to eq("session_id" => 456,
                                      "verification_access_token" => "abcdef123456")
    end

  end

end