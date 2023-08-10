require 'rubygems'
require 'bundler/setup'
require 'require_all'
require 'dotenv/load'
require 'pathname'

module BMOx
  require_rel 'bmox'
  
  LLAMA_CPP = Pathname(ENV["EXECUTABLE"])
  MODEL = Pathname(ENV["MODEL"])
  PROMPT_DIR = Pathname(ENV["PROMPT_DIR"])
  MEMORY_DIR = Pathname(ENV["MEMORY_DIR"])

  if ENV["MEMORY_DIR"] && !MEMORY_DIR.exist?
    MEMORY_DIR.mkpath
  end
end