require 'rails_helper'
require "fakeredis"

describe RateLimiter do
  MAX = 5
  TIME_WINDOW = 30
  IP = '::1'
  PREFIX = 'rate-limit-test'

  cache = Redis.new # fakeredis overwrites real one here

  let(:app) { ->(env) { [200, env, 'ok'] } }
  subject { RateLimiter.new(app, {
    cache: cache,
    max: MAX,
    time_window: TIME_WINDOW,
    prefix: PREFIX,
    routes: ['/home/index'] }) }

  context 'mandatory params' do
    it 'throws exception if not set cache client' do
      expect { RateLimiter.new(app) }.to raise_error('Need to set cache client before start.')
    end

    it 'throws exception if not set max number' do
      expect { RateLimiter.new(app, {cache: 'redis'}) }.to raise_error('Need to set max requests number before start.')
    end

    it 'throws exception if not set time window' do
      expect { RateLimiter.new(app, {cache: 'redis', max: 100}) }.to raise_error('Need to set time window before start.')
    end

  end

  context 'requests need rate limit' do

    it 'returns 200 if not exceed limit' do
      code, header, message = subject.call(env_for('/home/index'))
      expect(code).to eq(200)
      expect(message).to eq('ok')
    end

    it 'returns 429 if exceed limit' do
      for i in 0..MAX - 1
        subject.call(env_for('/home/index'))
      end

      code, header, message = subject.call(env_for('/home/index'))
      expect(code).to eq(429)
    end

    it 'shows how many seconds left' do
      for i in 0..MAX - 1
        subject.call(env_for('/home/index'))
      end

      seconds_left = rand(1..TIME_WINDOW-1)
      allow(cache).to receive(:ttl) { seconds_left }

      code, header, message = subject.call(env_for('/home/index'))
      expect(message[0]).to eq("Rate limit exceeded. Try again in #{seconds_left} seconds.")

      allow(cache).to receive(:ttl).and_call_original
    end

    it 'returns 200 after limit expires' do
      for i in 0..MAX - 1
        subject.call(env_for('/home/index'))
      end

      cache.expire(cache_key, 0)

      code, header, message = subject.call(env_for('/home/index'))
      expect(code).to eq(200)
      expect(message).to eq('ok')
    end
  end

  context 'requests do not need rate limit' do
    it 'returns 200 if exceed limit' do
      for i in 0..MAX - 1
        subject.call(env_for('/static_page'))
      end

      code, header, message = subject.call(env_for('/static_page'))
      expect(code).to eq(200)
      expect(message).to eq('ok')
    end

    it 'returns 200 if not exceed limit' do
      subject.call(env_for('/static_page'))

      code, header, message = subject.call(env_for('/static_page'))
      expect(code).to eq(200)
      expect(message).to eq('ok')
    end
  end
end

def env_for url
  Rack::MockRequest.env_for(url, { "REMOTE_ADDR" => IP })
end

def cache_key
  "#{PREFIX}::#{IP}"
end