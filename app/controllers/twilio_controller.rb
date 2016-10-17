class TwilioController < ApplicationController
  TWILIO_API_HOST = 'https://api.twilio.com'

  before_action :set_client_and_number, only: [:start_call_record, :broadcast_send, :fetch_recordings, :conference]

  # GET /conference
  def conference
    @conference_number = @twilio_number
  end

  # POST /conference
  def join_conference
    twiml = Twilio::TwiML::Response.new do |r|
      r.Say "You are about to join the Rapid Response conference"
      r.Gather action: "conference/connect" do |g|
        g.Say "Press 1 to join as a listener."
        g.Say "Press 2 to join as a speaker."
        g.Say "Press 3 to join as the moderator."
      end
    end
    # can also use .text here, which is aliased to .to_xml in twilio-ruby
    # render xml: twiml.text
    render xml: twiml.to_xml
  end

  # POST /conference/connect
  def conference_connect
    case params['Digits']
    when "1" # listener
      @muted = "true"
    when "3" # moderator
      @moderator = "true"
    end

    twiml = Twilio::TwiML::Response.new do |r|
      r.Say "You have joined the conference."
      r.Dial do |d|
        d.Conference "RapidResponseRoom",
          waitUrl: "http://twimlets.com/holdmusic?Bucket=com.twilio.music.ambient",
          muted: @muted || "false",
          startConferenceOnEnter: @moderator || "false",
          endConferenceOnExit: @moderator || "false"
      end
    end
    render xml: twiml.to_xml
  end

  # POST /broadcast/record
  def broadcast_record
    twiml = Twilio::TwiML::Response.new do |r|
      r.Say "Please record your message after the beep. Press star to end your recording."
      r.Record finishOnKey: "*"
    end
    render xml: twiml.to_xml
  end

  # POST /broadcast/send
  def broadcast_send
    numbers = CSV.parse(params[:numbers])
    recording = params[:recording_url]
    url = request.base_url + '/broadcast/play?recording_url=' + recording

    numbers.each do |number|
      @client.calls.create(
        from: @twilio_number,
        to: number,
        url: url
      )
    end
  end

  # POST /broadcast/play
  def broadcast_play
    recording_url = params[:recording_url]

    twiml = Twilio::TwiML::Response.new do |r|
      r.Play recording_url
    end
    render xml: twiml.to_xml
  end

  # GET /broadcast
  def broadcast
  end

  # POST /call_recording
  def start_call_record
    phone_number = params[:phone_number]

    @client.calls.create(
      from: @twilio_number,
      to: phone_number,
      url: "#{request.base_url}/broadcast/record"
    )
  end

  # GET /fetch_recordings
  def fetch_recordings
    recordings = @client.recordings.list.map do |recording|
      {
        url:  full_recording_uri(recording.uri),
        date: recording.date_created
      }
    end

    render json: recordings
  end

  private

  # returns full uri given partial recording uri
  def full_recording_uri(uri)
    # remove json extension from uri
    clean_uri = uri.sub!('.json', '')

    "#{TWILIO_API_HOST}#{clean_uri}"
  end

  def set_client_and_number
    @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
    @twilio_number = ENV['TWILIO_NUMBER']
  end
end
