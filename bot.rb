require 'rubygems'
require 'bundler/setup'
require 'discordrb'
require 'dotenv/load'
require 'pathname'
require 'open3'

LLAMA_DIR = Pathname(ENV["EXECUTABLE"])
PROMPT_DIR = Pathname(ENV["PROMPT_DIR"])

bot = Discordrb::Commands::CommandBot.new token: ENV["TOKEN"], client_id: ENV["CLIENT_ID"], prefix: "/"

@typing = {}
@characters = []
@queue = []
@queue_loop = false

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
  # lookup = output.match(/(?<=\[:)[\s\S]+(?=:\])/)
  # if lookup.is_a? MatchData
  #   perform_lookup(event, args, lookup)
  # else
  #   event.channel.send_message output.match(/(?<=### Assistant:)[\s\S]+/).to_s.strip
  # end
end

def respond_as_character(file, event, args)
  start_typing(event.channel)
  user_prompt = args.join(" ")
  prompt = file.read.gsub("<prompt>", user_prompt).gsub("<username>", event.author.display_name)
  output, status = Open3.capture2(LLAMA_DIR.join("main").to_s, "-ngl", ENV.fetch("NGL", "24"), "-m", LLAMA_DIR.join("models/#{ENV['MODEL']}").to_s, "-p", prompt, "-n", ENV.fetch("N", "768"))
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
      process_command(@queue.delete_at(0))
    end
    @queue_loop = false
  end
end

PROMPT_DIR.glob("*.template").each do |template|
  puts "Registering: #{template.basename}"
  command_name = template.basename.to_s.delete_suffix(".template").to_sym
  @characters << command_name.to_s
  bot.command command_name do |event, *args|
    queue_command(template: template, event: event, args: args)
    nil
  end
end

bot.command :bmox_list do |_event, *args|
  "**META:** Available Characters\n" + @characters.join("\n")
end

bot.command :bmox_queue do |_event, *args|
  "**META:** There are #{@queue.size + (@queue_loop ? 1 : 0)} prompts being processed currently."
end

bot.run
