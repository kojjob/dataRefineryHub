module ActionCableHelpers
  def stub_connection(current_user: nil)
    # Stub the connection object to return our test user
    connection = instance_double(ApplicationCable::Connection, 
      current_user: current_user,
      identifiers: [:current_user]
    )
    allow_any_instance_of(described_class).to receive(:connection).and_return(connection)
  end

  # Helper to check if a channel has a specific stream
  RSpec::Matchers.define :have_stream_from do |expected_stream|
    match do |actual|
      actual.streams.include?(expected_stream)
    end

    failure_message do |actual|
      "expected channel to stream from #{expected_stream}, but streams were #{actual.streams.inspect}"
    end
  end

  # Helper to check if a channel has any streams
  RSpec::Matchers.define :have_streams do
    match do |actual|
      actual.streams.any?
    end

    failure_message do |actual|
      "expected channel to have streams, but had none"
    end
  end
end

# Include helpers in channel specs
RSpec.configure do |config|
  config.include ActionCableHelpers, type: :channel
end