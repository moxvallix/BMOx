class BMOx::Character
  CONFIG = {
    "avatar" => "https://cdn.discordapp.com/avatars/1107979697700229142/08fc3e87798ef809b29e0ca3458bf0ae.webp",
    "name" => "Assistant",
    "prompt_id" => nil
  }

  CONFIG.each do |key, _|
    define_method(:"#{key}") { self.instance_variable_get("@#{key}") }
  end

  def initialize(contents, substitutes = {})
    @raw = contents
    @config = YAML.parse(contents).to_ruby
    @prompt = contents.gsub(/(---|)[\s\S]+---/, "").strip
    @initial_substitutes = substitutes

    CONFIG.each do |key, value|
      self.instance_variable_set("@#{key}", @config.fetch(key, value))
    end
  end

  def discord_author
    Discordrb::Webhooks::EmbedAuthor.new(name: name, icon_url: avatar)
  end

  def formatted_prompt(additional_substitutes = {})
    prompt = @prompt.dup
    @initial_substitutes.merge(additional_substitutes).each do |key, value|
      prompt.gsub! "<#{key}>", value.to_s
    end
    prompt
  end

  def reply_to(message, substitutes = {}, params = {})
    prompt = formatted_prompt(substitutes.merge({prompt: message}))
    params.merge!({"p": prompt})
    # params.merge!({"-prompt-cache": prompt_cache_file, "-prompt-cache-all": nil, "-file": prompt_history_file})
    output = BMOx::Llama.generate(params)
    output.sub(prompt, "").strip
  end

  private

  def check_prompt_id
    raise "Character missing a prompt id" unless prompt_id.is_a? String
    raise "Prompt id contains invalid characters" if prompt_id.match? /[^a-z0-9_\-]/
  end

  def prompt_cache_file
    check_prompt_id
    BMOx::MEMORY_DIR.join("#{prompt_id}.prompt-cache")
  end

  def prompt_history_file
    check_prompt_id
    BMOx::MEMORY_DIR.join("#{prompt_id}.prompt-history")
  end
end