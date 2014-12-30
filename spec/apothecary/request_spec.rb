require 'spec_helper'

describe 'Apothecary::Request' do

  let(:request_identifier) { "abc123" }
  let(:request_name) { "test/request" }
  let(:requests_path) { Dir.mktmpdir("apothecary_request") }

  # ===== REQUEST METHODS ==============================================================================================

  context "when the 'method' is GET" do

    let(:request) { Apothecary::Request.new(request_identifier,
                                            request_name,
                                            "https://api.communique.dev/messages",
                                            { 'method' => 'GET' },
                                            requests_path) }

    before(:each) do
      stub_request(:get, "https://api.communique.dev/messages")
    end

    it 'sends a GET request' do
      expect { request.send! }.not_to raise_error
      expect(WebMock).to have_requested(:get, 'https://api.communique.dev/messages')
    end

    # Note:
    # Testing that the request and response are written to disk proved difficult/impossible since the implementation
    # depends on curb/libcurl callbacks that aren't fired when mocked.

  end

  context "when the 'method' is omitted" do

    let(:request) { Apothecary::Request.new(request_identifier,
                                            request_name,
                                            "https://api.communique.dev/messages",
                                            { },
                                            requests_path) }



    it "defaults to 'GET'" do
      expect(request.request_method).to eq('GET')
    end

  end

  context 'when a POST request is made' do

    context 'with a json_body value' do

      let(:request) {
        Apothecary::Request.new(request_identifier,
                                request_name,
                                "https://api.communique.dev/messages",
                                {
                                    'method' => 'POST',
                                    'json_body' => {
                                      'type' => 'text',
                                      'text' => 'Hello, World!'
                                    }
                                },
                                requests_path)
      }

      before(:each) do
        stub_request(:post,
                     "https://api.communique.dev/messages")
            .with(headers: { 'Content-Type' => 'application/json'},
                  body: { type: 'text', text: 'Hello, World!' })
            .to_return(status: 200,
                       body: '[]',
                       headers: { 'Content-Type' => 'application/json',
                                  'Content-Length' => 2 })
      end

      it 'sends the json and sets the Content-Type header' do
        expect { request.send! }.not_to raise_error
        expect(WebMock).to have_requested(:post, 'https://api.communique.dev/messages')
      end

    end

  end

  context 'when a PUT request is made' do

    context 'with a json_body value' do

      let(:request) {
        Apothecary::Request.new(request_identifier,
                                request_name,
                                "https://api.communique.dev/messages",
                                {
                                    'method' => 'PUT',
                                    'json_body' => {
                                        'type' => 'text',
                                        'text' => 'Hello, World!'
                                    }
                                },
                                requests_path)
      }

      before(:each) do
        stub_request(:put,
                     "https://api.communique.dev/messages")
            .with(headers: { 'Content-Type' => 'application/json'},
                  body: { type: 'text', text: 'Hello, World!' })
            .to_return(status: 200,
                       body: '[]',
                       headers: { 'Content-Type' => 'application/json',
                                  'Content-Length' => 2 })
      end

      it 'sends the json and sets the Content-Type header' do
        expect { request.send! }.not_to raise_error
        expect(WebMock).to have_requested(:put, 'https://api.communique.dev/messages')
      end

    end

  end

  # ===== HEADERS ======================================================================================================

  context 'when headers are present' do

    let(:request) { Apothecary::Request.new("abc123",
                                            "messages",
                                            "https://api.communique.dev/messages",
                                            {
                                                'headers' => {
                                                    'User-Agent' => 'Apothecary',
                                                    'X-Greek' => %w[Alpha Beta]
                                                }
                                            },
                                            Dir.mktmpdir('apothecarySpecs')) }

    before(:each) do
      stub_request(:get,
                   "https://api.communique.dev/messages")
          .with(headers: { 'User-Agent' => 'Apothecary',
                           'X-Greek' => %w[Alpha Beta]})
    end

    it 'sets the headers in the request' do
      expect { request.send! }.not_to raise_error
      expect(WebMock).to have_requested(:get, 'https://api.communique.dev/messages')
    end

  end

  # ===== AUTHORIZATION ================================================================================================

  context 'when authorization data is present' do

    let(:request) { Apothecary::Request.new("abc123",
                                            "messages/secret",
                                            "https://api.communique.dev/messages/secret",
                                            {
                                                'username' => 'edith@communique.dev',
                                                'password' => 'abcdef123456'
                                            },
                                            Dir.mktmpdir('apothecarySpecs')) }

    it 'has a username and password' do
      expect(request.username).to eq('edith@communique.dev')
      expect(request.password).to eq('abcdef123456')
    end

    it 'sets an authorization header' do
      stub_request(:get,
                   "https://edith%40communique.dev:abcdef123456@api.communique.dev/messages/secret")
          .to_return(status: 200,
                     body: '[]',
                     headers: { 'Content-Type' => 'application/json',
                                'Content-Length' => 2 })

      request.send!
    end

  end



end