require 'discordrb'

class BMOx::Bot
  def self.start
    new.start
  end

  def initialize
    @bot = Discordrb::Commands::CommandBot.new token: ENV["TOKEN"], client_id: ENV["CLIENT_ID"], prefix: ENV.fetch("PREFIX", "/")
    @typing = {}
    @characters = []
    @queue = []
    @queue_loop = false
    
    @bot.command :bmox_list do |_event, *args|
      "**META:** Available Characters\n" + @characters.join("\n")
    end

    @bot.command :bmox_queue do |_event, *args|
      "**META:** There are #{@queue.size + (@queue_loop ? 1 : 0)} prompts being processed currently."
    end

    @bot.command :bmox_help do |_event, *args|
      "**META:** BMOx, by Moxvallix\nRun `/bmox_list` to see character commands!\nRun `/bmox_queue` to see the queue size."
    end
    
    @bot.command :bmox_reload do |_event, *args|
      if @queue.size > 0
        "**META:** Queue is not empty!"
      else
        self.class.restart
      end
    end
    
    BMOx::PROMPT_DIR.glob("*.template").each do |template|
      puts "Registering: #{template.basename}"
      command_name = template.basename.to_s.delete_suffix(".template").to_sym
      @characters << command_name.to_s
      @bot.command command_name do |event, *args|
        queue_command(template: template, event: event, args: args)
        nil
      end
    end
  end
  
  
  def start_typing(channel)
    @typing[channel.id] = true
    Thread.new do
      while @typing[channel.id] do
        channel.start_typing
        sleep 5
      end
    end
  end

  def stop_typing(channel)
    @typing[channel.id] = false
  end

  def process_response(event, args, output, char_name)
    if ENV["HIDE_NAMES"]
      event.channel.send_message output.match(/(?<=### Assistant:)[\s\S]+/).to_s.strip
    else
      event.channel.send_message "**#{char_name}:** " + output.match(/(?<=### Assistant:)[\s\S]+/).to_s.strip
    end
  end

  def respond_as_character(file, event, args)
    start_typing(event.channel)
    user_prompt = args.join(" ")
    llama = BMOx::Llama.new(file, username: event.author.display_name, prompt: user_prompt)
    output, status = llama.generate
    puts output
    stop_typing(event.channel)
    char_name = file.basename.to_s.delete_suffix(".template").capitalize
    process_response(event, args, output, char_name)
  end

  def process_command(data)
    respond_as_character(data[:template], data[:event], data[:args])
  end

  def queue_command(data = {})
    @queue << data
    return if @queue_loop
    @queue_loop = true
    Thread.new do
      while @queue.any?
        command = @queue.delete_at(0)
        begin
          process_command(command)
        rescue => e
          @queue.append(command)
          puts "Error found, retrying... #{e.message}"
        end
      end
      @queue_loop = false
    end
  end

  def start
    @bot.run
  end
end