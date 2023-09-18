require 'rubygems'
require 'bundler/setup'
require 'require_all'
require 'dotenv/load'
require 'pathname'
require 'yaml'
require 'ostruct'
require 'logger'

module BMOx
  CONFIG = YAML.parse_file(ENV.fetch("CONFIG_FILE", "config.yml")).to_ruby(symbolize_names: true)
  
  LLAMA_CPP = Pathname(CONFIG.dig(:paths, :executable).to_s)
  MODEL = Pathname(CONFIG.dig(:paths, :model).to_s)
  PROMPT_DIR = Pathname(CONFIG.dig(:paths, :prompt).to_s)
  MEMORY_DIR = Pathname(CONFIG.dig(:paths, :memory).to_s)
  
  if MEMORY_DIR && !MEMORY_DIR.exist?
    MEMORY_DIR.mkpath
  end

  LOGGER = Logger.new(STDOUT)
  PROMPT_LOGGER = Logger.new(CONFIG.dig(:paths, :log) || "prompts.log")

  require_rel 'bmox'
end