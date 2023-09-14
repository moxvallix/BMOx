require 'discordrb'

class BMOx::Bot
  def self.start
    new.start
  end

  def initialize
    @bot = Discordrb::Commands::CommandBot.new token: ENV["TOKEN"], client_id: ENV["CLIENT_ID"], prefix: ENV.fetch("PREFIX", "/")
    @typing = {}
    @characters = {}
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
    
    BMOx::PROMPT_DIR.glob("*.character").each do |template|
      puts "Registering: #{template.basename}"
      character = BMOx::Character.new(template.read)
      unless character.prompt_id
        puts "Character is missing a prompt id!"
        next
      end
      @characters[character.prompt_id] = character
      @bot.command character.prompt_id.to_s.to_sym do |event, *args|
        queue_command(character: character, event: event, args: args)
        nil
      end
    end
  end

  def process_response(event, args, output, character)
    embed = Discordrb::Webhooks::Embed.new(author: character.discord_author, description: output.to_s.strip)
    event.channel.send_message("", false, embed)
  end

  def respond_as_character(character, event, args)
    event.channel.typing = true
    user_prompt = args.join(" ")
    output = character.reply_to(user_prompt)
    event.channel.typing = false
    process_response(event, args, output, character)
  end

  def process_command(data)
    respond_as_character(data[:character], data[:event], data[:args])
  end

  def queue_command(**data)
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