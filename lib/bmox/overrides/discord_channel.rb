class Discordrb::Channel
  def typing=(value)
    @typing = value
    return value if @typing.is_a?(Numeric) && @typing <= 0
    Thread.new do
      while @typing
        @typing = false if @typing.is_a?(Numeric) && @typing <= 0
        start_typing
        sleep 5
      end
    end
    value
  end
end