require 'spec_helper'

describe 'Apothecary::Project' do

  let(:root) { Dir.mktmpdir('apothecarySpecs') }
  let(:project) { Apothecary::Project.new(root) }

  before(:each) do
    project.create_skeleton

    %w[.ignore_me server client api].each do |env_name|
      project.write_environment_yaml env_name, <<-YAML
        #{env_name}: "#{env_name} default"
      YAML

      project.write_environment_yaml "#{env_name}/alternate", <<-YAML
        #{env_name}: "#{env_name} alternate"
      YAML
    end
    File.open(File.join(project.environments_path, 'not_a_directory'), 'w') { |f| f << "Files aren't environments" }

    project.write_request_yaml 'messages', <<-YAML
        path: /messages
        method: GET
      YAML
  end

  # ===== REQUESTS =====================================================================================================

  describe '#requests_path' do

    it 'returns the path to the requests directory' do
      expect(project.requests_path).to eq(File.join(root, 'requests'))
    end

  end

  describe '#request_paths' do
    it 'returns the paths of all request files in the project' do
      expect(project.request_paths).to eq([ File.join(project.requests_path, 'messages.yaml') ])
    end
  end

  describe '#request_named' do

    it 'returns the request data matching the name when it exists' do
      request = project.request_named('messages')
      expect(request).to eq({ 'path' => '/messages',
                              'method' => 'GET' })
    end

    it 'returns nil when no request exists' do
      expect(project.request_named('messages/delete')).to be_nil
    end

  end

  # ===== SESSIONS =====================================================================================================

  describe '#create_session' do

    let(:session) { project.create_session('jam_session',
                                           environments: %w[api/alternate],
                                           variables: {
                                               'a' => 1,
                                               'b' => 2
                                           }) }

    it "should create a session directory" do
      expect(session.configuration_path).to_not be_nil
      expect(File.exists?(session.configuration_path)).to be_truthy

      expect(YAML.load(File.read(session.configuration_path))).to eq({'environments' => %w[api/alternate],
                                                                      'variables' => {
                                                                          'a' => 1,
                                                                          'b' => 2
                                                                        }
                                                                      })
    end

  end

  describe "#open_session" do

    before(:each) do
      project.create_session('jelly_session',
                             environments: %w[server/alternate],
                             variables: {
                                 'a' => 1,
                                 'b' => 2
                             })
    end

    it "should load the session from disk" do
      session = project.open_session('jelly_session')
      expect(session).not_to be_nil
      expect(session.environment_names).to eq(%w[server/alternate])
      expect(session.variables).to eq('a' => 1,
                                      'b' => 2)
    end

  end

  describe '#default_session' do

    let(:default_session) { project.default_session }

    it 'returns the default session' do
      expect(default_session).not_to be_nil
      expect(default_session.name).to eq('default')
      expect(default_session).to equal(project.default_session)

      expect(default_session.environment_names).to eq(%w[])
      expect(default_session.evaluate("server")).to eq("server default")
      expect(default_session.evaluate("client")).to eq("client default")
      expect(default_session.evaluate("api")).to eq("api default")
    end

  end

  describe "#session_with_environments" do

    let(:session_with_environments) {
      project.session_with_environments(%w[server/alternate client])
    }

    it 'returns a session with the given environments' do
      expect(session_with_environments).not_to be_nil
      expect(session_with_environments.evaluate("server")).to eq("server alternate")
      expect(session_with_environments.evaluate("client")).to eq("client default")

      # default environments are still included even when not listed
      expect(session_with_environments.evaluate("api")).to eq("api default")
    end

  end

  describe '#session_names' do

    before(:each) do
      project.create_session 'alpha'
      project.create_session 'beta'
    end

    it 'returns an array of all stored sessions' do
      expect(project.session_names).to eq(%w[alpha beta])
    end

  end

  # ===== ENVIRONMENTS =================================================================================================

  describe '#environments_path' do

    it 'returns the path where environments are stored' do
      expect(project.environments_path).to eq(File.join(project.path, 'environments'))
    end

  end

  describe 'variant_path_for_environment' do

    it 'accepts environments name for defaults' do
      expect(project.variant_path_for_environment('api')).to eq(File.join(project.environments_path, 'api', 'default.yaml'))
    end

    it 'accepts variants' do
      expect(project.variant_path_for_environment('api/sandbox')).to eq(File.join(project.environments_path, 'api', 'sandbox.yaml'))
    end

  end

  describe '#environment_names' do

    it 'returns the names of all environments in the project' do
      expect(project.environment_names.sort).to eq(%w[api client server])
    end

  end

  # ===== FLOWS ========================================================================================================

  describe '#flows_path' do

    it "returns the path where flows are stored" do
      expect(project.flows_path).to eq(File.join(project.path, 'flows'))
    end

  end

end