class RateLimiter

  def initialize(app, options={})
    @app, @options = app, options
    @options[:prefix] ||= 'rate-limit'
    @options[:routes] ||= []

    raise ArgumentError.new('Need to set cache client before start.') unless options[:cache]
    raise ArgumentError.new('Need to set max requests number before start.') unless options[:max]
    raise ArgumentError.new('Need to set time window before start.') unless options[:time_window]
  end

  def call(env)
    request = Rack::Request.new(env)
    allowed?(request) ? @app.call(env) : throttled(request)
  end

  protected

  def allowed?(request)
    # pass if this request url does not need rate limit
    return true if not @options[:routes].include? request.env["PATH_INFO"]

    key = cache_key(request) # create redis key for the request
    count = cache.get(key)

    if count
      return false if count.to_i >= @options[:max]

      cache.incr(key)
    else
      cache.set(key, 1)
      cache.expire(key, @options[:time_window])
    end

    true
  end

  def cache
    @options[:cache]
  end

  def throttled(request)
    content_type = 'text/plain; charset=utf-8'
    message = "Rate limit exceeded. Try again in #{cache.ttl(cache_key(request))} seconds."

    [429, {'Content-Type' => content_type}, [message]]
  end

  # used for redis key
  def cache_key(request)
    "#{@options[:prefix]}::#{request.ip.to_s}"
  end

end
