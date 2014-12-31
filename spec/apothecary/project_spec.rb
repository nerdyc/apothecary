require 'spec_helper'

describe 'Apothecary::Project' do

  let(:root) { Dir.mktmpdir('apothecarySpecs') }
  let(:project) { Apothecary::Project.new(root) }

  before(:each) do
    project.create_skeleton

    %w[.ignore_me server client api].each do |context_name|
      context_path = File.join(project.contexts_path, context_name)
      FileUtils.mkdir_p(context_path)

      # default values
      File.open(File.join(context_path, 'default.yaml'), 'w') { |f| f << "#{context_name}: \"#{context_name} default\"" }

      # alternate variant
      File.open(File.join(context_path, 'alternate.yaml'), 'w') { |f| f << "#{context_name}: \"#{context_name} alternate\"" }

    end
    File.open(File.join(project.contexts_path, 'not_a_directory'), 'w') { |f| f << "Files aren't contexts" }

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
                                           contexts: %w[api/alternate],
                                           variables: {
                                               'a' => 1,
                                               'b' => 2
                                           }) }

    it "should create a session directory" do
      expect(session.configuration_path).to_not be_nil
      expect(File.exists?(session.configuration_path)).to be_truthy

      expect(YAML.load(File.read(session.configuration_path))).to eq({'contexts' => %w[api/alternate],
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
                             contexts: %w[server/alternate],
                             variables: {
                                 'a' => 1,
                                 'b' => 2
                             })
    end

    it "should load the session from disk" do
      session = project.open_session('jelly_session')
      expect(session).not_to be_nil
      expect(session.context_names).to eq(%w[server/alternate])
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

      expect(default_session.context_names).to eq(%w[])
      expect(default_session.evaluate("server")).to eq("server default")
      expect(default_session.evaluate("client")).to eq("client default")
      expect(default_session.evaluate("api")).to eq("api default")
    end

  end

  describe "#session_with_contexts" do

    let(:session_with_contexts) {
      project.session_with_contexts(%w[server/alternate client])
    }

    it 'returns a session with the given contexts' do
      expect(session_with_contexts).not_to be_nil
      expect(session_with_contexts.evaluate("server")).to eq("server alternate")
      expect(session_with_contexts.evaluate("client")).to eq("client default")

      # default contexts are still included even when not listed
      expect(session_with_contexts.evaluate("api")).to eq("api default")
    end

  end

  # ===== CONTEXTS =====================================================================================================

  describe '#contexts_path' do

    it 'returns the path to the contexts directory' do
      expect(project.contexts_path).to eq(File.join(project.path, 'contexts'))
    end

  end

  describe 'variant_path_for_context' do

    it 'accepts context name for defaults' do
      expect(project.variant_path_for_context('api')).to eq(File.join(project.contexts_path, 'api', 'default.yaml'))
    end

    it 'accepts variants' do
      expect(project.variant_path_for_context('api/sandbox')).to eq(File.join(project.contexts_path, 'api', 'sandbox.yaml'))
    end

  end

  describe '#context_names' do

    it 'returns the names of all contexts in the project' do
      expect(project.context_names.sort).to eq(%w[api client server])
    end

  end

end