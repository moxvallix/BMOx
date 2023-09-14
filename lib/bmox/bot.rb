require 'discordrb'

class BMOx::Bot
  def self.start
    new.start
  end

  def initialize
    @bot = Discordrb::Commands::CommandBot.new(
      token: BMOx::CONFIG.dig(:bot, :token),
      client_id: BMOx::CONFIG.dig(:bot, :client_id),
      prefix: BMOx::CONFIG.dig(:bot, :prefix) || "/"
    )
    @name = (BMOx::CONFIG.dig(:bot, :name) || "bmox").to_s.downcase.gsub(/[^a-z0-9]/, "_")
    @typing = {}
    @characters = {}
    @queue = []
    @queue_loop = false
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

  def on_ready
    @bot.update_status("online", "#{@bot.prefix}#{@name}_help", nil, 0, false, 2)
  end

  def start
    register_base_commands
    register_character_commands
    @bot.ready { on_ready }
    @bot.run
  end

  private

  def register_base_commands
    @bot.command :"#{@name}_list" do |_event, *args|
      str = "**META:** Available Characters\n"
      @characters.each do |id, character|
        str << "#{@bot.prefix}#{id} - Talk to #{character.name}\n"
      end
      str
    end

    @bot.command :"#{@name}_queue" do |_event, *args|
      "**META:** There are #{@queue.size + (@queue_loop ? 1 : 0)} prompts being processed currently."
    end

    @bot.command :"#{@name}_help" do |_event, *args|
      prefix = "#{@bot.prefix}#{@name}"
      "**META:** BMOx, by Moxvallix\nRun `#{prefix}_list` to see character commands!\nRun `#{prefix}_queue` to see the queue size."
    end
    
    @bot.command :"#{@name}_reload" do |_event, *_args|
      @characters.each { |id, _| @bot.remove_command(:"#{id}") }
      @characters = {}
      register_character_commands
      prefix = "#{@bot.prefix}#{@name}"
      "**META:** Registered #{@characters.size} characters.\nRun `#{prefix}_list` to see character commands!"
    end
  end

  def register_character_commands
    BMOx::PROMPT_DIR.glob("*.character").each do |template|
      puts "Registering: #{template.basename}"
      character = BMOx::Character.new(template.read)
      unless character.prompt_id
        puts "Character is missing a prompt id!"
        next
      end
      @characters[character.prompt_id] = character
      @bot.command :"#{character.prompt_id}", aliases: [:"#{@name}:#{character.prompt_id}"] do |event, *args|
        queue_command(character: character, event: event, args: args)
        nil
      end
    end
  end
end