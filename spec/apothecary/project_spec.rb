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

  describe '#default_session' do

    it 'returns the default session' do
      expect(project.default_session).not_to be_nil
      expect(project.default_session.name).to eq('default')
      expect(project.default_session).to equal(project.default_session)
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

  # ===== ENVIRONMENTS =================================================================================================

  describe '#default_environment_variables' do

    it 'returns default envionment variables' do
      expect(project.default_environment_variables).to eq({ "server" => "server default",
                                                            "client" => "client default",
                                                            "api"    => "api default"})
    end

  end


  describe '#default_environment' do

    it 'returns an environment composed of all default contexts' do
      default_environment = project.default_environment
      expect(default_environment).not_to be_nil

      expect(default_environment.evaluate("server")).to eq("server default")
      expect(default_environment.evaluate("client")).to eq("client default")
      expect(default_environment.evaluate("api")).to eq("api default")
    end

  end

  describe '#environment_with_contexts' do

    it 'returns a new environment composed of the given contexts' do
      default_environment = project.environment_with_contexts(%w[server/alternate client])
      expect(default_environment).not_to be_nil

      expect(default_environment.evaluate("server")).to eq("server alternate")
      expect(default_environment.evaluate("client")).to eq("client default")

      # default contexts are still included even when not listed
      expect(default_environment.evaluate("api")).to eq("api default")
    end

  end

end