require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }
  let(:warden) { double('warden') }
  let(:env) do
    {
      'warden' => warden,
      'HTTP_CONNECTION' => 'Upgrade',
      'HTTP_UPGRADE' => 'websocket'
    }
  end

  describe 'authentication' do
    context 'with authenticated user' do
      before do
        allow(warden).to receive(:user).and_return(user)
      end

      it 'successfully connects' do
        connection = ApplicationCable::Connection.new(ActionCable.server, env)
        expect { connection.connect }.not_to raise_error
        expect(connection.current_user).to eq(user)
      end
    end

    context 'without authenticated user' do
      before do
        allow(warden).to receive(:user).and_return(nil)
      end

      it 'rejects the connection' do
        connection = ApplicationCable::Connection.new(ActionCable.server, env)
        expect { connection.connect }.to raise_error(ActionCable::Connection::Authorization::UnauthorizedError)
      end
    end
  end
end